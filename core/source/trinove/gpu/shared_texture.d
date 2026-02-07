// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.gpu.shared_texture;

import trinove.gpu.rhi : GpuDevice, RHI;
import trinove.gpu.itexture : ITexture;
import trinove.gpu.format : PixelFormat, fromDrm, toWGPU, isOpaqueAlpha;
import trinove.linux.drm;
import trinove.log;
import webgpu;

// Texture imported from external memory (DMA-BUF, etc.)
//
// Unlike Texture2D, this is explicitly single-device. The texture
// is imported on one device and can only be used there. For multi-GPU
// scenarios, explicit copy to another device is required.
//
// Usage:
//   auto sharedTex = SharedTexture2D.importDmaBuf(device, planes, format, ...);
//
//   // Each frame:
//   sharedTex.beginAccess(device);
//   // Render using sharedTex.view
//   sharedTex.endAccess(device);
class SharedTexture2D : ITexture
{
	private
	{
		GpuDevice _device;
		uint _width;
		uint _height;
		PixelFormat _format; // Format thats actually exposed to users. 
		WGPUTextureFormat _gpuFormat; // from Dawn's property query if available, else _format.toWGPU.

		WGPUSharedTextureMemory _sharedMem;
		WGPUTexture _texture;
		WGPUTextureView _view;
		bool _destroyed;
		bool _accessActive;
	}

	@property uint width() => _width;
	@property uint height() => _height;
	@property PixelFormat format() => _format;
	@property WGPUTextureFormat wgpuFormat() => _gpuFormat;
	@property GpuDevice device() => _device;
	@property WGPUTexture texture() => _texture;
	@property WGPUTextureView view() => _view;
	@property WGPUSharedTextureMemory sharedMemory() => _sharedMem;
	@property bool isValid() => _view !is null;

	WGPUTextureView getViewForDevice(GpuDevice device)
	{
		if (device !is _device)
			return null; // Only available on import device
		return _view;
	}

	void beginAccess(GpuDevice device)
	{
		if (device !is _device)
			return;
		doBeginAccess();
	}

	void endAccess(GpuDevice device)
	{
		if (device !is _device)
			return;
		doEndAccess();
	}

	bool isAvailableOn(GpuDevice device)
	{
		return device is _device;
	}

	@property bool opaqueAlpha() => _format.isOpaqueAlpha;

	// Import a DMA-BUF as a shared texture
	static SharedTexture2D importDmaBuf(GpuDevice device, uint width, uint height, uint drmFormat, ulong drmModifier,
			const(DmaBufPlane)[] planes)
	{
		auto tex = new SharedTexture2D();
		tex._device = device;
		tex._width = width;
		tex._height = height;
		tex._format = fromDrm(drmFormat);

		if (!tex.doImportDmaBuf(drmFormat, drmModifier, planes))
		{
			return null;
		}

		return tex;
	}

	private this()
	{
	}

	~this()
	{
		destroy();
	}

	void destroy()
	{
		if (_destroyed)
			return;
		_destroyed = true;

		if (_accessActive)
			doEndAccess();

		if (_view !is null)
		{
			wgpuTextureViewRelease(_view);
			_view = null;
		}
		if (_texture !is null)
		{
			wgpuTextureRelease(_texture);
			_texture = null;
		}
		if (_sharedMem !is null)
		{
			wgpuSharedTextureMemoryRelease(_sharedMem);
			_sharedMem = null;
		}
	}

	private void doBeginAccess()
	{
		if (_sharedMem is null || _texture is null)
		{
			logError("doBeginAccess: sharedMem or texture is null");
			return;
		}
		if (_accessActive)
		{
			logWarn("doBeginAccess: already active");
			return;
		}

		WGPUSharedTextureMemoryBeginAccessDescriptor desc;
		desc.concurrentRead = false;
		desc.initialized = true;

		// Vulkan requires image layout state to be specified.
		WGPUSharedTextureMemoryVkImageLayoutBeginState vkState;
		if (RHI.isVulkan)
		{
			vkState.chain.sType = WGPUSType.sharedTextureMemoryVkImageLayoutBeginState;
			vkState.oldLayout = 0; // VK_IMAGE_LAYOUT_UNDEFINED
			vkState.newLayout = 5; // VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL
			desc.nextInChain = &vkState.chain;
		}

		auto status = wgpuSharedTextureMemoryBeginAccess(_sharedMem, _texture, &desc);
		if (status == WGPUStatus.success)
		{
			_accessActive = true;
		}
		else
		{
			logError("beginAccess failed with status %d", status);
		}
	}

	private void doEndAccess()
	{
		if (_sharedMem is null || _texture is null || !_accessActive)
			return;

		WGPUSharedTextureMemoryEndAccessState state;

		// Vulkan requires image layout state chain
		WGPUSharedTextureMemoryVkImageLayoutEndState vkState;
		if (RHI.isVulkan)
		{
			vkState.chain.sType = WGPUSType.sharedTextureMemoryVkImageLayoutEndState;
			state.nextInChain = &vkState.chain;
		}

		wgpuSharedTextureMemoryEndAccess(_sharedMem, _texture, &state);
		wgpuSharedTextureMemoryEndAccessStateFreeMembers(state);
		_accessActive = false;
	}

	// Check if this texture is compatible with the given device.
	// Returns true only for the device it was imported on.
	bool isCompatibleWith(GpuDevice device)
	{
		return device is _device;
	}

	private bool doImportDmaBuf(uint drmFormat, ulong drmModifier, const(DmaBufPlane)[] planes)
	{
		if (_device is null)
		{
			logError("No device for dmabuf import");
			return false;
		}

		// Build plane array for WebGPU.
		// Dawn requires all planes sharing a dmabuf allocation to have identical fd values,
		WGPUSharedTextureMemoryDmaBufPlane[4] wgpuPlanes;
		foreach (i, ref plane; planes)
		{
			import core.sys.posix.sys.stat : stat_t, fstat;

			int fd = plane.fd;
			stat_t st;
			if (i > 0 && fstat(plane.fd, &st) == 0)
			{
				foreach (j; 0 .. i)
				{
					stat_t prev;
					if (fstat(planes[j].fd, &prev) == 0 && prev.st_ino == st.st_ino && prev.st_dev == st.st_dev)
					{
						fd = planes[j].fd;
						break;
					}
				}
			}
			wgpuPlanes[i].fd = fd;
			wgpuPlanes[i].offset = plane.offset;
			wgpuPlanes[i].stride = plane.stride;
		}

		// Create DMA-BUF descriptor
		WGPUSharedTextureMemoryDmaBufDescriptor dmabufDesc;
		dmabufDesc.chain.sType = WGPUSType.sharedTextureMemoryDmaBufDescriptor;
		dmabufDesc.size = WGPUExtent3d(_width, _height, 1);
		dmabufDesc.drmFormat = drmFormat;
		dmabufDesc.drmModifier = drmModifier;
		dmabufDesc.planeCount = planes.length;
		dmabufDesc.planes = wgpuPlanes.ptr;

		// Import shared texture memory
		WGPUSharedTextureMemoryDescriptor desc;
		desc.nextInChain = &dmabufDesc.chain;

		_sharedMem = wgpuDeviceImportSharedTextureMemory(_device.handle, &desc);
		if (_sharedMem is null)
		{
			logError("wgpuDeviceImportSharedTextureMemory failed");
			return false;
		}

		// Query the exact GPU format from the imported memory.
		// Dawn knows best here for known formats this should agree with _format.toWGPU.
		WGPUSharedTextureMemoryProperties props;
		auto status = wgpuSharedTextureMemoryGetProperties(_sharedMem, &props);
		_gpuFormat = (status == WGPUStatus.success) ? props.format : _format.toWGPU;

		// Create texture from shared memory
		WGPUTextureDescriptor texDesc;
		texDesc.usage = WGPUTextureUsage.textureBinding;
		texDesc.dimension = WGPUTextureDimension._2d;
		texDesc.size = WGPUExtent3d(_width, _height, 1);
		texDesc.format = _gpuFormat;
		texDesc.mipLevelCount = 1;
		texDesc.sampleCount = 1;

		_texture = wgpuSharedTextureMemoryCreateTexture(_sharedMem, &texDesc);
		if (_texture is null)
		{
			logError("wgpuSharedTextureMemoryCreateTexture failed");
			wgpuSharedTextureMemoryRelease(_sharedMem);
			_sharedMem = null;
			return false;
		}

		// Create texture view
		_view = wgpuTextureCreateView(_texture, null);
		if (_view is null)
		{
			logError("Failed to create texture view for shared texture");
			wgpuTextureRelease(_texture);
			_texture = null;
			wgpuSharedTextureMemoryRelease(_sharedMem);
			_sharedMem = null;
			return false;
		}

		return true;
	}

	override string toString() const @safe pure
	{
		import std.format : format;

		return format("SharedTexture2D(%dx%d %s)", _width, _height, _format);
	}
}

// Plane data for DMA-BUF import
struct DmaBufPlane
{
	int fd = -1;
	uint offset;
	uint stride;
}
