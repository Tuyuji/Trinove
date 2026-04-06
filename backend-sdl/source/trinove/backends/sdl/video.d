// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.backends.sdl.video;

import trinove.subsystem;
import trinove.backend;
import trinove.events;
import trinove.log;
import trinove.math;
import trinove.output : Output;
import trinove.virtual_output;
import trinove.gpu.rhi : GpuDevice, RHI;
import dawned;
import bindbc.sdl;
import std.string : fromStringz;
import wayland.server.protocol : WlOutput;

class SdlVideoBackend : VideoBackendSubsystem
{
	private SdlOutput[] _outputs;
	private VirtualOutputSpec[] _specs;

	this(VirtualOutputSpec[] specs)
	{
		_specs = specs;
	}

	override string name()
	{
		return "SdlVideoBackend";
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		required ~= Services.SDL;
	}

	override void initialize()
	{
		foreach (spec; _specs)
		{
			auto output = new SdlOutput(spec, this);
			_outputs ~= output;
			OnBackendOutputAdded.fire(output);
		}

		debug logDebug("SDL video backend initialized with %d outputs", _outputs.length);
	}

	override void shutdown()
	{
		foreach (output; _outputs)
		{
			OnBackendOutputRemoved.fire(output);
			output.destroy();
		}
		_outputs.length = 0;

		debug logDebug("SDL video backend shutdown");
	}

	// VideoBackend interface

	override Output[] outputs()
	{
		return cast(Output[]) _outputs;
	}

}

class SdlOutput : Output
{
	private string _name;
	private SdlVideoBackend _backend;
	private SDL_Window* _window;
	private Vector2U _size;
	private uint _refreshMilliHz;

	this(VirtualOutputSpec spec, SdlVideoBackend backend)
	{
		_name = spec.name;
		_backend = backend;
		_size = spec.size;
		_refreshMilliHz = spec.refreshMilliHz;
	}

	void destroy()
	{
		deactivate();
	}

	override string name()
	{
		return _name;
	}

	override WGPUSurface activate(WGPUInstance instance)
	{
		if (_window)
			deactivate();

		import std.string : toStringz;
		import std.format : format;

		_window = SDL_CreateWindow(format("Trinove: %s", _name).toStringz, _size.x, _size.y, SDL_WINDOW_RESIZABLE);

		if (!_window)
		{
			logError("Failed to create SDL window: %s", SDL_GetError().fromStringz);
			return null;
		}
		SDL_SetWindowFullscreen(_window, false);
		SDL_SetWindowRelativeMouseMode(_window, true);

		auto surface = createSurfaceFromWindow(instance);
		if (surface is null)
		{
			logError("Failed to create WebGPU surface for output %s", _name);
			SDL_DestroyWindow(_window);
			_window = null;
			return null;
		}

		logInfo("Output %s activated (%dx%d @ %dHz)", _name, _size.x, _size.y, _refreshMilliHz / 1000);
		return surface;
	}

	override void deactivate()
	{
		if (_window)
		{
			SDL_DestroyWindow(_window);
			_window = null;
		}

		logInfo("Output %s deactivated", _name);
	}

	override Vector2U size()
	{
		if (_window)
		{
			int w, h;
			SDL_GetWindowSizeInPixels(_window, &w, &h);
			_size = Vector2U(w, h);
		}
		return _size;
	}

	Vector2U getAspectRatio(Vector2U size)
	{
		import std.numeric : gcd;

		uint common = gcd(size.x, size.y);
		return Vector2U(size.x / common, size.y / common);
	}

	override Mode[] modes()
	{
		Mode[] result;
		result ~= Mode(WlOutput.Mode.current | WlOutput.Mode.preferred, _size, _refreshMilliHz);

		Vector2U baseSize = _size;
		Vector2U ratio = getAspectRatio(baseSize);
		uint[] standardHeights = [2160, 1440, 1080, 900, 720, 480, 360];
		foreach (h; standardHeights)
		{
			if (h < _size.y)
			{
				uint w = (h / ratio.y) * ratio.x;

				result ~= Mode(cast(WlOutput.Mode) 0, Vector2U(w, h), _refreshMilliHz);
			}
		}
		return result;
	}

	override uint refreshRateMilliHz()
	{
		return _refreshMilliHz;
	}

	override GpuDevice findGpu()
	{
		// Use primary, this is just for debug and the root compositor will copy
		// our surface to other gpus if needed.
		return RHI.primaryDevice;
	}

	private WGPUSurface createSurfaceFromWindow(WGPUInstance instance)
	{
		auto props = SDL_GetWindowProperties(_window);
		if (props == 0)
		{
			logError("Failed to get window properties");
			return null;
		}

		auto driver = SDL_GetCurrentVideoDriver();
		string driverName = driver ? cast(string) driver.fromStringz : "";

		WGPUSurfaceDescriptor surfaceDesc;

		if (driverName == "wayland")
		{
			auto wlDisplay = SDL_GetPointerProperty(props, "SDL.window.wayland.display", null);
			auto wlSurface = SDL_GetPointerProperty(props, "SDL.window.wayland.surface", null);

			if (wlDisplay is null || wlSurface is null)
			{
				logError("Failed to get Wayland handles from SDL window");
				return null;
			}

			WGPUSurfaceSourceWaylandSurface waylandSource;
			waylandSource.chain.sType = WGPUSType.surfaceSourceWaylandSurface;
			waylandSource.display = wlDisplay;
			waylandSource.surface = wlSurface;

			surfaceDesc.nextInChain = cast(WGPUChainedStruct*)&waylandSource;

			logInfo("Creating WebGPU surface from Wayland");
			return wgpuInstanceCreateSurface(instance, &surfaceDesc);
		}
		else if (driverName == "x11")
		{
			auto x11Display = SDL_GetPointerProperty(props, "SDL.window.x11.display", null);
			auto x11Window = SDL_GetNumberProperty(props, "SDL.window.x11.window", 0);

			if (x11Display is null || x11Window == 0)
			{
				logError("Failed to get X11 handles from SDL window");
				return null;
			}

			WGPUSurfaceSourceXlibWindow x11Source;
			x11Source.chain.sType = WGPUSType.surfaceSourceXlibWindow;
			x11Source.display = x11Display;
			x11Source.window = cast(ulong) x11Window;

			surfaceDesc.nextInChain = cast(WGPUChainedStruct*)&x11Source;

			logInfo("Creating WebGPU surface from X11");
			return wgpuInstanceCreateSurface(instance, &surfaceDesc);
		}
		else
		{
			logError("Unsupported SDL video driver for WebGPU: %s", driverName);
			return null;
		}
	}

	package SDL_Window* sdlWindow()
	{
		return _window;
	}

	// SDL in relative mouse mode hides the host cursor, so HW cursor
	// via SDL is not usable. We'll use software cursor rendering instead.
}
