// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.wm.default_manager;

import trinove.math;
import trinove.layer;
import trinove.renderer : RenderSubsystem;
import trinove.renderer.canvas : ICanvas;
import trinove.backend.input;
import trinove.seat;
import trinove.seat_manager;
import trinove.wm.view;
import trinove.wm.window;
import trinove.wm.popup;
import trinove.wm.decoration;
import trinove.wm.conductor;
import trinove.wm.imanager;
import trinove.wm.seat_state;
import trinove.surface.surface : WaiSurface, SurfaceHit, findSurfaceAt;
import trinove.output_manager;
import trinove.events;
import trinove.debug_.protocol_tracer : traceEnter, Actor;
import std.algorithm : remove;
import std.traits : EnumMembers;
import std.typecons : Nullable;

// Default window management policy.
//
// Like the name says, its a pretty basic floating WM implementation.
class DefaultWindowManager : IWindowManager
{
	private
	{
		WindowConductor _conductor;
		RenderSubsystem _renderSubsystem;
		SeatManager _seatManager;
		OutputManager _outputManager;

		SeatInteraction[Seat] _seatInteractions;

		Vector2I _nextWindowPos = Vector2I(50, 50);
	}

	override @property string name()
	{
		return "Default";
	}

	override @property WmCapabilityFlags wmCapabilities()
	{
		return WmCapabilityFlags.maximize | WmCapabilityFlags.fullscreen;
	}

	override void startup(WindowConductor conductor)
	{
		_conductor = conductor;
		_renderSubsystem = conductor.renderSubsystem;
		_seatManager = conductor.seatManager;
		_outputManager = conductor.outputManager;
		Seat.OnInputEvent.subscribe(&handleInput);
	}

	override void shutdown()
	{
		Seat.OnInputEvent.unsubscribe(&handleInput);
	}

	override void onWindowAdded(Window window)
	{
		Vector2I framePos;
		if (window.parentWindow !is null && window.parentWindow.mapped)
		{
			auto p = window.parentWindow;
			framePos = Vector2I(p.position.x + (cast(int) p.surfaceSize.x - cast(int) window.surfaceSize.x) / 2,
					p.position.y + (cast(int) p.surfaceSize.y - cast(int) window.surfaceSize.y) / 2);
		}
		else
		{
			framePos = _nextWindowPos;
			_nextWindowPos.x += 10;
			_nextWindowPos.y += 10;
			if (_nextWindowPos.x > 400)
				_nextWindowPos.x = 100;
			if (_nextWindowPos.y > 400)
				_nextWindowPos.y = 100;
		}

		window.position = framePos;

		foreach (seat; _seatManager.seats)
			_conductor.setKeyboardFocus(seat, window);

		OnWindowAdded.fire(window);
		_renderSubsystem.scheduleRepaint();
	}

	override void onWindowRemoved(Window window)
	{
		foreach (seat; _seatInteractions.byKey())
		{
			if (auto si = seat in _seatInteractions)
			{
				if (si.interactionView is window)
					si.endInteraction();
			}
		}

		OnWindowRemoved.fire(window);
	}

	override void onPopupAdded(Popup popup)
	{
	}

	override void onPopupRemoved(Popup popup)
	{
	}

	override void onWindowStateChanged(Window window)
	{
	}

	override void onWindowFocusChanged(Window window, bool focused)
	{
		if (focused)
			raiseWindow(window);

		_renderSubsystem.scheduleRepaint();
	}

	override void onWindowRaised(Window window)
	{
	}

	override void onMaximizeRequest(Window window)
	{
		auto _t = traceEnter(window, Actor.WM, "maximize");

		if (window.state.maximized)
			return;

		auto geom = window.clientBounds();
		window.savedGeometry = Rect(window.position + geom.position, geom.size);

		auto output = _conductor.outputForWindow(window);
		if (output is null)
			return;
		auto area = output.viewport();

		window.configure().maximize().size(area.size).position(area.position).send();
	}

	override void onUnmaximizeRequest(Window window)
	{
		auto _t = traceEnter(window, Actor.WM, "unmaximize");

		if (!window.state.maximized)
			return;

		auto restoreGeo = window.savedGeometry;

		window.configure().unmaximize().size(restoreGeo.size).position(restoreGeo.position).send();
	}

	override void onFullscreenRequest(Window window, OutputManager.ManagedOutput output)
	{
		auto _t = traceEnter(window, Actor.WM, "fullscreen");

		if (window.state.fullscreen)
			return;

		if (!window.state.maximized)
		{
			auto geom = window.clientBounds();
			window.savedGeometry = Rect(window.position + geom.position, geom.size);
		}

		if (output is null)
			output = _conductor.outputForWindow(window);
		if (output is null)
			return;
		auto area = output.viewport();

		window.configure().fullscreen().size(area.size).position(area.position).send();
	}

	override void onUnfullscreenRequest(Window window)
	{
		auto _t = traceEnter(window, Actor.WM, "unfullscreen");

		if (!window.state.fullscreen)
			return;

		auto restoreGeo = window.savedGeometry;

		if (window.state.maximized)
		{
			auto output = _conductor.outputForWindow(window);
			if (output !is null)
				restoreGeo = output.viewport();
		}

		window.configure().unfullscreen().size(restoreGeo.size).position(restoreGeo.position).send();
	}

	override void onMinimizeRequest(Window window)
	{
		window.state.minimized = true;
		_renderSubsystem.scheduleRepaint();
	}

	override void onDecorationPreference(Window window, bool ssd)
	{
		window.state.serverDecorations = false;
	}

	override void onShowWindowMenuRequest(Seat seat, Window window, Vector2I localPos)
	{
	}

	override void onMoveRequest(Seat seat, Window window)
	{
		auto si = getOrCreateSeatInteraction(seat);
		auto pos = seat.pointerPosition;
		si.beginMove(window, cast(Vector2I) pos, window.position);
	}

	override void onResizeRequest(Seat seat, Window window, DecorationHit edge)
	{
		auto si = getOrCreateSeatInteraction(seat);
		auto pos = seat.pointerPosition;
		si.beginResize(window, cast(Vector2I) pos, window.position, window.clientBounds().size, edge);
		window.state.resizing = true;

		window.configure().size(window.clientBounds().size).send();
	}

	override void onWindowConfigureApplied(Window window, Nullable!Vector2I position)
	{
		auto pos = position.isNull ? window.position : position.get;
		_conductor.applyGeometry(window, pos, window.surfaceSize);
	}

	override void onWindowResizeCommitted(Window window, Vector2U newSize)
	{
		foreach (seat; _seatManager.seats)
		{
			if (auto si = seat in _seatInteractions)
			{
				if (si.interactionView is window && si.interaction == InteractionType.Resize)
				{
					auto adj = si.getResizePositionAdjustment(window.surfaceSize, newSize);
					auto newPos = Vector2I(window.position.x + adj.x, window.position.y + adj.y);
					_conductor.applyGeometry(window, newPos, newSize);
					return;
				}
			}
		}

		_conductor.applyGeometry(window, window.position, newSize);
	}

	override @property bool visible()
	{
		return true;
	}

	override void draw(ICanvas canvas, OutputManager.ManagedOutput output)
	{
		foreach (layer; EnumMembers!Layer)
		{
			foreach (window; _conductor.windows)
			{
				if (window.layer != layer) continue;
				if (!window.mapped || window.state.minimized) continue;

				window.draw(canvas, window.position);
				drawPopupChain(canvas, window.popup);
			}
		}

		_seatManager.drawSoftwareCursors(canvas, output);
	}

	override void pushDamage(OutputManager om, OutputManager.ManagedOutput output)
	{
		foreach (window; _conductor.windows)
		{
			if (!window.mapped) continue;
			window.pushDamage(om, output);

			auto popup = window.popup;
			while (popup !is null)
			{
				if (popup.mapped)
					popup.pushDamage(om, output);
				popup = popup.childPopup;
			}
		}

		_seatManager.pushCursorDamage(om, output);
	}

	override void onFramePresented(OutputManager.ManagedOutput output)
	{
		foreach (window; _conductor.windows)
		{
			if (window.mapped && !window.state.minimized)
				window.fireAllCallbacks();

			auto popup = window.popup;
			while (popup !is null)
			{
				if (popup.mapped)
					popup.fireAllCallbacks();
				popup = popup.childPopup;
			}
		}
	}

	void raiseWindow(Window window)
	{
		onWindowRaised(window);
		_conductor.reorderWindowToTop(window);
	}

	void toggleMaximize(Window window)
	{
		if (window.state.maximized)
			onUnmaximizeRequest(window);
		else
			onMaximizeRequest(window);
	}

	void dismissPopups(Window window)
	{
		if (window.popup is null)
			return;
		window.popup.dismiss();
	}

	void dismissPopupsOutside(Seat seat, Vector2I pos)
	{
		foreach (window; _conductor.windows)
		{
			if (window.popup is null)
				continue;

			auto popup = window.popup;
			while (popup.childPopup !is null)
				popup = popup.childPopup;

			while (popup !is null)
			{
				if (popup.grabbedSeat is seat && !popup.containsPoint(pos))
				{
					popup.dismiss();
					return;
				}
				popup = popup.parentPopup;
			}
		}
	}

	Window windowAt(Vector2I pos)
	{
		Window best = null;
		foreach (window; _conductor.windows)
		{
			if (!window.mapped)
				continue;

			bool hit = window.inputBounds().contains(pos);
			if (hit && (best is null || window.layer >= best.layer))
				best = window;
		}
		return best;
	}

	// === Input handling ===

	private void handleInput(Seat seat, InputEvent event)
	{
		bool consumed = false;

		switch (event.type)
		{
		case InputEventType.keyPress:
			consumed = handleKeyPress(seat, event);
			break;

		case InputEventType.pointerMotionAbsolute:
			consumed = handlePointerMotion(seat, event.pointerAbsolute.pos);
			break;

		case InputEventType.pointerMotion:
			if (_conductor.handleLockedPointerMotion(seat, event))
			{
				consumed = true;
				break;
			}
			consumed = handlePointerMotion(seat, seat.pointerPosition + event.pointerMotion.delta);
			break;

		case InputEventType.pointerButton:
			consumed = handlePointerButton(seat, event.pointerButton.button, event.pointerButton.pressed);
			break;

		default:
			break;
		}

		if (!consumed)
		{
			auto local = seat.pointerFocusSurface !is null
				? seat.surfaceLocalPosition(seat.pointerPosition) : Vector2.init;
			seat.notifyFocusedClient(event, local);
		}
	}

	private bool handleKeyPress(Seat seat, InputEvent event)
	{
		import linux.input : KEY_F1, KEY_F4;

		bool shiftHeld = false;
		if (event.device !is null)
		{
			uint depressed, latched, locked, group;
			event.device.getModifiers(depressed, latched, locked, group);
			shiftHeld = (depressed & 1) != 0;
		}

		if (!shiftHeld)
			return false;

		switch (event.key.keycode)
		{
		case KEY_F1:
			toggleDamageOverlay();
			return true;

		case KEY_F4:
			import trinove.display_manager : getDisplay;

			getDisplay().terminate();
			return true;

		default:
			return false;
		}
	}

	private void toggleDamageOverlay()
	{
		import trinove.renderer.subsystem : RenderSubsystem;
		import trinove.subsystem : SubsystemManager, Services;
		import trinove.log : logInfo;

		auto rs = SubsystemManager.getByService!RenderSubsystem(Services.RenderSubsystem);
		if (rs is null)
			return;

		rs.showDamageOverlay = !rs.showDamageOverlay;
		logInfo("Damage overlay: %s", rs.showDamageOverlay ? "on" : "off");

		_outputManager.damageAll();
		_renderSubsystem.scheduleRepaint();
	}

	private bool handlePointerMotion(Seat seat, Vector2 pos)
	{
		pos = _outputManager.constrainToOutputs(pos);
		pos = _conductor.applyPointerConfine(seat, pos);
		seat.pointerPosition = pos;

		auto posI = cast(Vector2I) pos;

		if (auto si = seat in _seatInteractions)
		{
			if (si.interaction != InteractionType.None)
			{
				Vector2I newPos;
				Vector2U newSize;

				if (si.updateInteraction(posI, newPos, newSize))
				{
					auto window = cast(Window) si.interactionView;

					if (si.interaction == InteractionType.Move)
					{
						_conductor.moveWindow(window, newPos);
					}
					else if (si.interaction == InteractionType.Resize && newSize != window.clientBounds().size)
					{
						window.configure().size(newSize).position(newPos).send();
					}
				}
				return true;
			}
		}

		auto popup = _conductor.popupAt(posI);
		if (popup !is null)
		{
			updatePointerFocus(seat, popup);
			return false;
		}

		auto window = windowAt(posI);
		updatePointerFocus(seat, window);
		return false;
	}

	private bool handlePointerButton(Seat seat, uint button, bool pressed)
	{
		auto pos = cast(Vector2I) seat.pointerPosition;

		if (!pressed)
		{
			if (auto si = seat in _seatInteractions)
			{
				if (si.interaction != InteractionType.None)
				{
					si.endInteraction();
					return false;
				}
			}
			return false;
		}

		auto popup = _conductor.popupAt(pos);
		if (popup !is null)
		{
			updatePointerFocus(seat, popup);
			return false;
		}

		dismissPopupsOutside(seat, pos);

		auto window = windowAt(pos);
		if (window is null)
			return false;

		_conductor.setKeyboardFocus(seat, window);
		return false;
	}

	private void updatePointerFocus(Seat seat, View view)
	{
		_conductor.setPointerFocus(seat, view);
	}

	private void drawPopupChain(ICanvas canvas, Popup popup)
	{
		if (popup is null || !popup.mapped) return;
			popup.draw(canvas, popup.absolutePosition());
		drawPopupChain(canvas, popup.childPopup);
	}

	private SeatInteraction getOrCreateSeatInteraction(Seat seat)
	{
		if (auto si = seat in _seatInteractions)
			return *si;
		auto si = new SeatInteraction();
		_seatInteractions[seat] = si;
		return si;
	}
}
