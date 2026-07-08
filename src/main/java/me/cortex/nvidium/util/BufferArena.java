package me.cortex.nvidium.util;

import me.cortex.nvidium.Nvidium;
import me.cortex.nvidium.gl.RenderDevice;
import me.cortex.nvidium.gl.buffers.IDeviceMappedBuffer;
import me.cortex.nvidium.gl.buffers.PersistentSparseAddressableBuffer;

// TODO: defer sparse page deallocation to end-of-frame — committing pages is not cheap
public class BufferArena {
	public final IDeviceMappedBuffer buffer;
	private final RenderDevice device;
	private final int vertexFormatSize;
	private final long memorySize;
	SegmentedManager segments = new SegmentedManager();
	private long totalQuads;

	public BufferArena(RenderDevice device, long memory, int vertexFormatSize) {
		this.device = device;
		this.vertexFormatSize = vertexFormatSize;
		this.memorySize = memory;
		if (Nvidium.SUPPORTS_PERSISTENT_SPARSE_ADDRESSABLE_BUFFER) {
			buffer = device.createSparseBuffer(80_000_000_000L); // 80 GB virtual sparse buffer
		} else {
			buffer = device.createDeviceOnlyMappedBuffer(memory);
			this.segments.setLimit(memory / (4L * this.vertexFormatSize));
		}
		//Reserve index 0
		this.allocQuads(1);
	}

	public int allocQuads(int quadCount) {
		totalQuads += quadCount;
		int addr = (int) segments.alloc(quadCount);
		if (addr == SegmentedManager.SIZE_LIMIT) {
			return addr;
		}
		if (buffer instanceof PersistentSparseAddressableBuffer psab) {
			psab.ensureAllocated(Integer.toUnsignedLong(addr) * 4L * vertexFormatSize, quadCount * 4L * vertexFormatSize);
		}
		return addr;
	}

	public void free(int addr) {
		int count = segments.free(addr);
		totalQuads -= count;
		if (buffer instanceof PersistentSparseAddressableBuffer psab) {
			psab.deallocate(Integer.toUnsignedLong(addr) * 4L * vertexFormatSize, count * 4L * vertexFormatSize);
		}
	}

	public long upload(UploadingBufferStream stream, int addr) {
		return stream.upload(buffer, Integer.toUnsignedLong(addr) * 4L * vertexFormatSize, (int) segments.getSize(addr) * 4 * vertexFormatSize);
	}

	public void delete() {
		buffer.delete();
	}

	public int getAllocatedMB() {
		if (buffer instanceof PersistentSparseAddressableBuffer psab) {
			return (int) ((psab.getPagesCommitted() * PersistentSparseAddressableBuffer.PAGE_SIZE) / (1024 * 1024));
		} else {
			return (int) (memorySize / (1024 * 1024));
		}
	}

	public int getUsedMB() {
		return (int) ((totalQuads * vertexFormatSize * 4) / (1024 * 1024));
	}

	public long getMemoryUsed() {
		if (buffer instanceof PersistentSparseAddressableBuffer psab) {
			return psab.getPagesCommitted() * PersistentSparseAddressableBuffer.PAGE_SIZE;
		} else {
			return memorySize;
		}
	}

	public float getFragmentation() {
		long expected = totalQuads * vertexFormatSize * 4;
		return (float) ((double) expected / getMemoryUsed());
	}

	public boolean canReuse(int addr, int quads) {
		return this.segments.getSize(addr) == quads;
	}
}
