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
import trinove.seat_manager;
import trinove.cursor;
import trinove.cursor_shape : WaiCursorShapeManager;
import trinove.xdg_shell.wm_base;
import trinove.xdg_shell.xdg_decoration : WaiXdgDecorationManager;
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
import std.algorithm : remove;
import std.typecons;
import trinove.seat : Seat;

abstract class TrinoveCompositor : WlCompositor, ISubsystem
{
	protected Window[] _windows;

	private
	{
		RenderSubsystem _renderSubsystem;
		SeatManager _seatManager;
		OutputManager _outputManager;
		VideoBackend _videoBackend;
		WaiXdgWmBase _xdgWmBase;
		WaiXdgDecorationManager _xdgDecorationManager;
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
		return "TrinoveCompositor";
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

		_xdgWmBase = new WaiXdgWmBase(this);
		_xdgDecorationManager = new WaiXdgDecorationManager(d, this);
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
		_renderSubsystem.scheduleRepaint();

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

	//Simple helper for protocols to try and start a render.
	//This doesn't mean a render will actually happen as the renderer will ask for damage
	// from the IRenderEntrys (your own compositor) and if no damage is reported for the output
	// then it won't render.
	void scheduleRepaint()
	{
		_renderSubsystem.scheduleRepaint();
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


	// === Window Manager ===
	// Functions in here will not assume anything about rendering, a subclass must
	// shedule repaints as necessary and set damage regions on the display as needed.
	// The reasons for this is Trinove doesn't want to assume how your using position on Views or how your rendering them,
	// thus we can't handle this for you, if you want these assumsions then you can use a subclass of this that
	// has those assumptions. 

	void addWindow(Window window)
	{
		_windows ~= window;
	}

	void removeWindow(Window window)
	{
		foreach (seat; _seatManager.seats)
		{
			seat.clearFocusForView(window);
		}

		_windows = _windows.remove!(w => w is window);

		foreach (w; _windows)
		{
			if (w.parentWindow is window)
				w.parentWindow = window.parentWindow;
		}
		window.parentWindow = null;
	}

	void setWindowParent(Window window, Window parent)
	{
		window.parentWindow = parent;

		if(window.mapped && parent !is null)
		{
			reorderWindowChildren(parent);
		}
	}

	// Reorders _windows so all descendants of parent sit directly after it,
	// in DFS pre-order (child before grandchild). Parent's own position is unchanged.
	void reorderWindowChildren(Window parent)
	{
		import std.algorithm : countUntil;
		
		Window[] descendants;
		void collect(Window w)
		{
			foreach (child; _windows)
			{
				if (child.parentWindow is w)
				{
					descendants ~= child;
					collect(child);
				}
			}
		}
		collect(parent);

		if (descendants.length == 0)
			return;

		foreach (d; descendants)
			_windows = _windows.remove!(w => w is d);

		auto parentIndex = _windows.countUntil!(w => w is parent);
		if (parentIndex == -1)
		{
			logError("Parent window not found in compositor's window list");
			return;
		}

		_windows = _windows[0 .. parentIndex + 1] ~ descendants ~ _windows[parentIndex + 1 .. $];
	}

	// Moves the given window from where-ever to the top of the stack (end of _windows array).
	void reorderWindowToTop(Window window)
	{
		_windows = _windows.remove!(w => w is window) ~ window;
		reorderWindowChildren(window);
	}

	void addPopup(Popup popup)
	{
		if(popup.parentWindow is null)
			return;
		
		popup.mapped = true;

		if (popup.parentPopup !is null)
			popup.parentPopup.childPopup = popup;
		else
			popup.parentWindow.popup = popup;
	}

	void removePopup(Popup popup)
	{
		if (!popup.mapped)
			return;

		popup.mapped = false;

		if (popup.parentPopup !is null)
		{
			if (popup.parentPopup.childPopup is popup)
				popup.parentPopup.childPopup = popup.childPopup;
		}
		else if (popup.parentWindow !is null)
		{
			if (popup.parentWindow.popup is popup)
				popup.parentWindow.popup = popup.childPopup;
		}

		if (popup.childPopup !is null)
			popup.childPopup.parentPopup = popup.parentPopup;

		popup.parentPopup = null;
		popup.childPopup = null;
	}

	// === Window helpers ===

	Popup popupAt(Vector2I pos)
	{
		Popup best = null;
		Layer bestLayer = Layer.min;

		foreach (window; _windows)
		{
			if (!window.mapped || window.popup is null) continue;
			if (best !is null && window.layer < bestLayer) continue;

			auto popup = window.popup;
			while (popup.childPopup !is null)
				popup = popup.childPopup;

			while (popup !is null)
			{
				if (popup.mapped && popup.containsPoint(pos))
				{
					if (best is null || window.layer >= bestLayer)
					{
						best = popup;
						bestLayer = window.layer;
					}
					break;
				}
				popup = popup.parentPopup;
			}
		}
		return best;
	}

	// === Constraint helpers ===

	bool handleLockedPointerMotion(Seat seat, InputEvent event)
	{
		import trinove.pointer_constraints.constraint : ConstraintType;

		auto c = seat.pointerConstraint;
		if (c is null || !c.active || c.type != ConstraintType.lock)
			return false;
		seat.notifyRelativeMotion(event.timestampMs, event.pointerMotion.delta, event.pointerMotion.deltaUnaccel);
		seat.sendPointerFrame();
		return true;
	}

	bool hasActivePointerConfine(Seat seat)
	{
		import trinove.pointer_constraints.constraint : ConstraintType;

		auto c = seat.pointerConstraint;
		return c !is null && c.active && c.type == ConstraintType.confine;
	}

	bool hasActivePointerLock(Seat seat)
	{
		import trinove.pointer_constraints.constraint : ConstraintType;

		auto c = seat.pointerConstraint;
		return c !is null && c.active && c.type == ConstraintType.lock;
	}

	// Clamp a surface-local cursor position to the active confine constraint region.
	// Returns the clamped surface-local position, or the input unchanged if no confine is active.
	Vector2 applyPointerConfine(Seat seat, Vector2 cursorPosViewLocal)
	{
		import trinove.pointer_constraints.constraint : ConstraintType;

		auto c = seat.pointerConstraint;
		if (c is null || !c.active || c.type != ConstraintType.confine)
			return cursorPosViewLocal;

		auto focusedSurface = seat.pointerFocus.surface;
		if (focusedSurface is null)
			return cursorPosViewLocal;

		auto surfaceSize = focusedSurface.computeSurfaceState().size;
		auto clamped = c.clampToRegion(cast(int) cursorPosViewLocal.x, cast(int) cursorPosViewLocal.y, surfaceSize);
		return Vector2(clamped.x, clamped.y);
	}

	// === Abstract policy hooks ===

	//Sent by protocols when their configure loop is complete.
	void onApplyGeometry(Window window, Vector2I position, Vector2U size);

	void onMaximizeRequest(Window window, bool bWantsMaximize);
	void onFullscreenRequest(Window window, bool bWantsFullscreen, OutputManager.ManagedOutput output);
	void onMinimizeRequest(Window window);
	void onWindowTitleChange(Window window);
	void onWindowDecorationPreferenceChange(Window window, bool bWantsSSD);
	void onShowWindowMenuRequest(Window window, Seat seat, Vector2I localPos);
	void onMoveWindowRequest(Window window, Seat seat);
	void onResizeWindowRequest(Window window, Seat seat, DecorationHit edges);

	// Called when the client has ack'ed and commited a tracked configure.
	// The protocol layer is responsible for having already applied window.state.flags
	// and called setLayer if needed.
	void onWindowConfigureApplied(Window window, Nullable!Vector2I position);
	void onWindowResizeCommited(Window window, Vector2U newSize);
}

public import trinove.region;
