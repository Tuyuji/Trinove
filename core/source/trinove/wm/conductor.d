// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.wm.conductor;

import trinove.subsystem;
import trinove.renderer : RenderSubsystem;
import trinove.math;
import trinove.layer;
import trinove.wm.view : WmCapabilityFlags;
import trinove.backend.input;
import trinove.seat;
import trinove.seat_manager;
import trinove.wm.view;
import trinove.wm.window;
import trinove.wm.popup;
import trinove.wm.imanager;
import trinove.wm.decoration : DecorationHit;
import trinove.surface.surface : WaiSurface, SurfaceHit, findSurfaceAt;
import trinove.pointer_constraints : PointerConstraint, ConstraintType;
import trinove.output_manager;
import trinove.log;
import std.algorithm : remove;
import std.typecons : Nullable;

// Base layer that helps with managing the higher level window stuff.
//
// Does NOT own window policy (placement, decorations, z-order rules).
// Policy lives in the IWindowManager implementation.
class WindowConductor : ISubsystem
{
	private
	{
		IWindowManager _manager;
		Window[] _windows;
		RenderSubsystem _renderSubsystem;
		SeatManager _seatManager;
		OutputManager _outputManager;
	}

	override string name()
	{
		return "WindowConductor";
	}

	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.Conductor;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		required ~= Services.RenderSubsystem;
		required ~= Services.SeatManager;
		required ~= Services.OutputManager;
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	override void initialize()
	{
		auto render = SubsystemManager.getByService!RenderSubsystem(Services.RenderSubsystem);
		_renderSubsystem = render;
		_seatManager = SubsystemManager.getByService!SeatManager(Services.SeatManager);
		_outputManager = SubsystemManager.getByService!OutputManager(Services.OutputManager);
		logInfo("WindowConductor initialized");
	}

	override void shutdown()
	{
		logInfo("WindowConductor shutdown");
	}

	// Replace the active window manager.
	void setWindowManager(IWindowManager mgr)
	{
		if (_manager !is null)
			_renderSubsystem.removeEntry(_manager);

		_manager = mgr;

		if (_manager !is null)
		{
			_renderSubsystem.addEntry(_manager);
			_manager.startup(this);
			auto caps = _manager.wmCapabilities;
			foreach (w; _windows)
			{
				_manager.onWindowAdded(w);
				w.onWmCapabilitiesChanged(caps);
			}
		}
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

	@property Window[] windows()
	{
		return _windows;
	}

	@property IWindowManager windowManager()
	{
		return _manager;
	}

	@property WmCapabilityFlags wmCapabilities()
	{
		return _manager !is null ? _manager.wmCapabilities : WmCapabilityFlags.none;
	}

	void scheduleRepaint()
	{
		_renderSubsystem.scheduleRepaint();
	}

	void addWindow(Window window)
	{
		assert(_manager !is null, "No IWindowManager set. Call setWindowManager before mapping windows");
		_windows ~= window;
		_manager.onWindowAdded(window);
	}

	void removeWindow(Window window)
	{
		foreach (seat; _seatManager.seats)
		{
			if (seat.keyboardFocusView is window)
				setKeyboardFocus(seat, null);
			if (seat.pointerFocus.view is window)
				setPointerFocus(seat, null);
		}

		damageCurrentBounds(window);

		if (_manager !is null)
			_manager.onWindowRemoved(window);

		_windows = _windows.remove!(w => w is window);

		foreach (w; _windows)
		{
			if (w.parentWindow is window)
				w.parentWindow = window.parentWindow;
		}
		window.parentWindow = null;

		foreach (seat; _seatManager.seats)
		{
			if (seat.keyboardFocusView is null && _windows.length > 0)
				setKeyboardFocus(seat, _windows[$ - 1]);
		}

		_renderSubsystem.scheduleRepaint();
	}

	void setWindowParent(Window window, Window parent)
	{
		window.parentWindow = parent;

		if (window.mapped && parent !is null && _manager !is null)
		{
			_manager.onWindowRaised(window);
			reorderWindowToTop(window);
		}
	}

	void addPopup(Popup popup)
	{
		if (popup.parentWindow is null)
			return;

		popup.mapped = true;

		if (popup.parentPopup !is null)
			popup.parentPopup.childPopup = popup;
		else
			popup.parentWindow.popup = popup;

		if (_manager !is null)
			_manager.onPopupAdded(popup);

		_renderSubsystem.scheduleRepaint();
	}

	void removePopup(Popup popup)
	{
		if (!popup.mapped)
			return;

		_outputManager.addDamage(Rect(popup.absolutePosition(), popup.surfaceSize));

		if (_manager !is null)
			_manager.onPopupRemoved(popup);

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

		_renderSubsystem.scheduleRepaint();
	}

	void requestMaximize(Window w)
	{
		if (_manager !is null)
			_manager.onMaximizeRequest(w);
	}

	void requestUnmaximize(Window w)
	{
		if (_manager !is null)
			_manager.onUnmaximizeRequest(w);
	}

	void requestFullscreen(Window w, OutputManager.ManagedOutput output = null)
	{
		if (_manager !is null)
			_manager.onFullscreenRequest(w, output);
	}

	void requestUnfullscreen(Window w)
	{
		if (_manager !is null)
			_manager.onUnfullscreenRequest(w);
	}

	void requestMinimize(Window w)
	{
		if (_manager !is null)
			_manager.onMinimizeRequest(w);
	}

	// Notify the WM that the window title or app-id changed.
	void notifyWindowTitleChanged(Window window)
	{
		if (_manager !is null)
			_manager.onWindowStateChanged(window);
	}

	// Notify the WM of a client decoration preference.
	void notifyDecorationPreference(Window w, bool ssd)
	{
		w.state.serverDecorations = ssd;
		if (_manager !is null)
			_manager.onDecorationPreference(w, ssd);
	}

	void requestShowWindowMenu(Seat seat, Window window, Vector2I localPos)
	{
		if (_manager !is null)
			_manager.onShowWindowMenuRequest(seat, window, localPos);
	}

	void requestMove(Seat seat, Window window)
	{
		if (_manager !is null)
			_manager.onMoveRequest(seat, window);
	}

	void requestResize(Seat seat, Window window, DecorationHit edge)
	{
		if (_manager !is null)
			_manager.onResizeRequest(seat, window, edge);
	}

	// === Stuff called from the protocol layer ===

	// Called when the client has acked and committed a tracked configure.
	// The protocol layer is responsible for having already applied window.state.flags
	// and called setLayer if needed. Conductor just notifies the WM.
	void notifyWindowConfigureApplied(Window window, Nullable!Vector2I position)
	{
		if (_manager !is null)
			_manager.onWindowConfigureApplied(window, position);

		_renderSubsystem.scheduleRepaint();
	}

	void notifyWindowResizeCommitted(Window window, Vector2U newSize)
	{
		if (_manager !is null)
			_manager.onWindowResizeCommitted(window, newSize);
	}

	void setKeyboardFocus(Seat seat, View view)
	{
		if (seat.keyboardFocusView is view)
			return;

		auto oldWindow = cast(Window) seat.keyboardFocusView;
		seat.keyboardFocusView = view;
		seat.setKeyboardFocusSurface(view !is null ? view.getSurface() : null);

		if (oldWindow !is null)
		{
			oldWindow.state.focused = false;
			if (_manager !is null)
				_manager.onWindowFocusChanged(oldWindow, false);
		}

		if (auto newWindow = cast(Window) view)
		{
			newWindow.state.focused = true;
			if (_manager !is null)
				_manager.onWindowFocusChanged(newWindow, true);
		}

		_renderSubsystem.scheduleRepaint();
	}

	void setPointerFocus(Seat seat, View view)
	{
		if (view is null)
		{
			seat.pointerFocus = PointerFocus.init;
			seat.setPointerFocusSurface(null, 0, 0);
			seat.updateConstraintForFocus(null, Vector2(0, 0));
			return;
		}

		auto mainSurface = view.getSurface();
		if (mainSurface is null)
			return;

		auto cursorF = seat.pointerPosition;
		auto cursor = cast(Vector2I) cursorF;
		auto origin = view.contentOrigin();
		auto ss = mainSurface.computeSurfaceState();
		auto hit = findSurfaceAt(mainSurface, origin, cast(Vector2I) ss.size, cursor);

		seat.pointerFocus = PointerFocus(view, hit.subsurface);
		seat.setPointerFocusSurface(seat.pointerFocus.surface, hit.local.x, hit.local.y);
		seat.updateConstraintForFocus(seat.pointerFocus.surface, Vector2(hit.local.x, hit.local.y));
	}

	void applyGeometry(Window window, Vector2I pos, Vector2U newSize)
	{
		import trinove.debug_.protocol_tracer : traceEnter, Actor;

		auto _t = traceEnter(window, Actor.WM, "applyGeometry");

		damageCurrentBounds(window);
		window.surfaceSize = newSize;
		window.position = pos;

		if (_manager !is null)
			_manager.onWindowStateChanged(window);

		_renderSubsystem.scheduleRepaint();
	}

	void moveWindow(Window window, Vector2I newPos)
	{
		damageCurrentBounds(window);
		window.position = newPos;

		if (_manager !is null)
			_manager.onWindowStateChanged(window);

		_renderSubsystem.scheduleRepaint();
	}

	void damageCurrentBounds(Window window)
	{
		_outputManager.addDamage(Rect(window.position.x, window.position.y, window.surfaceSize.x, window.surfaceSize.y));
	}

	void setLayer(Window window, Layer newLayer)
	{
		if (window.layer == newLayer)
			return;

		window.layer = newLayer;

		if (_manager !is null)
			_manager.onWindowStateChanged(window);

		_renderSubsystem.scheduleRepaint();
	}

	void reorderWindowToTop(Window window)
	{
		_windows = _windows.remove!(w => w is window);
		_windows ~= window;

		foreach (w; _windows)
		{
			if (w.parentWindow is window)
				reorderWindowToTop(w);
		}
	}

	// === Constraint helpers ===

	bool handleLockedPointerMotion(Seat seat, InputEvent event)
	{
		auto c = seat.pointerConstraint;
		if (c is null || !c.active || c.type != ConstraintType.lock)
			return false;

		seat.notifyRelativeMotion(event.timestampMs, event.pointerMotion.delta, event.pointerMotion.deltaUnaccel);
		seat.sendPointerFrame();
		return true;
	}

	Vector2 applyPointerConfine(Seat seat, Vector2 pos)
	{
		auto c = seat.pointerConstraint;
		if (c is null || !c.active || c.type != ConstraintType.confine)
			return pos;

		auto focusedSurface = seat.pointerFocus.surface;
		if (focusedSurface is null)
			return pos;

		auto localPos = seat.pointerFocus.surfaceLocalPosition(pos);
		auto surfaceSize = focusedSurface.computeSurfaceState().size;
		auto clamped = c.clampToRegion(cast(int) localPos.x, cast(int) localPos.y, surfaceSize);
		auto origin = seat.pointerFocus.surfaceOrigin;
		return Vector2(origin.x + clamped.x, origin.y + clamped.y);
	}

	// === Queries ===

	Popup popupAt(Vector2I pos)
	{
		Popup best = null;
		Layer bestLayer = Layer.min;

		foreach (window; _windows)
		{
			if (!window.mapped || window.popup is null)
				continue;
			if (best !is null && window.layer < bestLayer)
				continue;

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

	OutputManager.ManagedOutput outputForWindow(Window window)
	{
		auto geom = window.clientBounds();
		auto cx = window.position.x + geom.position.x + cast(int)(geom.size.x / 2);
		auto cy = window.position.y + geom.position.y + cast(int)(geom.size.y / 2);
		return outputAt(Vector2I(cx, cy));
	}

	OutputManager.ManagedOutput outputAt(Vector2I point)
	{
		foreach (ref mo; _outputManager.outputs)
		{
			auto vp = mo.viewport();
			if (point.x >= vp.position.x && point.x < vp.position.x + cast(int) vp.size.x && point.y >= vp.position.y
					&& point.y < vp.position.y + cast(int) vp.size.y)
				return mo;
		}
		auto outputs = _outputManager.outputs;
		return outputs.length > 0 ? outputs[0] : null;
	}

}
