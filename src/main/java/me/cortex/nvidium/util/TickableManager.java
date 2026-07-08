package me.cortex.nvidium.util;

import java.util.LinkedHashSet;
import java.util.Set;

public class TickableManager {
	private static final Set<UploadingBufferStream> UPLOADERS = new LinkedHashSet<>();
	private static final Set<DownloadTaskStream> DOWNLOADERS = new LinkedHashSet<>();

	public static void register(UploadingBufferStream stream) {
		UPLOADERS.add(stream);
	}

	public static void register(DownloadTaskStream stream) {
		DOWNLOADERS.add(stream);
	}

	public static void remove(UploadingBufferStream stream) {
		UPLOADERS.remove(stream);
	}

	public static void remove(DownloadTaskStream stream) {
		DOWNLOADERS.remove(stream);
	}

	/**
	 * Should be called at the end of every frame.
	 */
	public static void TickAll() {
		for (UploadingBufferStream u : UPLOADERS) u.tick();
		for (DownloadTaskStream d : DOWNLOADERS) d.tick();
	}
}
