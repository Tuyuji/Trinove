// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.gpu.texture;

import trinove.gpu.resource;
import trinove.gpu.rhi : GpuDevice, RHI;
import trinove.gpu.itexture : ITexture;
import trinove.gpu.format : PixelFormat, toWGPU, isOpaqueAlpha;
import trinove.log;
import webgpu;

// Per-device
struct DeviceTexture
{
	WGPUTexture texture;
	WGPUTextureView view;
}

class Texture2D : MultiDeviceResource!DeviceTexture, ITexture
{
	private
	{
		uint _width;
		uint _height;
		PixelFormat _format;
	}

	@property uint width() => _width;
	@property uint height() => _height;
	@property PixelFormat format() => _format;
	@property bool opaqueAlpha() => _format.isOpaqueAlpha;

	WGPUTextureView getViewForDevice(GpuDevice device)
	{
		auto devTex = getForDevice(device);
		return devTex.view;
	}

	void beginAccess(GpuDevice device)
	{

	}

	void endAccess(GpuDevice device)
	{

	}

	bool isAvailableOn(GpuDevice device)
	{
		return true;
	}

	// Create a texture. Creates on all devices immediately.
	this(uint width, uint height, PixelFormat format = PixelFormat.bgra8Unorm)
	{
		super();
		_width = width;
		_height = height;
		_format = format;

		createForAllDevices();
	}

	~this()
	{
		foreach (dev, res; _deviceResources)
			destroyDeviceResource(res);
	}

	override void destroy()
	{
		foreach (device, ref devTex; _deviceResources)
			destroyDeviceResource(devTex);
		_deviceResources.clear();
	}

	override string toString() const @safe pure
	{
		import std.format : format;

		return format("Texture2D(%dx%d %s)", _width, _height, _format);
	}

	// Upload pixel data to the GPU texture on all devices via wgpuQueueWriteTexture.
	void upload(const(ubyte)[] data, uint stride)
	{
		auto needed = stride * _height;
		if (data.length < needed)
		{
			logError("Upload data too small: %d bytes, need %d", data.length, needed);
			return;
		}

		foreach (device, ref devTex; _deviceResources)
		{
			if (devTex.texture is null)
				continue;

			WGPUTexelCopyTextureInfo dest;
			dest.texture = devTex.texture;
			dest.mipLevel = 0;
			dest.origin = WGPUOrigin3d(0, 0, 0);
			dest.aspect = WGPUTextureAspect.all;

			WGPUTexelCopyBufferLayout layout;
			layout.offset = 0;
			layout.bytesPerRow = stride;
			layout.rowsPerImage = _height;

			WGPUExtent3d size;
			size.width = _width;
			size.height = _height;
			size.depthOrArrayLayers = 1;

			wgpuQueueWriteTexture(device.queue, &dest, data.ptr, needed, &layout, &size);
		}
	}

	// Recreate the texture with new dimensions.
	// Any bind groups referencing the old texture views become invalid.
	void recreate(uint newWidth, uint newHeight, PixelFormat newFormat = PixelFormat.bgra8Unorm)
	{
		foreach (device, ref devTex; _deviceResources)
			destroyDeviceResource(devTex);
		_deviceResources.clear();

		_width = newWidth;
		_height = newHeight;
		_format = newFormat;

		createForAllDevices();
	}

	// Check if recreation is needed for new dimensions.
	bool needsRecreate(uint newWidth, uint newHeight) const
	{
		return _width != newWidth || _height != newHeight;
	}

	// Check if recreation is needed for new dimensions and format.
	bool needsRecreate(uint newWidth, uint newHeight, PixelFormat newFormat) const
	{
		return _width != newWidth || _height != newHeight || _format != newFormat;
	}

	protected override DeviceTexture createForDevice(GpuDevice device)
	{
		DeviceTexture devTex;

		WGPUTextureDescriptor desc;
		desc.usage = WGPUTextureUsage.textureBinding | WGPUTextureUsage.copyDst;
		desc.dimension = WGPUTextureDimension._2d;
		desc.size = WGPUExtent3d(_width, _height, 1);
		desc.format = _format.toWGPU;
		desc.mipLevelCount = 1;
		desc.sampleCount = 1;

		devTex.texture = wgpuDeviceCreateTexture(device.handle, &desc);
		if (devTex.texture is null)
		{
			logError("Failed to create texture %dx%d on device %s", _width, _height, device.name);
			return devTex;
		}

		devTex.view = wgpuTextureCreateView(devTex.texture, null);
		if (devTex.view is null)
		{
			logError("Failed to create texture view on device %s", device.name);
			wgpuTextureRelease(devTex.texture);
			devTex.texture = null;
			return devTex;
		}

		return devTex;
	}

	protected override void destroyDeviceResource(DeviceTexture res)
	{
		if (res.view !is null)
			wgpuTextureViewRelease(res.view);
		if (res.texture !is null)
			wgpuTextureRelease(res.texture);
	}

}
