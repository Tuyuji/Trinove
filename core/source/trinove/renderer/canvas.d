// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.renderer.canvas;

import trinove.math;
import trinove.output_manager : OutputManager;
import trinove.gpu.itexture : ITexture;
import wayland.server.protocol : WlOutput;

alias BufferTransform = WlOutput.Transform;

// Has info for the current draw with utility functions.
// Setup for a current output and contains helper functions.
// Currently enforces the renderers pipeline but in the future this should change.
interface ICanvas
{
	// Draw a solid-colour rectangle.
	void drawRect(Vector2F pos, Vector2F size, float[4] color, float opacity);

	// Draw a textured rectangle with an optional color tint.
	// srcRect is [u0, v0, u1, v1] into the texture.
	void drawTexture(Vector2F pos, Vector2F size, ITexture tex,
		float[4] srcRect, BufferTransform uvTransform,
		float[4] color, float opacity);

	// Draw a drop shadow for a content rectangle of the given size.
	void drawShadow(Vector2F pos, Vector2U contentSize,
		uint blurRadius, uint cornerRadius,
		uint extentTop, uint extentBottom,
		uint extentLeft, uint extentRight,
		float[4] color, float opacity);
}

// Interface for objects in the flat render list managed by RenderSystem.
interface IRenderEntry
{
	// Draw all content owned by this entry onto the canvas for the given output.
	// Called once per output per frame while the render pass is active.
	void draw(ICanvas canvas, OutputManager.ManagedOutput output);

	// Translate accumulated damage into compositor-space rects and push them
	// to the OutputManager for the given output. Called before the render pass begins.
	void pushDamage(OutputManager om, OutputManager.ManagedOutput output);

	// When false the entry is skipped entirely (draw + pushDamage).
	@property bool visible();

	// Called after the given output's command buffer has been submitted and presented.
	void onFramePresented(OutputManager.ManagedOutput output);
}
