// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.output;

import trinove.math;
import trinove.gpu.rhi : GpuDevice;
import webgpu : WGPUInstance, WGPUSurface;
import wayland.server.protocol : WlOutput;

// Hardware cursor plane abstraction.
//
// Backends implement this to provide hardware cursor support.
// Returns null from Output.cursorPlane() if hardware cursor is unsupported.
interface CursorPlane
{
	// Set the cursor image. Pixels are ARGB8888 format.
	// Returns false if cursor couldn't be set (too large for HW).
	// Should fall back to software cursor on failure.
	bool setImage(const(ubyte)[] pixels, Vector2U size, Vector2I hotspot);

	void setPosition(Vector2I pos);
	void hide();
	Vector2U sizeLimit();
}

// Represents a display output/monitor from the backend.
//
// Compositor-level state (position, damage, WlOutput global) is managed
// by OutputManager.
abstract class Output
{
	// Output identifier from hardware ("HDMI-1", "DP-2", "SDL-0")
	abstract string name();

	// Activate the output and create a WebGPU surface for rendering.
	// Creates backend resources and returns the surface on success, null on failure.
	abstract WGPUSurface activate(WGPUInstance instance);

	// Deactivate the output and release all backend resources.
	abstract void deactivate();

	// Size in pixels of current mode.
	abstract Vector2U size();

	// Physical size in millimeters.
	// Returns (0, 0) if unknown.
	Vector2U physicalSize()
	{
		return Vector2U(0, 0);
	}

	// Available display modes.
	abstract Mode[] modes();

	// Current refresh rate in millihertz (60000 = 60Hz).
	abstract uint refreshRateMilliHz();

	// The GPU device responsible for rendering this output.
	// For DRM backends, this is the GPU that owns the connector.
	// For SDL/debug backends, this typically returns RHI.primaryDevice.
	abstract GpuDevice findGpu();

	// Hardware cursor plane, or null if not supported.
	CursorPlane cursorPlane()
	{
		return null;
	}

	// Display mode information
	struct Mode
	{
		WlOutput.Mode flags; // current, preferred
		Vector2U size;
		uint refreshMilliHz;
	}
}
