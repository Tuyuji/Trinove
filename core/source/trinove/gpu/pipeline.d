// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.gpu.pipeline;

import trinove.gpu.resource;
import trinove.gpu.shader : Shader;
import trinove.gpu.rhi : GpuDevice, RHI;
import trinove.log;
import webgpu;

WGPUBindGroupLayoutEntry uniformBinding(uint idx, WGPUShaderStage vis, bool dynamic = false) pure nothrow @nogc
{
	WGPUBindGroupLayoutEntry e;
	e.binding = idx;
	e.visibility = vis;
	e.buffer.type = WGPUBufferBindingType.uniform;
	e.buffer.hasDynamicOffset = dynamic;
	return e;
}

WGPUBindGroupLayoutEntry samplerBinding(uint idx, WGPUShaderStage vis, WGPUSamplerBindingType type = WGPUSamplerBindingType
		.filtering) pure nothrow @nogc
{
	WGPUBindGroupLayoutEntry e;
	e.binding = idx;
	e.visibility = vis;
	e.sampler.type = type;
	return e;
}

WGPUBindGroupLayoutEntry textureBinding(uint idx, WGPUShaderStage vis, WGPUTextureSampleType sampleType
		= WGPUTextureSampleType.float_, WGPUTextureViewDimension dim = WGPUTextureViewDimension._2d) pure nothrow @nogc
{
	WGPUBindGroupLayoutEntry e;
	e.binding = idx;
	e.visibility = vis;
	e.texture.sampleType = sampleType;
	e.texture.viewDimension = dim;
	return e;
}

// ---

struct DevicePipeline
{
	WGPURenderPipeline pipeline;
	WGPUBindGroupLayout[] bindGroupLayouts; // indexed by bind group slot
	WGPUPipelineLayout pipelineLayout;
}

// Render pipeline configuration
struct RenderPipelineConfig
{
	Shader shader;
	string vertexEntry = "vsMain";
	string fragmentEntry = "fsMain";
	WGPUTextureFormat targetFormat = WGPUTextureFormat.bgra8Unorm;
	WGPUPrimitiveTopology topology = WGPUPrimitiveTopology.triangleStrip;
	bool enableBlend = true;
	string label;
	// TODO: Accept pre-built BindGroupLayout MultiDeviceResources here instead of entry
	// descriptors, so layouts can be shared across pipelines that use the same group structure.
	const(WGPUBindGroupLayoutEntry[])[] bindGroups;
}

// Render pipeline with multi-GPU support.
class RenderPipeline : MultiDeviceResource!DevicePipeline
{
	private RenderPipelineConfig _config;

	@property ref const(RenderPipelineConfig) config() => _config;

	this(RenderPipelineConfig config)
	{
		super();
		_config = config;

		if (_config.shader is null)
		{
			logError("RenderPipeline created without shader");
			return;
		}

		createForAllDevices();
	}

	~this()
	{
		destroy();
	}

	override string toString() const @safe pure
	{
		import std.format : format;

		return format("RenderPipeline(%s)", _config.label ? _config.label : "unnamed");
	}

	protected override DevicePipeline createForDevice(GpuDevice device)
	{
		DevicePipeline devPipeline;

		auto devShader = _config.shader.getForDevice(device);
		if (devShader.shaderModule is null)
		{
			logError("Cannot create pipeline: shader module is null for device %s", device.name);
			return devPipeline;
		}

		// Create one bind group layout per group defined in config
		devPipeline.bindGroupLayouts = new WGPUBindGroupLayout[_config.bindGroups.length];

		foreach (i, ref group; _config.bindGroups)
		{
			WGPUBindGroupLayoutDescriptor desc;
			desc.entryCount = group.length;
			desc.entries = group.ptr;

			devPipeline.bindGroupLayouts[i] = wgpuDeviceCreateBindGroupLayout(device.handle, &desc);
			if (devPipeline.bindGroupLayouts[i] is null)
			{
				logError("Failed to create bind group layout %d on device %s", i, device.name);
				foreach (j; 0 .. i)
					wgpuBindGroupLayoutRelease(devPipeline.bindGroupLayouts[j]);
				devPipeline.bindGroupLayouts = null;
				return devPipeline;
			}
		}

		// Pipeline layout wraps all bind group layouts
		WGPUPipelineLayoutDescriptor pipelineLayoutDesc;
		pipelineLayoutDesc.bindGroupLayoutCount = devPipeline.bindGroupLayouts.length;
		pipelineLayoutDesc.bindGroupLayouts = devPipeline.bindGroupLayouts.ptr;

		devPipeline.pipelineLayout = wgpuDeviceCreatePipelineLayout(device.handle, &pipelineLayoutDesc);
		if (devPipeline.pipelineLayout is null)
		{
			logError("Failed to create pipeline layout on device %s", device.name);
			foreach (layout; devPipeline.bindGroupLayouts)
				wgpuBindGroupLayoutRelease(layout);
			devPipeline.bindGroupLayouts = null;
			return devPipeline;
		}

		// Vertex state (vertex data generated in shader)
		WGPUVertexState vertexState;
		vertexState.module_ = devShader.shaderModule;
		vertexState.entryPoint = WGPUStringView(_config.vertexEntry);

		// Fragment state
		WGPUBlendState blendState;
		if (_config.enableBlend)
		{
			blendState.color.srcFactor = WGPUBlendFactor.srcAlpha;
			blendState.color.dstFactor = WGPUBlendFactor.oneMinusSrcAlpha;
			blendState.color.operation = WGPUBlendOperation.add;
			blendState.alpha.srcFactor = WGPUBlendFactor.one;
			blendState.alpha.dstFactor = WGPUBlendFactor.oneMinusSrcAlpha;
			blendState.alpha.operation = WGPUBlendOperation.add;
		}

		WGPUColorTargetState colorTarget;
		colorTarget.format = _config.targetFormat;
		colorTarget.blend = _config.enableBlend ? &blendState : null;
		colorTarget.writeMask = WGPUColorWriteMask_All;

		WGPUFragmentState fragmentState;
		fragmentState.module_ = devShader.shaderModule;
		fragmentState.entryPoint = WGPUStringView(_config.fragmentEntry);
		fragmentState.targetCount = 1;
		fragmentState.targets = &colorTarget;

		// Primitive state
		WGPUPrimitiveState primitiveState;
		primitiveState.topology = _config.topology;
		primitiveState.frontFace = WGPUFrontFace.ccw;
		primitiveState.cullMode = WGPUCullMode.none;

		// Multisample state
		WGPUMultisampleState multisampleState;
		multisampleState.count = 1;
		multisampleState.mask = ~0u;

		WGPURenderPipelineDescriptor pipelineDesc;
		if (_config.label !is null)
			pipelineDesc.label = WGPUStringView(_config.label);
		pipelineDesc.layout = devPipeline.pipelineLayout;
		pipelineDesc.vertex = vertexState;
		pipelineDesc.fragment = &fragmentState;
		pipelineDesc.primitive = primitiveState;
		pipelineDesc.multisample = multisampleState;

		devPipeline.pipeline = wgpuDeviceCreateRenderPipeline(device.handle, &pipelineDesc);
		if (devPipeline.pipeline is null)
		{
			logError("Failed to create render pipeline on device %s", device.name);
			wgpuPipelineLayoutRelease(devPipeline.pipelineLayout);
			devPipeline.pipelineLayout = null;
			foreach (layout; devPipeline.bindGroupLayouts)
				wgpuBindGroupLayoutRelease(layout);
			devPipeline.bindGroupLayouts = null;
			return devPipeline;
		}

		return devPipeline;
	}

	protected override void destroyDeviceResource(DevicePipeline res)
	{
		if (res.pipeline !is null)
			wgpuRenderPipelineRelease(res.pipeline);
		if (res.pipelineLayout !is null)
			wgpuPipelineLayoutRelease(res.pipelineLayout);
		foreach (layout; res.bindGroupLayouts)
			if (layout !is null)
				wgpuBindGroupLayoutRelease(layout);
	}
}
