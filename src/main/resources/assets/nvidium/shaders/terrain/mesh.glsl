#version 460

#extension GL_ARB_shading_language_include : enable
#pragma optionNV(unroll all)
#define UNROLL_LOOP
#extension GL_NV_mesh_shader : require
#extension GL_NV_gpu_shader5 : require
#extension GL_NV_bindless_texture : require

#extension GL_KHR_shader_subgroup_arithmetic: require
#extension GL_KHR_shader_subgroup_basic : require
#extension GL_KHR_shader_subgroup_vote : require
#extension GL_KHR_shader_subgroup_shuffle : require

layout(binding = 1) uniform sampler2D tex_light;

#moj_import <nvidium:occlusion/scene.glsl>
#moj_import <nvidium:terrain/vertex_format/vertex_format.glsl>

#ifdef RENDER_FOG
#moj_import <sodium:include/fog.glsl>
#endif

// ~16 quads per mesh invocation is the sweet spot for terrain
layout(local_size_x = 32) in;
layout(triangles, max_vertices=64, max_primitives=32) out;

#ifndef USE_NV_FRAGMENT_SHADER_BARYCENTRIC
layout(location=1) out Interpolants {
#ifdef RENDER_FOG
    vec2 v_FragDistance;
#endif
    vec2 uv;
    vec3 v_colour;
} OUT[];
#endif

taskNV in Task {
    uvec4 binStarts;
    uvec4 binOffsets;

    vec3 origin;
    uint quadCount;
    uint transformationId;
};


// Binary search by global invocation index to determine the base quad offset.
// All threads in a workgroup will likely take the same branch.
uint getOffset() {
    uint gii = gl_GlobalInvocationID.x>>1;
    bvec4 le = lessThan(uvec4(gii), binStarts);

    uint retval = binOffsets.w;
    if (le.y) { // le.x is always true (binStarts[0] == 0)
        retval = binOffsets.x;
    } else if (le.z) {
        retval = binOffsets.y;
    } else if (le.w) {
        retval = binOffsets.z;
    }
    return retval+gii;
}

mat4 transformMat;

vec4 transformVertex(Vertex V) {
    vec3 pos = decodeVertexPosition(V)+origin;
    return MVP*(transformMat * vec4(pos,1.0));
}

Vertex Vc;
vec4 pVc;
Vertex V;
vec4 pV;

void putVertex(uint id, Vertex V) {
#ifndef USE_NV_FRAGMENT_SHADER_BARYCENTRIC
    #ifdef RENDER_FOG
    vec3 pos = decodeVertexPosition(V)+origin;
    vec3 exactPos = pos+subchunkOffset.xyz;
    OUT[id].v_FragDistance = getFragDistance(exactPos);
    #endif

    OUT[id].uv = decodeVertexUV(V);
    OUT[id].v_colour = computeMultiplier(V);
#endif
}

void main() {
    if (gl_LocalInvocationIndex == 0) {
        gl_PrimitiveCountNV = 0;
    }

    if (quadCount <= (gl_GlobalInvocationID.x >> 1)) {
        return;
    }

    uint quadId = getOffset();

    if (quadId == uint(-1)) {
        return;
    }
    transformMat = transformationArray[transformationId];

    bool triangle1 = (gl_LocalInvocationIndex & uint(1)) == 1;

    // Corner vertex: alternated relative to neighbor thread
    Vc = terrainData[(quadId<<2)+(triangle1?2:0)];

    // Unique vertex: V1 or V3 depending on which triangle
    V = terrainData[(quadId<<2)+(triangle1?3:1)];

    pVc = transformVertex(Vc);
    pV = transformVertex(V);

    bool draw = true;
    bool peerDraw = true;

#ifdef CULL_DEGENERATE_TRIANGLES
    { // Compute triangle screen-space bounding box; vertices 0 and 2 are shared
        vec2 ssmin = ((pVc.xy/pVc.w)+1)*screenSize;
        vec2 ssmax = ssmin;

        // Exchange common vertex data with the paired thread
        vec2 pVc2 = subgroupShuffleXor(ssmin, 1u);
        ssmin = min(ssmin, pVc2);
        ssmax = max(ssmax, pVc2);

        vec2 point = ((pV.xy/pV.w)+1)*screenSize;
        vec2 tmin = min(ssmin, point);
        vec2 tmax = max(ssmax, point);

        // Cull if the triangle doesn't cover the center of any screen pixel
        float degenBias = 0.01f;
        draw = all(notEqual(round(tmin-degenBias),round(tmax+degenBias)));

        // Exchange cull result with the paired thread
        peerDraw = subgroupShuffleXor(draw, 1u);

        if (!(draw || peerDraw)) {
            return;
        }
    }
    #endif

    uint qId = (gl_LocalInvocationIndex&uint(~1))*2;
    // Emit the shared corner vertex
    gl_MeshVerticesNV[qId+uint(triangle1)].gl_Position = pVc;
    putVertex(qId+uint(triangle1), Vc);
    if (draw) {
        uint uId = qId+uint(triangle1)+2;
        gl_MeshVerticesNV[uId].gl_Position = pV;
        putVertex(uId, V);

        uint triId = subgroupExclusiveAdd(1);

        // Vertex indices are inserted in inverted order: vert 0 is at idx 1, vert 2 is at idx 0
        gl_PrimitiveIndicesNV[triId * 3 + 0] = qId+uint(triangle1);  // shared vertex 1
        gl_PrimitiveIndicesNV[triId * 3 + 1] = uId;                   // unique vertex
        gl_PrimitiveIndicesNV[triId * 3 + 2] = qId+uint(!triangle1);  // shared vertex 2

        gl_MeshPrimitivesNV[triId].gl_PrimitiveID = int(quadId<<1) | int(triangle1);

        uint triCount = subgroupMax(triId);
        if (subgroupElect()) {
            gl_PrimitiveCountNV = triCount+1;
            #ifdef STATISTICS_CULL
            atomicAdd(statistics_buffer+3, (32-1)-triCount); // count culled triangles
            #endif
        }
    }
}