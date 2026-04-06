// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.gpu.buffer;

import trinove.gpu.resource;
import trinove.gpu.rhi : GpuDevice, RHI;
import trinove.log;
import webgpu;

alias BufferUsage = WGPUBufferUsage;

// Per-device buffer data
struct DeviceBuffer
{
	WGPUBuffer buffer;
}

// GPU buffer resource with multi-GPU support.
class GpuBuffer : MultiDeviceResource!DeviceBuffer
{
	private
	{
		size_t _size;
		BufferUsage _usage;
	}

	@property size_t size() => _size;
	@property BufferUsage usage() => _usage;

	this(size_t size, BufferUsage usage)
	{
		super();
		_size = size;
		// adding copyDst for everything cause we dont really need to not do that right now.
		_usage = usage | BufferUsage.copyDst;

		createForAllDevices();
	}

	~this()
	{
		destroy();
	}

	override string toString() const @safe pure
	{
		import std.format : format;

		return format("GpuBuffer(%d bytes)", _size);
	}

	void upload(const(ubyte)[] data, size_t offset = 0)
	{
		if (data.length + offset > _size)
		{
			logError("Upload data too large: %d bytes at offset %d, buffer is %d bytes", data.length, offset, _size);
			return;
		}

		foreach (device, ref devBuf; _deviceResources)
		{
			if (devBuf.buffer !is null)
			{
				wgpuQueueWriteBuffer(device.queue, devBuf.buffer, offset, data.ptr, data.length);
			}
		}
	}

	void upload(T)(const(T)[] data, size_t offset = 0)
	{
		upload(cast(const(ubyte)[]) data, offset * T.sizeof);
	}

	protected override DeviceBuffer createForDevice(GpuDevice device)
	{
		DeviceBuffer devBuf;

		WGPUBufferDescriptor desc;
		desc.usage = cast(WGPUBufferUsage) _usage;
		desc.size = _size;

		devBuf.buffer = wgpuDeviceCreateBuffer(device.handle, &desc);
		if (devBuf.buffer is null)
		{
			logError("Failed to create buffer (%d bytes) on device %s", _size, device.name);
			return devBuf;
		}

		return devBuf;
	}

	protected override void destroyDeviceResource(DeviceBuffer res)
	{
		if (res.buffer !is null)
			wgpuBufferRelease(res.buffer);
	}
}
