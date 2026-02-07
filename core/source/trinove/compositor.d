// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.compositor;

import trinove.subsystem;
import trinove.display_manager;
import trinove.backend;
import trinove.output_manager;
import trinove.renderer;
import trinove.layer;
import trinove.math;
import trinove.log;
import trinove.wm;
import trinove.wm.conductor : WindowConductor;
import trinove.seat_manager;
import trinove.cursor;
import trinove.cursor_shape : WaiCursorShapeManager;
import trinove.shell.wm_base;
import trinove.relative_pointer;
import trinove.pointer_constraints;
import trinove.viewporter;
import trinove.subcompositor;
import trinove.surface.buffer;
import trinove.surface.dmabuf;
import trinove.gpu.rhi : RHI;
import wayland.server;
import wayland.native.server;
import core.time : MonoTime;
import std.process : environment;

class WaiCompositor : WlCompositor, ISubsystem
{
	private
	{
		RenderSubsystem _renderSubsystem;
		SeatManager _seatManager;
		OutputManager _outputManager;
		WindowConductor _conductor;
		VideoBackend _videoBackend;
		WaiXdgWmBase _xdgWmBase;
		WaiLinuxDmabuf _linuxDmabuf;
		WaiRelativePointerManager _relativePointerManager;
		WaiPointerConstraints _pointerConstraints;
		WaiViewporter _viewporter;
		WaiSubcompositor _subcompositor;
		WaiCursorShapeManager _cursorShapeManager;

		CursorTheme _defaultCursorTheme;

		MonoTime _startTime;
	}

	override string name()
	{
		return "WaiCompositor";
	}

	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.Compositor;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		required ~= Services.VideoBackend;
		required ~= Services.InputBackend;
		required ~= Services.OutputManager;
		required ~= Services.SeatManager;
		required ~= Services.RenderSubsystem;
		required ~= Services.Conductor;
		required ~= Services.WindowManager;
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	override void initialize()
	{
		_startTime = MonoTime.currTime;
		auto d = getDisplay();
		d.initShm();

		_outputManager = SubsystemManager.getByService!OutputManager(Services.OutputManager);
		if (_outputManager is null)
		{
			logError("No OutputManager available");
			return;
		}

		_videoBackend = SubsystemManager.getByService!VideoBackend(Services.VideoBackend);
		if (_videoBackend is null)
		{
			logError("No video backend available");
			return;
		}

		if (_outputManager.outputs.length == 0)
		{
			logError("No outputs could be activated");
			return;
		}

		_renderSubsystem = SubsystemManager.getByService!RenderSubsystem(Services.RenderSubsystem);
		if (_renderSubsystem is null)
		{
			logError("No RenderSubsystem available");
			return;
		}

		_seatManager = SubsystemManager.getByService!SeatManager(Services.SeatManager);
		if (_seatManager is null)
		{
			logError("No SeatManager available");
			return;
		}

		_conductor = SubsystemManager.getByService!WindowConductor(Services.Conductor);

		// Load default cursor theme and set it on all seats.
		auto ctm = SubsystemManager.getByService!CursorThemeManager(Services.CursorThemeManager);
		if (ctm !is null)
		{
			auto xcursorTheme = environment.get("XCURSOR_THEME", "default");
			_defaultCursorTheme = ctm.getTheme(xcursorTheme);
			loadSystemCursorTheme(_defaultCursorTheme, xcursorTheme);
			foreach (seat; _seatManager.seats)
				seat.setCursorTheme(_defaultCursorTheme);
		}

		_xdgWmBase = new WaiXdgWmBase(_conductor);
		_linuxDmabuf = new WaiLinuxDmabuf(d);
		_relativePointerManager = new WaiRelativePointerManager(d);
		_pointerConstraints = new WaiPointerConstraints(d);
		_viewporter = new WaiViewporter(d);
		_subcompositor = new WaiSubcompositor(d);
		_cursorShapeManager = new WaiCursorShapeManager(d);

		// Set WAYLAND_DISPLAY for child processes
		environment["WAYLAND_DISPLAY"] = getDisplayName();

		d.addClientCreatedListener(&addClient);

		// Clear screen
		_outputManager.damageAll();
		_renderSubsystem.scene.scheduleRepaint();

		logInfo("Compositor initialized");
	}

	override void shutdown()
	{
		if (_defaultCursorTheme !is null)
		{
			auto ctm = SubsystemManager.getByService!CursorThemeManager(Services.CursorThemeManager);
			if (ctm !is null)
				ctm.releaseTheme(_defaultCursorTheme);
			_defaultCursorTheme = null;
		}

		logInfo("Compositor shutdown");
	}

	@property MonoTime startTime()
	{
		return _startTime;
	}

	@property SceneGraph scene()
	{
		return _renderSubsystem.scene;
	}

	@property Renderer renderer()
	{
		return _renderSubsystem.renderer;
	}

	@property RenderSubsystem renderSubsystem()
	{
		return _renderSubsystem;
	}

	@property SeatManager seatManager()
	{
		return _seatManager;
	}

	@property OutputManager outputManager()
	{
		return _outputManager;
	}

	@property WindowConductor conductor()
	{
		return _conductor;
	}

	this()
	{
		super(getDisplay(), ver);
	}

	void addClient(WlClient cl)
	{
		cl.addNativeResourceCreatedListener((wl_resource* natRes) {
			import core.stdc.string : strcmp;

			if (strcmp(wl_resource_get_class(natRes), "wl_buffer") == 0)
				new CpuBuffer(natRes);
		});
	}

	override WlSurface createSurface(WlClient cl, Resource res, uint id)
	{
		import trinove.surface.surface;

		return new WaiSurface(this, cl, id);
	}

	override void createRegion(WlClient cl, Resource res, uint id)
	{
		new Region(cl, id);
	}
}

public import trinove.region;
