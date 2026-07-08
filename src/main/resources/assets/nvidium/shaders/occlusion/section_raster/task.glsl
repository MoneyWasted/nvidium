#version 460

#extension GL_ARB_shading_language_include : enable
#pragma optionNV(unroll all)
#define UNROLL_LOOP
#extension GL_NV_mesh_shader : require
#extension GL_NV_gpu_shader5 : require
#extension GL_NV_bindless_texture : require

#extension GL_KHR_shader_subgroup_basic : require
#extension GL_KHR_shader_subgroup_ballot : require
#extension GL_KHR_shader_subgroup_vote : require

#moj_import <nvidium:occlusion/scene.glsl>

// local_size_x=1: each workgroup maps to multiple meshlets, not invocations
layout(local_size_x=1) in;

taskNV out Task {
    uint32_t _visOutBase; // base visibility output offset
    uint32_t _offset;     // region start offset (regionId << 8)
    mat4 regionTransform;
    ivec3 chunkShift;
    uint sectionCount;
};

void main() {
    uint cmdIdx = gl_WorkGroupID.x;
    uint transCmdIdx = (uint(regionCount) - gl_WorkGroupID.x) - 1;

    if (regionVisibility[gl_WorkGroupID.x] == uint8_t(0)) {
        gl_TaskCountNV = 0;
        return;
    }

    #ifdef STATISTICS_REGIONS
    atomicAdd(statistics_buffer, 1);
    #endif

    // TODO: uploading region data directly into the UBO would remove one level of indirection
    uint32_t offset = regionIndicies[gl_WorkGroupID.x];
    Region data = regionData[offset];
    int count = unpackRegionCount(data)+1;

    _visOutBase = offset<<8; // fast visibility lookup in the compute shader
    _offset = offset<<8;
    regionTransform = getRegionTransformation(data);

    chunkShift = (-chunkPosition.xyz) - unpackOriginOffsetId(unpackRegionTransformId(data));

    sectionCount = uint(count);
    gl_TaskCountNV = (count + 3) / 4;
}
