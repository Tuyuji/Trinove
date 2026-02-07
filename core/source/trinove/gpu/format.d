// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.gpu.format;

import webgpu : WGPUTextureFormat;

// Pixel formats used by Trinove for Wayland buffer types (SHM and DMA-BUF).
// WebGPU doesn't have X channel formats so thats why we have our own format enum.
enum PixelFormat
{
	bgra8Unorm,
	rgba8Unorm,
	bgrx8Unorm,
	rgbx8Unorm,
	rgb10a2Unorm,
	rgbx10Unorm,
}

// Returns true for X-channel formats where the alpha channel should be treated as fully opaque.
bool isOpaqueAlpha(PixelFormat fmt) @nogc nothrow pure
{
	return fmt == PixelFormat.bgrx8Unorm || fmt == PixelFormat.rgbx8Unorm || fmt == PixelFormat.rgbx10Unorm;
}

// opaque alpha variants return the same WGPUTextureFormat as their alpha channel counterparts.
// Please use isOpaqueAlpha separately to check if you should use alpha blending or not.
WGPUTextureFormat toWGPU(PixelFormat fmt) @nogc nothrow pure
{
	final switch (fmt)
	{
	case PixelFormat.bgra8Unorm:
	case PixelFormat.bgrx8Unorm:
		return WGPUTextureFormat.bgra8Unorm;
	case PixelFormat.rgba8Unorm:
	case PixelFormat.rgbx8Unorm:
		return WGPUTextureFormat.rgba8Unorm;
	case PixelFormat.rgb10a2Unorm:
	case PixelFormat.rgbx10Unorm:
		return WGPUTextureFormat.rgb10A2Unorm;
	}
}

// Convert from a DRM fourcc format code to the closest PixelFormat.
// Returns PixelFormat.bgra8Unorm for unrecognised formats.
PixelFormat fromDrm(uint drmFmt)
{
	import trinove.linux.drm : DrmFormat;
	import trinove.log : logWarn;

	switch (drmFmt)
	{
	case DrmFormat.ARGB8888:
		return PixelFormat.bgra8Unorm;
	case DrmFormat.XRGB8888:
		return PixelFormat.bgrx8Unorm;
	case DrmFormat.ABGR8888:
		return PixelFormat.rgba8Unorm;
	case DrmFormat.XBGR8888:
		return PixelFormat.rgbx8Unorm;
	case DrmFormat.XBGR2101010:
		return PixelFormat.rgbx10Unorm;
	default:
		logWarn("fromDrm: unrecognised DRM format 0x%08X, falling back to bgra8Unorm", drmFmt);
		return PixelFormat.bgra8Unorm;
	}
}

// Convert from a wl_shm format code.
//
// Per the Wayland spec, wl_shm format values match DRM fourcc codes except for argb8888 / xrgb8888
PixelFormat fromShm(uint shmFmt)
{
	import wayland.server.protocol : WlShm;

	switch (shmFmt)
	{
	case WlShm.Format.argb8888:
		return PixelFormat.bgra8Unorm;
	case WlShm.Format.xrgb8888:
		return PixelFormat.bgrx8Unorm;
	default:
		return fromDrm(shmFmt);
	}
}
