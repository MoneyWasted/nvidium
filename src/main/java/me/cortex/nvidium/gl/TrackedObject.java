package me.cortex.nvidium.gl;

import me.cortex.nvidium.Nvidium;

import java.lang.ref.Cleaner;
import java.lang.ref.Cleaner.Cleanable;

public abstract class TrackedObject {
	private static final Cleaner cleaner = Cleaner.create();
	private final Ref ref;

	public TrackedObject() {
		this.ref = register(this);
	}

	public static Ref register(Object obj) {
		String clazz = obj.getClass().getName();
		Throwable trace = Nvidium.IS_DEBUG ? new Throwable() : null;
		boolean[] freed = new boolean[1];
		var clean = cleaner.register(obj, () -> {
			if (!freed[0]) {
				System.err.println("Object not freed: " + clazz);
				if (trace != null) {
					trace.printStackTrace();
				} else {
					System.err.println("(enable debug mode for allocation trace)");
				}
				System.err.flush();
			}
		});
		return new Ref(clean, freed);
	}

	protected void free0() {
		if (this.isFreed()) {
			throw new IllegalStateException("Object " + this + " was double freed.");
		}
		this.ref.freedRef[0] = true;
		this.ref.cleanable.clean();
	}

	public abstract void free();

	public void assertNotFreed() {
		if (isFreed()) {
			throw new IllegalStateException("Object " + this + " should not be free, but is");
		}
	}

	public boolean isFreed() {
		return this.ref.freedRef[0];
	}

	public record Ref(Cleaner.Cleanable cleanable, boolean[] freedRef) {
	}
}
