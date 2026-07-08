#define MESH_WORKLOAD_PER_INVOCATION 32

taskNV out Task {
    vec3 origin;
    uint baseOffset;
    uint quadCount;
    uint transformationId;

    // Binary search indices and data
    uvec4 binIa;
    uvec4 binIb;
    uvec4 binVa;
    uvec4 binVb;
};

void putBinData(inout uint idx, inout uint lastIndex, uint offset, uint nextOffset) {
    uint len = nextOffset - offset;
    uint id = idx++;
    if (id < 4) {
        binIa[id] = lastIndex + len;
        binVa[id] = offset;
    } else {
        binIb[id - 4] = lastIndex + len;
        binVb[id - 4] = offset;
    }
    lastIndex += len;
}

// Populate tasks based on chunk face visibility
void populateTasks(ivec3 relChunkPos, uvec4 ranges) {
    // If block face culling is disabled, render all faces
    if (!useBlockFaceCulling()) {
        relChunkPos = ivec3(0);
    }

    uint idx = 0;
    uint lastIndex = 0;

    binIa = uvec4(0);
    binIb = uvec4(0);

    // Pre-extract all per-face quad counts once; avoids repeated masking
    uint dxN = (ranges.x      ) & 0xFFFFu; // -X (nX)
    uint dyN = (ranges.x >> 16) & 0xFFFFu; // -Y
    uint dzN = (ranges.y      ) & 0xFFFFu; // -Z
    uint dxP = (ranges.y >> 16) & 0xFFFFu; // +X
    uint dyP = (ranges.z      ) & 0xFFFFu; // +Y
    uint dzP = (ranges.z >> 16) & 0xFFFFu; // +Z
    uint dNA = (ranges.w      ) & 0xFFFFu; // non-axis-aligned (double-sided)

    uint fr = (ranges.w >> 16) & 0xFFFFu;  // base quad offset

    if (relChunkPos.x <= 0 && dxN > 0) { putBinData(idx, lastIndex, fr, fr + dxN); }
    fr += dxN;

    if (relChunkPos.y <= 0 && dyN > 0) { putBinData(idx, lastIndex, fr, fr + dyN); }
    fr += dyN;

    if (relChunkPos.z <= 0 && dzN > 0) { putBinData(idx, lastIndex, fr, fr + dzN); }
    fr += dzN;

    if (relChunkPos.x >= 0 && dxP > 0) { putBinData(idx, lastIndex, fr, fr + dxP); }
    fr += dxP;

    if (relChunkPos.y >= 0 && dyP > 0) { putBinData(idx, lastIndex, fr, fr + dyP); }
    fr += dyP;

    if (relChunkPos.z >= 0 && dzP > 0) { putBinData(idx, lastIndex, fr, fr + dzP); }
    fr += dzP;

    // TODO: put double-sided quads first — may be cheaper
    putBinData(idx, lastIndex, fr, fr + dNA);

    quadCount = lastIndex;

    // Emit enough mesh shaders such that max(gl_GlobalInvocationID.x) >= 2*quadCount
    gl_TaskCountNV = ((lastIndex * 2) + MESH_WORKLOAD_PER_INVOCATION - 1) / MESH_WORKLOAD_PER_INVOCATION;
}