// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.renderer.renderer;

import trinove.output;
import trinove.math;
import trinove.log;
import trinove.renderer.scene : SceneGraph, SceneNode, RectNode, ShadowNode, IFrameListener;
import trinove.output_manager;
import trinove.gpu.rhi : GpuDevice, RHI;
import trinove.gpu.texture : Texture2D;
import trinove.gpu.format : PixelFormat;
import trinove.gpu.shader : Shader;
import trinove.gpu.pipeline : RenderPipeline, RenderPipelineConfig, uniformBinding, samplerBinding, textureBinding;
import trinove.gpu.buffer : GpuBuffer, BufferUsage;
import trinove.gpu.sampler : Sampler;
import trinove.gpu.itexture;
import webgpu;

// WebGPU requires uniform buffer dynamic offsets to be aligned to this
enum UNIFORM_ALIGNMENT = 256;

// Used for dynamic uniform buffer offsets, 
// so each draw call can have its own set of uniforms without needing multiple buffers.
enum MAX_DRAWS_PER_FRAME = 2048;

// Per-frame uniform data (group 0, binding 0)
struct FrameUniforms
{
	float[16] projection; // mat4x4f (64 bytes)
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

// Renders the scene graph to outputs.
// The renderer traverses the scene graph and issues draw calls.
class Renderer
{
	private
	{
		Texture2D _whiteTexture;
		Shader _quadShader;
		RenderPipeline _quadPipeline;
		GpuBuffer _frameUniformBuffer; // Per-frame uniform
		GpuBuffer _drawUniformBuffer; // Per-draw uniforms with dynamic offsets
		Sampler _linearSampler;
	}

	float[4] clearColor = [0.15f, 0.6f, 0.7f, 1.0f];
	bool showDamageOverlay = false;
	private uint _damageFrameCounter = 0;

	void initialize()
	{
		//Create white texture.
		{
			ubyte[4] white = [255, 255, 255, 255];
			_whiteTexture = new Texture2D(1, 1, PixelFormat.rgba8Unorm);
			_whiteTexture.upload(white[], 4);
		}
		//Create our main shader and pipeline.
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
		//Create uniform buffers.
		{
			_frameUniformBuffer = new GpuBuffer(FrameUniforms.sizeof, BufferUsage.uniform);
			_drawUniformBuffer = new GpuBuffer(UNIFORM_ALIGNMENT * MAX_DRAWS_PER_FRAME, BufferUsage.uniform);
		}
		//Create samplers.
		{
			import trinove.gpu.sampler : SamplerConfig;

			SamplerConfig config;
			config.label = "linear_sampler";
			_linearSampler = new Sampler(config);
		}
		logInfo("Renderer initialized");
	}

	void shutdown()
	{
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
		logInfo("Renderer shutdown");
	}

	@property Texture2D whiteTexture() => _whiteTexture;

	void renderOutput(OutputManager.ManagedOutput mo, SceneGraph scene, ref IFrameListener[] frameListeners)
	{
		auto device = mo.gpuDevice;

		if (mo.surface is null || device is null)
		{
			logError("Cannot render: surface or device is null");
			return;
		}

		// Get current surface texture
		WGPUSurfaceTexture surfaceTexture;
		wgpuSurfaceGetCurrentTexture(mo.surface, &surfaceTexture);

		if (surfaceTexture.status != WGPUSurfaceGetCurrentTextureStatus.successOptimal
				&& surfaceTexture.status != WGPUSurfaceGetCurrentTextureStatus.successSuboptimal)
		{
			logError("Failed to get surface texture: status=%d", surfaceTexture.status);
			return;
		}

		auto textureView = wgpuTextureCreateView(surfaceTexture.texture, null);
		if (textureView is null)
		{
			logError("Failed to create texture view");
			return;
		}
		scope (exit)
			wgpuTextureViewRelease(textureView);

		wgpuTextureRelease(surfaceTexture.texture);

		auto encoder = wgpuDeviceCreateCommandEncoder(device.handle, null);
		if (encoder is null)
		{
			logError("Failed to create command encoder");
			return;
		}

		// Set up render pass
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
			return;
		}

		// Set up frame state
		auto viewport = mo.viewport();
		FrameRenderState frameState;
		frameState.device = device;
		frameState.renderPass = renderPass;
		frameState.viewport = viewport;
		frameState.projection = orthoMatrix(0, viewport.width, viewport.height, 0, -1, 1);
		frameState.drawIndex = 0;

		// Set pipeline once for all draws
		auto devPipeline = _quadPipeline.getForDevice(device);
		if (devPipeline.pipeline is null)
		{
			wgpuRenderPassEncoderEnd(renderPass);
			wgpuRenderPassEncoderRelease(renderPass);
			wgpuCommandEncoderRelease(encoder);
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
			return;
		}

		wgpuRenderPassEncoderSetBindGroup(renderPass, 0, frameBindGroup, 0, null);

		// Render scene
		foreach (layerRoot; scene.layerRoots)
		{
			renderNode(layerRoot, Vector2F(0, 0), 1.0f, frameState, frameListeners);
		}

		// Draw damage overlay if enabled
		if (showDamageOverlay && !mo.damage.empty)
			drawDamageOverlay(mo.damage.rects, frameState);

		wgpuRenderPassEncoderEnd(renderPass);
		wgpuRenderPassEncoderRelease(renderPass);
		wgpuBindGroupRelease(frameBindGroup);

		auto commandBuffer = wgpuCommandEncoderFinish(encoder, null);
		wgpuCommandEncoderRelease(encoder);

		if (commandBuffer is null)
		{
			logError("Failed to finish command encoder");
			return;
		}

		wgpuQueueSubmit(device.queue, 1, &commandBuffer);
		wgpuCommandBufferRelease(commandBuffer);

		// Request notification
		device.notifyOnWorkDone();

		wgpuSurfacePresent(mo.surface);
	}

	private void renderNode(SceneNode node, Vector2F parentPos, float parentOpacity, ref FrameRenderState frameState,
			ref IFrameListener[] frameListeners)
	{
		if (!node.visible)
			return;

		auto worldPos = Vector2F(parentPos.x + node.position.x, parentPos.y + node.position.y);
		auto opacity = parentOpacity * node.opacity;

		auto nodeBounds = Rect(cast(int) worldPos.x, cast(int) worldPos.y, cast(uint) node.size.x, cast(uint) node.size.y);

		bool nodeVisible = nodeBounds.intersects(frameState.viewport);

		auto localPos = Vector2F(worldPos.x - frameState.viewport.position.x, worldPos.y - frameState.viewport.position.y);

		if (nodeVisible)
		{
			if (auto shadow = cast(ShadowNode) node)
			{
				drawShadow(shadow, localPos, opacity, frameState);
			}
			else if (auto rect = cast(RectNode) node)
			{
				drawRect(rect, localPos, opacity, frameState);

				if (rect.frameListener !is null)
					frameListeners ~= rect.frameListener;
			}
		}

		foreach (child; node.children)
		{
			renderNode(child, worldPos, opacity, frameState, frameListeners);
		}
	}

	private void drawRect(RectNode rect, Vector2F pos, float opacity, ref FrameRenderState frameState)
	{
		if (rect.size.x <= 0 || rect.size.y <= 0)
			return;

		if (frameState.drawIndex >= MAX_DRAWS_PER_FRAME)
		{
			logError("Max draws per frame exceeded");
			return;
		}

		auto device = frameState.device;
		auto renderPass = frameState.renderPass;

		auto devPipeline = _quadPipeline.getForDevice(device);
		if (devPipeline.pipeline is null)
			return;

		auto devUniform = _drawUniformBuffer.getForDevice(device);
		if (devUniform.buffer is null)
			return;

		// Determine texture to use
		ITexture tex = rect.texture !is null ? rect.texture : _whiteTexture;
		if (!tex.isAvailableOn(device))
		{
			logError("Cannot render node: texture not available on this output's GPU.");
			return;
		}
		auto textureView = tex.getViewForDevice(device);
		if (textureView is null)
		{
			logError("Failed to get texture view for node texture.");
			return;
		}

		// Calculate buffer offset for this draw
		uint bufferOffset = frameState.drawIndex * UNIFORM_ALIGNMENT;

		// Prepare per-draw uniforms
		DrawUniforms uniforms;
		uniforms.rect = [pos.x, pos.y, rect.size.x, rect.size.y];
		uniforms.srcRect = rect.srcRect;
		uniforms.color = rect.color;
		uniforms.opacity = opacity;
		uniforms.opaqueAlpha = tex.opaqueAlpha ? 1 : 0;
		uniforms.uvTransform = cast(uint) rect.uvTransform;

		// Upload uniforms at offset
		wgpuQueueWriteBuffer(device.queue, devUniform.buffer, bufferOffset, &uniforms, DrawUniforms.sizeof);

		// Create bind group 1 (per-draw: uniform buffer + texture)
		WGPUBindGroupEntry[2] entries;

		entries[0].binding = 0;
		entries[0].buffer = devUniform.buffer;
		entries[0].offset = 0; // Base offset, dynamic offset added at draw time
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

		// Bind group 1 with dynamic offset
		wgpuRenderPassEncoderSetBindGroup(renderPass, 1, bindGroup, 1, &bufferOffset);
		wgpuRenderPassEncoderDraw(renderPass, 4, 1, 0, 0);

		frameState.drawIndex++;
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

	private void drawDamageOverlay(Rect[] damageRects, ref FrameRenderState frameState)
	{
		foreach (i, rect; damageRects)
		{
			auto color = _damageColors[(_damageFrameCounter + i) % _damageColors.length];
			drawColoredQuad(Vector2F(rect.position.x, rect.position.y), Vector2F(rect.size.x, rect.size.y), color, 0.35f, frameState);
		}
		_damageFrameCounter++;
	}

	private void drawColoredQuad(Vector2F pos, Vector2F size, float[4] color, float opacity, ref FrameRenderState frameState)
	{
		if (size.x <= 0 || size.y <= 0)
			return;

		if (frameState.drawIndex >= MAX_DRAWS_PER_FRAME)
			return;

		auto device = frameState.device;
		auto renderPass = frameState.renderPass;

		auto devPipeline = _quadPipeline.getForDevice(device);
		if (devPipeline.pipeline is null)
			return;

		auto devUniform = _drawUniformBuffer.getForDevice(device);
		if (devUniform.buffer is null)
			return;

		auto textureView = _whiteTexture.getViewForDevice(device);
		if (textureView is null)
			return;

		uint bufferOffset = frameState.drawIndex * UNIFORM_ALIGNMENT;

		DrawUniforms uniforms;
		uniforms.rect = [pos.x, pos.y, size.x, size.y];
		uniforms.srcRect = [0.0f, 0.0f, 1.0f, 1.0f];
		uniforms.color = color;
		uniforms.opacity = opacity;
		uniforms.opaqueAlpha = 0;

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

	private void drawShadow(ShadowNode shadow, Vector2F pos, float opacity, ref FrameRenderState frameState)
	{
		// TODO: Implement shadow rendering with gradient shader
		// For now, skip shadows
	}

	private static float[16] orthoMatrix(float l, float r, float b, float t, float n, float f)
	{
		return [
			2 / (r - l), 0, 0, 0, 0, 2 / (t - b), 0, 0, 0, 0, -2 / (f - n), 0, -(r + l) / (r - l), -(t + b) / (t - b),
			-(f + n) / (f - n), 1
		];
	}
}
