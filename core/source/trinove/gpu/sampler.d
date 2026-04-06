// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.gpu.sampler;

import trinove.gpu.resource;
import trinove.gpu.rhi : GpuDevice, RHI;
import trinove.log;
import webgpu;

alias MipmapFitlerMode = WGPUMipmapFilterMode;
alias FilterMode = WGPUFilterMode;
alias AddressMode = WGPUAddressMode;

struct SamplerConfig
{
	FilterMode magFilter = FilterMode.linear;
	FilterMode minFilter = FilterMode.linear;
	MipmapFitlerMode mipmapFilter = MipmapFitlerMode.linear;
	AddressMode addressModeU = AddressMode.clampToEdge;
	AddressMode addressModeV = AddressMode.clampToEdge;
	AddressMode addressModeW = AddressMode.clampToEdge;
	string label;
}

// Per-device
struct DeviceSampler
{
	WGPUSampler sampler;
}

// Texture sampler
class Sampler : MultiDeviceResource!DeviceSampler
{
	private
	{
		SamplerConfig _config;
	}

	@property ref const(SamplerConfig) config() => _config;

	this(SamplerConfig config = SamplerConfig.init)
	{
		super();
		_config = config;

		createForAllDevices();
	}

	~this()
	{
		destroy();
	}

	override string toString() const @safe pure
	{
		import std.format : format;

		return format("Sampler(%s)", _config.label ? _config.label : "unnamed");
	}

	protected override DeviceSampler createForDevice(GpuDevice device)
	{
		DeviceSampler devSampler;

		WGPUSamplerDescriptor desc;
		desc.compare = WGPUCompareFunction.undefined;
		desc.maxAnisotropy = 1;
		desc.addressModeU = _config.addressModeU;
		desc.addressModeV = _config.addressModeV;
		desc.addressModeW = _config.addressModeW;
		desc.magFilter = _config.magFilter;
		desc.minFilter = _config.minFilter;
		desc.mipmapFilter = _config.mipmapFilter;
		desc.lodMinClamp = 0.0f;
		desc.lodMaxClamp = 32.0f;

		if (_config.label !is null)
			desc.label = WGPUStringView(_config.label);

		devSampler.sampler = wgpuDeviceCreateSampler(device.handle, &desc);
		if (devSampler.sampler is null)
		{
			logError("Failed to create sampler on device %s", device.name);
		}

		return devSampler;
	}

	protected override void destroyDeviceResource(DeviceSampler res)
	{
		if (res.sampler !is null)
			wgpuSamplerRelease(res.sampler);
	}
}
