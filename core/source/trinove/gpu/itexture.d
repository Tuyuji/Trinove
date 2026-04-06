// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.gpu.itexture;

import trinove.gpu.rhi : GpuDevice;
import webgpu : WGPUTextureView;

// Interface for textures usable by the renderer.
//
// The renderer uses this interface to get what it needs without
// caring about the underlying texture type.
interface ITexture
{
	@property uint width();
	@property uint height();

	// Get the texture view for rendering on a specific device.
	// Returns null if the texture is not available on that device.
	WGPUTextureView getViewForDevice(GpuDevice device);

	// Called before rendering. For shared textures, this begins access.
	void beginAccess(GpuDevice device);

	// Called after rendering. For shared textures, this ends access.
	void endAccess(GpuDevice device);

	// Check if this texture is usable on the given device.
	bool isAvailableOn(GpuDevice device);

	// Returns true if the alpha channel should be ignored (treated as fully opaque).
	// This is true for formats like XRGB8888 where alpha exists but is undefined.
	@property bool opaqueAlpha();
}
