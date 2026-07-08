#define COLOR_SCALE        1.0 / 255.0

#ifdef USE_SODIUM_VERTEX_FORMAT
#moj_import <nvidium:terrain/vertex_format/sodium_vertex_format.glsl>
#else
#moj_import <nvidium:terrain/vertex_format/nvidium_vertex_format.glsl>
#endif

float getVertexAlphaCutoff(uint v) {
    return (float[](0.0f,0.0001f,0.5f,1.0f))[v];
}

vec4 sampleLight(vec2 uv) {
    // Divided by 16 to match Sodium/vanilla light levels (value is never exactly 1.0)
    return vec4(texture(tex_light, uv).rgb, 1);
}

vec3 computeMultiplier(Vertex V) {
    vec4 tint = decodeVertexColour(V);
    tint *= sampleLight(decodeLightUV(V));
    tint *= tint.w;
    return tint.xyz;
}