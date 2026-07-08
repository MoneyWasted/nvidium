package me.cortex.nvidium.api0;

import me.cortex.nvidium.Nvidium;
import me.cortex.nvidium.NvidiumWorldRenderer;
import me.cortex.nvidium.sodiumCompat.INvidiumWorldRendererGetter;
import net.caffeinemc.mods.sodium.client.render.SodiumWorldRenderer;
import org.joml.Matrix4fc;

public class NvidiumAPI {
	private final String modName;

	public NvidiumAPI(String modName) {
		this.modName = modName;
	}

	private NvidiumWorldRenderer getRenderer() {
		if (!Nvidium.IS_ENABLED) return null;
		return ((INvidiumWorldRendererGetter) SodiumWorldRenderer.instance()).getRenderer();
	}

	/**
	 * Forces a render section to not render. The section stays hidden until {@link #showSection} is called.
	 *
	 * @param x section X coordinate
	 * @param y section Y coordinate
	 * @param z section Z coordinate
	 */
	public void hideSection(int x, int y, int z) {
		var renderer = getRenderer();
		if (renderer != null) renderer.getSectionManager().setHideBit(x, y, z, true);
	}

	/**
	 * Unhides a render section that was previously hidden.
	 *
	 * @param x section X coordinate
	 * @param y section Y coordinate
	 * @param z section Z coordinate
	 */
	public void showSection(int x, int y, int z) {
		var renderer = getRenderer();
		if (renderer != null) renderer.getSectionManager().setHideBit(x, y, z, false);
	}

	/**
	 * Assigns a region to the given transformation id. All regions default to id 0.
	 *
	 * @param id transformation id
	 * @param x  region X coordinate
	 * @param y  region Y coordinate
	 * @param z  region Z coordinate
	 */
	public void setRegionTransformId(int id, int x, int y, int z) {
		var renderer = getRenderer();
		if (renderer != null) renderer.getSectionManager().getRegionManager().setRegionTransformId(x, y, z, id);
	}

	/**
	 * Sets the transform matrix for the given transformation id.
	 *
	 * @param id        transformation id
	 * @param transform the matrix to apply
	 */
	public void setTransformation(int id, Matrix4fc transform) {
		var renderer = getRenderer();
		if (renderer != null) renderer.setTransformation(id, transform);
	}

	/**
	 * Sets the origin (in chunk coordinates) for the given transformation id.
	 *
	 * @param id transformation id
	 * @param x  chunk X coordinate
	 * @param y  chunk Y coordinate
	 * @param z  chunk Z coordinate
	 */
	public void setOrigin(int id, int x, int y, int z) {
		var renderer = getRenderer();
		if (renderer != null) renderer.setOrigin(id, x, y, z);
	}
}
