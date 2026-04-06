// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.renderer.subsystem;

import trinove.subsystem;
import trinove.output;
import trinove.math;
import trinove.log;
import trinove.output_manager;
import trinove.renderer.canvas;
import trinove.events;
import trinove.gpu;
import trinove.backend.video;
import dawned;
import std.algorithm : remove;

// WebGPU requires uniform buffer dynamic offsets to be aligned to this
enum UNIFORM_ALIGNMENT = 256;

// Used for dynamic uniform buffer offsets,
// so each draw call can have its own set of uniforms without needing multiple buffers.
enum MAX_DRAWS_PER_FRAME = 2048;

// Per-frame uniform data (group 0, binding 0)
struct FrameUniforms
{
	float[16] projection; // mat4x4f
}

// Per-draw uniform data (group 1, binding 0)
// Padded for dynamic offset support.
struct DrawUniforms
{
	float[4] rect; // vec4f: x, y, width, height
	float[4] srcRect; // vec4f: u0, v0, u1, v1
	float[4] color; // vec4f: rgba
	float opacity; // f32
	uint opaqueAlpha; // u32: 1 = ignore texture alpha
	uint uvTransform; // u32: wl_output.transform value
	ubyte[UNIFORM_ALIGNMENT - 60] _pad; // pad to 256 bytes
}

static assert(DrawUniforms.sizeof == UNIFORM_ALIGNMENT);

// Per-frame render state passed through draw calls
struct FrameRenderState
{
	GpuDevice device;
	WGPURenderPassEncoder renderPass;
	Rect viewport;
	float[16] projection;
	uint drawIndex; // Current draw call index for uniform buffer offset
}

// Owns the render entry list and all GPU rendering resources.
// Handles the repaint/damage/render cycle.
class RenderSubsystem : ISubsystem
{
	override string name()
	{
		return "RenderSubsystem";
	}

	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.RenderSubsystem;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		required ~= Services.OutputManager;
		required ~= Services.VideoBackend;
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	override void initialize()
	{
		_outputManager = SubsystemManager.getByService!OutputManager(Services.OutputManager);
		if (_outputManager is null)
		{
			logError("RenderSubsystem: No OutputManager available");
			return;
		}

		ubyte[4] white = [255, 255, 255, 255];
		_whiteTexture = new Texture2D(1, 1, PixelFormat.rgba8Unorm);
		_whiteTexture.upload(white[], 4);

		{
			enum shaderSource = import("texture.wgsl");
			_quadShader = new Shader(shaderSource, "quad_shader");

			// group 0: per-frame (projection matrix + sampler)
			static immutable WGPUBindGroupLayoutEntry[] frameBindings = [
				uniformBinding(0, WGPUShaderStage.vertex | WGPUShaderStage.fragment),
				samplerBinding(1, WGPUShaderStage.fragment),
			];
			// group 1: per-draw (rect/color/opacity + texture) using dynamic offset
			static immutable WGPUBindGroupLayoutEntry[] drawBindings = [
				uniformBinding(0, WGPUShaderStage.vertex | WGPUShaderStage.fragment, true),
				textureBinding(1, WGPUShaderStage.fragment),
			];

			RenderPipelineConfig config;
			config.shader = _quadShader;
			config.label = "quad_pipeline";
			config.bindGroups = [frameBindings, drawBindings];
			_quadPipeline = new RenderPipeline(config);
		}
		{
			_frameUniformBuffer = new GpuBuffer(FrameUniforms.sizeof, BufferUsage.uniform);
			_drawUniformBuffer = new GpuBuffer(UNIFORM_ALIGNMENT * MAX_DRAWS_PER_FRAME, BufferUsage.uniform);
		}
		{
			SamplerConfig config;
			config.label = "linear_sampler";
			_linearSampler = new Sampler(config);
		}

		_canvas = new CanvasImpl(this);

		_outputManager.setRenderCallback(&renderOutput);

		OnQueueWorkDone.subscribe(&onQueueWorkDone);

		logInfo("RenderSubsystem initialized");
	}

	override void shutdown()
	{
		OnQueueWorkDone.unsubscribe(&onQueueWorkDone);

		if (_linearSampler !is null)
		{
			_linearSampler.destroy();
			_linearSampler = null;
		}
		if (_drawUniformBuffer !is null)
		{
			_drawUniformBuffer.destroy();
			_drawUniformBuffer = null;
		}
		if (_frameUniformBuffer !is null)
		{
			_frameUniformBuffer.destroy();
			_frameUniformBuffer = null;
		}
		if (_quadPipeline !is null)
		{
			_quadPipeline.destroy();
			_quadPipeline = null;
		}
		if (_quadShader !is null)
		{
			_quadShader.destroy();
			_quadShader = null;
		}
		if (_whiteTexture !is null)
		{
			_whiteTexture.destroy();
			_whiteTexture = null;
		}

		logInfo("RenderSubsystem shutdown");
	}

	float[4] clearColor = [0.15f, 0.6f, 0.7f, 1.0f];
	bool showDamageOverlay = false;

	void addEntry(IRenderEntry e)
	{
		_entries ~= e;
	}

	void removeEntry(IRenderEntry e)
	{
		_entries = _entries.remove!(x => x is e);
	}

	void scheduleRepaint()
	{
		onRepaintRequested();
	}

	@property OutputManager outputManager()
	{
		return _outputManager;
	}

	private
	{
		Texture2D _whiteTexture;
		Shader _quadShader;
		RenderPipeline _quadPipeline;
		GpuBuffer _frameUniformBuffer;
		GpuBuffer _drawUniformBuffer;
		Sampler _linearSampler;

		uint _damageFrameCounter = 0;

		CanvasImpl _canvas;
		OutputManager _outputManager;
		IRenderEntry[] _entries;

		// Pending GPU-present records: one entry per submitted frame, in submit order.
		// Drained in onQueueWorkDone once the GPU signals completion.
		struct PendingPresent
		{
			GpuDevice device;
			OutputManager.ManagedOutput mo;
		}
		PendingPresent[] _pendingPresents;
	}

	private void onRepaintRequested()
	{
		foreach (entry; _entries)
			if (entry.visible)
				entry.pushDamage(_outputManager, null);

		foreach (ref mo; _outputManager.outputs)
		{
			if (mo.hasDamage())
				mo.scheduleRepaint();
		}
	}

	private void renderOutput(OutputManager.ManagedOutput mo)
	{
		import dawned : wgpuDeviceTick;

		auto device = mo.gpuDevice;

		if (device !is null)
			wgpuDeviceTick(device.handle);

		if (mo.surface is null || device is null)
		{
			logError("Cannot render: surface or device is null");
			mo.clearDamage();
			return;
		}

		WGPUSurfaceTexture surfaceTexture;
		wgpuSurfaceGetCurrentTexture(mo.surface, &surfaceTexture);

		if (surfaceTexture.status != WGPUSurfaceGetCurrentTextureStatus.successOptimal
				&& surfaceTexture.status != WGPUSurfaceGetCurrentTextureStatus.successSuboptimal)
		{
			logError("Failed to get surface texture: status=%d", surfaceTexture.status);
			mo.clearDamage();
			return;
		}

		auto textureView = wgpuTextureCreateView(surfaceTexture.texture, null);
		if (textureView is null)
		{
			logError("Failed to create texture view");
			mo.clearDamage();
			return;
		}
		scope (exit)
			wgpuTextureViewRelease(textureView);

		wgpuTextureRelease(surfaceTexture.texture);

		auto encoder = wgpuDeviceCreateCommandEncoder(device.handle, null);
		if (encoder is null)
		{
			logError("Failed to create command encoder");
			mo.clearDamage();
			return;
		}

		WGPURenderPassColorAttachment colorAttachment;
		colorAttachment.depthSlice = WGPUDepthSliceUndefined;
		colorAttachment.view = textureView;
		colorAttachment.loadOp = WGPULoadOp.clear;
		colorAttachment.storeOp = WGPUStoreOp.store;
		colorAttachment.clearValue = WGPUColor(clearColor[0], clearColor[1], clearColor[2], clearColor[3]);

		WGPURenderPassDescriptor renderPassDesc;
		renderPassDesc.colorAttachmentCount = 1;
		renderPassDesc.colorAttachments = &colorAttachment;

		auto renderPass = wgpuCommandEncoderBeginRenderPass(encoder, &renderPassDesc);
		if (renderPass is null)
		{
			logError("Failed to begin render pass");
			wgpuCommandEncoderRelease(encoder);
			mo.clearDamage();
			return;
		}

		auto viewport = mo.viewport();
		FrameRenderState frameState;
		frameState.device = device;
		frameState.renderPass = renderPass;
		frameState.viewport = viewport;
		// We get positions in compositor space, so transform them properly.
		frameState.projection = orthoMatrix(
			cast(float) viewport.left, cast(float) viewport.right,
			cast(float) viewport.bottom, cast(float) viewport.top,
			-1, 1);
		frameState.drawIndex = 0;

		auto devPipeline = _quadPipeline.getForDevice(device);
		if (devPipeline.pipeline is null)
		{
			wgpuRenderPassEncoderEnd(renderPass);
			wgpuRenderPassEncoderRelease(renderPass);
			wgpuCommandEncoderRelease(encoder);
			mo.clearDamage();
			return;
		}
		wgpuRenderPassEncoderSetPipeline(renderPass, devPipeline.pipeline);

		FrameUniforms frameUniforms;
		frameUniforms.projection = frameState.projection;

		auto devFrameUniform = _frameUniformBuffer.getForDevice(device);
		auto devSampler = _linearSampler.getForDevice(device);
		if (devFrameUniform.buffer is null || devSampler.sampler is null)
		{
			wgpuRenderPassEncoderEnd(renderPass);
			wgpuRenderPassEncoderRelease(renderPass);
			wgpuCommandEncoderRelease(encoder);
			mo.clearDamage();
			return;
		}

		wgpuQueueWriteBuffer(device.queue, devFrameUniform.buffer, 0, &frameUniforms, FrameUniforms.sizeof);

		WGPUBindGroupEntry[2] frameEntries;
		frameEntries[0].binding = 0;
		frameEntries[0].buffer = devFrameUniform.buffer;
		frameEntries[0].offset = 0;
		frameEntries[0].size = FrameUniforms.sizeof;

		frameEntries[1].binding = 1;
		frameEntries[1].sampler = devSampler.sampler;

		WGPUBindGroupDescriptor frameBindGroupDesc;
		frameBindGroupDesc.layout = devPipeline.bindGroupLayouts[0];
		frameBindGroupDesc.entryCount = frameEntries.length;
		frameBindGroupDesc.entries = frameEntries.ptr;

		auto frameBindGroup = wgpuDeviceCreateBindGroup(device.handle, &frameBindGroupDesc);
		if (frameBindGroup is null)
		{
			wgpuRenderPassEncoderEnd(renderPass);
			wgpuRenderPassEncoderRelease(renderPass);
			wgpuCommandEncoderRelease(encoder);
			mo.clearDamage();
			return;
		}

		wgpuRenderPassEncoderSetBindGroup(renderPass, 0, frameBindGroup, 0, null);

		_canvas.reset(&frameState);
		foreach (e; _entries)
			if (e.visible)
				e.draw(_canvas, mo);

		if (showDamageOverlay && !mo.damage.empty)
			drawDamageOverlay(mo.damage.rects, viewport.position);

		wgpuRenderPassEncoderEnd(renderPass);
		wgpuRenderPassEncoderRelease(renderPass);
		wgpuBindGroupRelease(frameBindGroup);

		auto commandBuffer = wgpuCommandEncoderFinish(encoder, null);
		wgpuCommandEncoderRelease(encoder);

		if (commandBuffer is null)
		{
			logError("Failed to finish command encoder");
			mo.clearDamage();
			return;
		}

		wgpuQueueSubmit(device.queue, 1, &commandBuffer);
		wgpuCommandBufferRelease(commandBuffer);

		device.notifyOnWorkDone();

		wgpuSurfacePresent(mo.surface);
		mo.clearDamage();

		_pendingPresents ~= PendingPresent(device, mo);
	}

	private static immutable float[4][8] _damageColors = [
		[1.0f, 0.0f, 0.0f, 1.0f], // red
		[0.0f, 1.0f, 0.0f, 1.0f], // green
		[0.0f, 0.5f, 1.0f, 1.0f], // blue
		[1.0f, 1.0f, 0.0f, 1.0f], // yellow
		[1.0f, 0.0f, 1.0f, 1.0f], // magenta
		[0.0f, 1.0f, 1.0f, 1.0f], // cyan
		[1.0f, 0.5f, 0.0f, 1.0f], // orange
		[0.5f, 1.0f, 0.0f, 1.0f], // lime
	];

	private void drawDamageOverlay(Rect[] damageRects, Vector2I outputOrigin)
	{
		foreach (i, rect; damageRects)
		{
			auto color = _damageColors[(_damageFrameCounter + i) % _damageColors.length];
			_canvas.drawRect(
				cast(Vector2F)(rect.position + outputOrigin),
				cast(Vector2F) rect.size, color, 0.35f);
		}
		_damageFrameCounter++;
	}

	private static float[16] orthoMatrix(float l, float r, float b, float t, float n, float f)
	{
		return [
			2 / (r - l), 0, 0, 0, 0, 2 / (t - b), 0, 0, 0, 0, -2 / (f - n), 0, -(r + l) / (r - l), -(t + b) / (t - b),
			-(f + n) / (f - n), 1
		];
	}

	private void onQueueWorkDone(GpuDevice dev)
	{
		foreach (i, ref pp; _pendingPresents)
		{
			if (pp.device is dev)
			{
				auto mo = pp.mo;
				_pendingPresents = _pendingPresents.remove(i);

				foreach (entry; _entries)
					entry.onFramePresented(mo);

				return;
			}
		}
	}
}

// Given to IFrameEntry.draw to pass the context for the frame like
// the output its rendering for and what device, currently its pretty basic.
class CanvasImpl : ICanvas
{
	private RenderSubsystem _subsystem;
	private FrameRenderState* _frameState;

	this(RenderSubsystem subsystem)
	{
		_subsystem = subsystem;
	}

	void reset(FrameRenderState* frameState)
	{
		_frameState = frameState;
	}

	override void drawRect(Vector2F pos, Vector2F size, float[4] color, float opacity)
	{
		drawTexturedQuad(pos, size, _subsystem._whiteTexture, [0.0f, 0.0f, 1.0f, 1.0f],
			BufferTransform.normal, color, opacity);
	}

	override void drawTexture(Vector2F pos, Vector2F size, ITexture tex,
		float[4] srcRect, BufferTransform uvTransform,
		float[4] color, float opacity)
	{
		drawTexturedQuad(pos, size, tex, srcRect, uvTransform, color, opacity);
	}

	override void drawShadow(Vector2F pos, Vector2U contentSize,
		uint blurRadius, uint cornerRadius,
		uint extentTop, uint extentBottom,
		uint extentLeft, uint extentRight,
		float[4] color, float opacity)
	{
		// TODO: implement shadow rendering
	}

	private void drawTexturedQuad(Vector2F pos, Vector2F size, ITexture tex,
		float[4] srcRect, BufferTransform uvTransform,
		float[4] color, float opacity)
	{
		if (tex is null)
		{
			logError("drawTexturedQuad: null texture, skipping draw");
			return;
		}

		if (size.x <= 0 || size.y <= 0)
			return;

		auto frameState = _frameState;

		if (!Rect(cast(Vector2I) pos, cast(Vector2U) size).intersects(frameState.viewport))
			return;

		if (frameState.drawIndex >= MAX_DRAWS_PER_FRAME)
		{
			logError("Max draws per frame exceeded");
			return;
		}

		auto device = frameState.device;
		auto renderPass = frameState.renderPass;

		auto devPipeline = _subsystem._quadPipeline.getForDevice(device);
		if (devPipeline.pipeline is null)
			return;

		auto devUniform = _subsystem._drawUniformBuffer.getForDevice(device);
		if (devUniform.buffer is null)
			return;

		if (!tex.isAvailableOn(device))
		{
			logError("Cannot render: texture not available on this output's GPU.");
			return;
		}
		auto textureView = tex.getViewForDevice(device);
		if (textureView is null)
		{
			logError("Failed to get texture view.");
			return;
		}

		uint bufferOffset = frameState.drawIndex * UNIFORM_ALIGNMENT;

		DrawUniforms uniforms;
		uniforms.rect = [pos.x, pos.y, size.x, size.y];
		uniforms.srcRect = srcRect;
		uniforms.color = color;
		uniforms.opacity = opacity;
		uniforms.opaqueAlpha = tex.opaqueAlpha ? 1 : 0;
		uniforms.uvTransform = cast(uint) uvTransform;

		wgpuQueueWriteBuffer(device.queue, devUniform.buffer, bufferOffset, &uniforms, DrawUniforms.sizeof);

		WGPUBindGroupEntry[2] entries;

		entries[0].binding = 0;
		entries[0].buffer = devUniform.buffer;
		entries[0].offset = 0;
		entries[0].size = DrawUniforms.sizeof;

		entries[1].binding = 1;
		entries[1].textureView = textureView;

		WGPUBindGroupDescriptor bindGroupDesc;
		bindGroupDesc.layout = devPipeline.bindGroupLayouts[1];
		bindGroupDesc.entryCount = entries.length;
		bindGroupDesc.entries = entries.ptr;

		auto bindGroup = wgpuDeviceCreateBindGroup(device.handle, &bindGroupDesc);
		if (bindGroup is null)
			return;
		scope (exit)
			wgpuBindGroupRelease(bindGroup);

		wgpuRenderPassEncoderSetBindGroup(renderPass, 1, bindGroup, 1, &bufferOffset);
		wgpuRenderPassEncoderDraw(renderPass, 4, 1, 0, 0);

		frameState.drawIndex++;
	}
}
