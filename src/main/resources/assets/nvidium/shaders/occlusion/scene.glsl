#ifdef USE_SODIUM_VERTEX_FORMAT
struct Vertex {
    uint hi;
    uint lo;
    uint color;

    uint16_t u;
    uint16_t v;

    uint8_t blockLight;
    uint8_t skyLight;
    uint8_t material;
    uint8_t section;
};
#else
#define Vertex uvec4
#endif

// Section data is tightly packed to improve cache hit rate in the section rasterizer
struct Section {
    ivec4 header;
    // header.x: bits 0-3=offsetX  4-7=sizeX   8-31=chunkX
    // header.y: bits 0-3=offsetZ  4-7=sizeZ   8-31=chunkZ
    // header.z: bits 0-3=offsetY  4-7=sizeY   8-15=chunkY
    // header.w: quad offset
    ivec4 renderRanges;
    int   translucencyDataIdx;
};

struct Region {
    uint64_t a;
    uint64_t b;
};

ivec3 unpackRegionSize(Region region) {
    return ivec3((region.a>>59)&7, region.a>>62, (region.a>>56)&7);
}

uint unpackRegionTransformId(Region region) {
    return uint((region.b>>(64-24-10))&((1<<10)-1));
}

ivec3 unpackRegionPosition(Region region) {
    int x = int(int64_t(region.a<<(64-24-24))>>(64-24));
    int y = (int(region.a)<<8)>>8;
    int z = int(int64_t(region.b)>>(64-24));
    return ivec3(x,y,z);
}

int unpackRegionCount(Region region) {
    return int((region.a>>48)&255);
}

bool sectionEmpty(ivec4 header) {
    header.y &= ~0x1FF<<17;
    return header == ivec4(0);
}


layout(std140, binding=0) uniform SceneData {
    // Fields must be ordered by alignment (largest first)

    // align(16)
    mat4 MVP;
    #ifdef RENDER_FOG
    mat4 MVPInv;
    #endif
    ivec4 chunkPosition;
    vec4 subchunkOffset;

    // align(8)
    readonly restrict uint16_t *regionIndicies; // mapped to end of SceneData, also bound as uniform
    readonly restrict Region *regionData;
    restrict Section *sectionData;
    restrict uint8_t *regionVisibility;
    restrict uint8_t *sectionVisibility;
    restrict u8vec3  *sectionIndices;
    writeonly restrict uvec2 *terrainCommandBuffer;
    writeonly restrict uvec2 *translucencyCommandBuffer;
    writeonly restrict uvec2 *temporalCommandBuffer;

    readonly restrict uint16_t *sortingRegionList;

    // TODO: restrict terrainData to readonly except for translucency mesh
    restrict Vertex *terrainData;
    restrict uint   *translucencyIndexData;

    // TODO: consider a uniform instead of a buffer — but it can get large
    readonly restrict mat4 *transformationArray;
    readonly restrict uint64_t *originArray;

    uint32_t *statistics_buffer;

    vec2 screenSize;

    vec4 fogColour;
    vec2 environmentFog;
    vec2 renderFog;

    vec2 texCoordShrink;
    vec2 texelSize;

    uint flags;

    // align(2)
    uint16_t regionCount; // number of regions in regionIndicies
    // align(1)
    uint8_t frameId;
};

mat4 getRegionTransformation(Region region) {
    return transformationArray[unpackRegionTransformId(region)];
}

ivec3 unpackOriginOffsetId(uint id) {
    uint64_t val = originArray[id];
    int x = (int(uint(val&0x1ffffff))<<7)>>7;
    int y = (int(uint((val>>50)&0x3fff))<<18)>>18;
    int z = (int(uint((val>>25)&0x1ffffff))<<7)>>7;
    return ivec3(x,y,z);
}

bool useBlockFaceCulling() {
    return (flags&1)!=0;
}

bool useRGSS() {
    return (flags&2)!=0;
}