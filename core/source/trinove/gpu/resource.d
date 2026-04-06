// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.gpu.resource;

import trinove.gpu.rhi : GpuDevice, RHI;

// Base class for GPU resources that need per-device backing.
//
// In a multi-GPU setup, a single logical resource (e.g., Texture2D) may need
// separate GPU-side objects for each device. This base class handles it.
abstract class MultiDeviceResource(DeviceResourceType)
{
	protected DeviceResourceType[GpuDevice] _deviceResources;
	protected GpuDevice _primaryDevice;

	// Create with RHI's primary device as the primary
	this()
	{
		_primaryDevice = RHI.primaryDevice;
	}

	// Create with a specific primary device (for things like dmabuf import)
	this(GpuDevice primary)
	{
		_primaryDevice = primary;
	}

	// Get the device-specific resource, creating lazily if needed
	final DeviceResourceType getForDevice(GpuDevice device)
	{
		if (auto existing = device in _deviceResources)
			return *existing;

		auto devResource = createForDevice(device);
		_deviceResources[device] = devResource;
		return devResource;
	}

	final DeviceResourceType primary()
	{
		return getForDevice(_primaryDevice);
	}

	final @property GpuDevice primaryDevice() => _primaryDevice;

	// Create on all registered devices now.
	final void createForAllDevices()
	{
		foreach (device; RHI.allDevices)
		{
			getForDevice(device);
		}
	}

	// Check if resource exists for a device without creating it.
	final bool hasForDevice(GpuDevice device)
	{
		return (device in _deviceResources) !is null;
	}

	// Mark all device resources as stale except one.
	// Call after updating data on one device to trigger re-upload on others.
	protected void markStale(GpuDevice exceptDevice = null)
	{
		foreach (dev, ref res; _deviceResources)
		{
			if (dev !is exceptDevice)
				markDeviceResourceStale(dev, res);
		}
	}

	// Subclasses can override for stale marking (e.g., set a dirty flag)
	protected void markDeviceResourceStale(GpuDevice device, ref DeviceResourceType res)
	{
	}

	// Clean up all device resources
	void destroy()
	{
		foreach (dev, res; _deviceResources)
		{
			destroyDeviceResource(res);
		}
		_deviceResources.clear();
	}

	// Create the device-specific resource
	protected abstract DeviceResourceType createForDevice(GpuDevice device);

	// Clean up a device-specific resource
	protected abstract void destroyDeviceResource(DeviceResourceType res);
}
