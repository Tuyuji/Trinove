// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.gpu.shader;

import trinove.gpu.resource;
import trinove.gpu.rhi : GpuDevice, RHI;
import trinove.log;
import webgpu;

// Per-device
struct DeviceShader
{
	WGPUShaderModule shaderModule;
}

class Shader : MultiDeviceResource!DeviceShader
{
	private
	{
		string _source;
		string _label;
	}

	@property string label() => _label;

	this(string source, string label = null)
	{
		super();
		_source = source;
		_label = label;

		createForAllDevices();
	}

	~this()
	{
		destroy();
	}

	override string toString() const @safe pure
	{
		import std.format : format;

		return format("Shader(%s)", _label ? _label : "unnamed");
	}

	protected override DeviceShader createForDevice(GpuDevice device)
	{
		DeviceShader devShader;

		WGPUShaderSourceWgsl wgslSource;
		wgslSource.chain.sType = WGPUSType.shaderSourceWgsl;
		wgslSource.code = WGPUStringView(_source);

		WGPUShaderModuleDescriptor desc;
		desc.nextInChain = &wgslSource.chain;
		if (_label !is null)
			desc.label = WGPUStringView(_label);

		devShader.shaderModule = wgpuDeviceCreateShaderModule(device.handle, &desc);
		if (devShader.shaderModule is null)
		{
			logError("Failed to create shader module '%s' on device %s", _label, device.name);
		}

		return devShader;
	}

	protected override void destroyDeviceResource(DeviceShader res)
	{
		if (res.shaderModule !is null)
			wgpuShaderModuleRelease(res.shaderModule);
	}
}
