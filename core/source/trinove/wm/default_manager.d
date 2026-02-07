// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.wm.default_manager;

import trinove.math;
import trinove.layer;
import trinove.renderer.scene;
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
import std.typecons : Nullable;

// Default window management policy.
//
// Like the name says, its a pretty basic floating WM implementation.
class DefaultWindowManager : IWindowManager
{
	private
	{
		WindowConductor _conductor;
		SceneGraph _scene;
		SeatManager _seatManager;
		OutputManager _outputManager;

		WindowDecoration[Window] _decorations;
		SeatInteraction[Seat] _seatInteractions;

		// Cascade placement state.
		Vector2I _nextWindowPos;
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
		_scene = conductor.scene;
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
		// Placement
		if (window.parentWindow !is null && window.parentWindow.mapped)
		{
			auto p = window.parentWindow;
			window.position = Vector2I(p.position.x + (cast(int) p.surfaceSize.x - cast(int) window.surfaceSize.x) / 2,
					p.position.y + (cast(int) p.surfaceSize.y - cast(int) window.surfaceSize.y) / 2);
		}
		else
		{
			window.position = _nextWindowPos;
			_nextWindowPos.x += 10;
			_nextWindowPos.y += 10;
			if (_nextWindowPos.x > 400)
				_nextWindowPos.x = 100;
			if (_nextWindowPos.y > 400)
				_nextWindowPos.y = 100;
		}

		// Scene graph setup
		window.containerNode.position = Vector2F(window.position.x, window.position.y);
		window.containerNode.visible = true;
		window.contentNode.size = Vector2F(window.surfaceSize.x, window.surfaceSize.y);
		_scene.layerRoots[window.layer].addChild(window.containerNode);

		// Apply SSD if requested
		if (window.state.serverDecorations)
			applyDecoration(window);

		// Give keyboard focus
		foreach (seat; _seatManager.seats)
			_conductor.setKeyboardFocus(seat, window);

		OnWindowAdded.fire(window);
		_scene.scheduleRepaint();
	}

	override void onWindowRemoved(Window window)
	{
		// End any active interaction on this window
		foreach (seat; _seatInteractions.byKey())
		{
			if (auto si = seat in _seatInteractions)
			{
				if (si.interactionView is window)
					si.endInteraction();
			}
		}

		// Remove decoration
		if (auto dec = window in _decorations)
		{
			if (dec.container.parent !is null)
				dec.container.parent.removeChild(dec.container);
			_decorations.remove(window);
		}
		else
		{
			if (window.containerNode.parent !is null)
				window.containerNode.parent.removeChild(window.containerNode);
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
		if (auto dec = window in _decorations)
		{
			dec.clientPosition = window.position;
			dec.updateGeometry();
			dec.container.addFullDamage();
		}
		else
		{
			window.containerNode.position = Vector2F(window.position.x, window.position.y);
			window.contentNode.size = Vector2F(window.surfaceSize.x, window.surfaceSize.y);
			window.containerNode.addFullDamage();
		}
	}

	override void onWindowFocusChanged(Window window, bool focused)
	{
		if (auto dec = window in _decorations)
			dec.updateFocus(focused);

		if (focused)
			raiseWindow(window);

		_scene.scheduleRepaint();
	}

	override void onWindowRaised(Window window)
	{
		auto layerRoot = _scene.layerRoots[window.layer];

		if (auto dec = window in _decorations)
		{
			layerRoot.removeChild(dec.container);
			layerRoot.addChild(dec.container);
		}
		else
		{
			layerRoot.removeChild(window.containerNode);
			layerRoot.addChild(window.containerNode);
		}
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

		// Hide decorations immediately for fullscreen
		removeDecoration(window);

		window.configure().fullscreen().size(area.size).position(area.position).send();
	}

	override void onUnfullscreenRequest(Window window)
	{
		auto _t = traceEnter(window, Actor.WM, "unfullscreen");

		if (!window.state.fullscreen)
			return;

		auto restoreGeo = window.savedGeometry;

		// If window was maximized before fullscreen, restore to maximized
		if (window.state.maximized)
		{
			auto output = _conductor.outputForWindow(window);
			if (output !is null)
				restoreGeo = output.viewport();
		}

		// Restore decorations if window prefers SSD
		if (window.state.serverDecorations)
			applyDecoration(window);

		window.configure().unfullscreen().size(restoreGeo.size).position(restoreGeo.position).send();
	}

	override void onMinimizeRequest(Window window)
	{
		window.state.minimized = true;
		window.syncVisibility();
		_scene.scheduleRepaint();
	}

	override void onDecorationPreference(Window window, bool ssd)
	{
		if (ssd)
			applyDecoration(window);
		else
			removeDecoration(window);
	}

	override void onShowWindowMenuRequest(Seat seat, Window window, Vector2I localPos)
	{
	}

	override void onMoveRequest(Seat seat, Window window)
	{
		auto si = getOrCreateSeatInteraction(seat);
		auto pos = seat.pointerPosition;
		si.beginMove(window, Vector2I(cast(int) pos.x, cast(int) pos.y), window.position);
	}

	override void onResizeRequest(Seat seat, Window window, DecorationHit edge)
	{
		auto si = getOrCreateSeatInteraction(seat);
		auto pos = seat.pointerPosition;
		si.beginResize(window, Vector2I(cast(int) pos.x, cast(int) pos.y), window.position, window.clientBounds().size, edge);
		window.state.resizing = true;

		// Send an initial resize configure to tell the client it's resizing.
		window.configure().size(window.clientBounds().size).send();
	}

	// === Configure lifecycle ===

	override void onWindowConfigureApplied(Window window, Nullable!Vector2I position)
	{
		auto pos = position.isNull ? window.position : position.get;
		_conductor.applyGeometry(window, pos, window.surfaceSize);
	}

	override void onWindowResizeCommitted(Window window, Vector2U newSize)
	{
		// Find the seat currently resizing this window
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

		// No active resize interaction — just apply the new size at current position
		_conductor.applyGeometry(window, window.position, newSize);
	}

	bool isDecorated(Window window)
	{
		return (window in _decorations) !is null;
	}

	WindowDecoration getDecoration(Window window)
	{
		if (auto dec = window in _decorations)
			return *dec;
		return null;
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
			if (!hit)
			{
				if (auto dec = window in _decorations)
					hit = dec.hitTest(pos) != DecorationHit.None;
			}

			if (hit && (best is null || window.layer >= best.layer))
				best = window;
		}
		return best;
	}

	// === Input handling ===

	private void handleInput(Seat seat, InputEvent event)
	{
		bool handled = false;

		switch (event.type)
		{
		case InputEventType.keyPress:
			handled = handleKeyPress(seat, event);
			break;

		case InputEventType.pointerMotionAbsolute:
			handled = handlePointerMotion(seat, event.pointerAbsolute.pos);
			break;

		case InputEventType.pointerMotion:
			if (_conductor.handleLockedPointerMotion(seat, event))
			{
				handled = true;
				break;
			}
			handled = handlePointerMotion(seat, seat.pointerPosition + event.pointerMotion.delta);
			break;

		case InputEventType.pointerButton:
			handled = handlePointerButton(seat, event.pointerButton.button, event.pointerButton.pressed);
			break;

		default:
			break;
		}

		if (!handled)
			seat.dispatchToFocusedClient(event);
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

		rs.renderer.showDamageOverlay = !rs.renderer.showDamageOverlay;
		logInfo("Damage overlay: %s", rs.renderer.showDamageOverlay ? "on" : "off");

		_outputManager.damageAll();
		_scene.scheduleRepaint();
	}

	private bool handlePointerMotion(Seat seat, Vector2 pos)
	{
		pos = _outputManager.constrainToOutputs(pos);
		pos = _conductor.applyPointerConfine(seat, pos);
		seat.pointerPosition = pos;

		auto posI = Vector2I(cast(int) pos.x, cast(int) pos.y);

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
		auto pos = Vector2I(cast(int) seat.pointerPosition.x, cast(int) seat.pointerPosition.y);

		if (!pressed)
		{
			if (auto si = seat in _seatInteractions)
			{
				if (si.interaction != InteractionType.None)
				{
					si.endInteraction();
					return false; // let the client know about the button release.
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

		if (auto dec = window in _decorations)
		{
			auto hit = dec.hitTest(pos);

			final switch (hit)
			{
			case DecorationHit.None:
			case DecorationHit.Content:
				return false;

			case DecorationHit.Titlebar:
				onMoveRequest(seat, window);
				return true;

			case DecorationHit.CloseButton:
				window.close();
				return true;

			case DecorationHit.MaximizeButton:
				toggleMaximize(window);
				return true;

			case DecorationHit.MinimizeButton:
				onMinimizeRequest(window);
				return true;

			case DecorationHit.ResizeTop:
			case DecorationHit.ResizeBottom:
			case DecorationHit.ResizeLeft:
			case DecorationHit.ResizeRight:
			case DecorationHit.ResizeTopLeft:
			case DecorationHit.ResizeTopRight:
			case DecorationHit.ResizeBottomLeft:
			case DecorationHit.ResizeBottomRight:
				onResizeRequest(seat, window, hit);
				return true;
			}
		}

		return false;
	}

	private void updatePointerFocus(Seat seat, View view)
	{
		_conductor.setPointerFocus(seat, view);
	}

	// === Decoration helpers ===

	private void applyDecoration(Window window)
	{
		if (window in _decorations)
			return;

		if (window.containerNode.parent !is null)
			window.containerNode.parent.removeChild(window.containerNode);

		auto decoration = new WindowDecoration(window);
		_decorations[window] = decoration;

		decoration.clientPosition = window.position;
		decoration.updateGeometry();

		_scene.layerRoots[window.layer].addChild(decoration.container);
		_scene.scheduleRepaint();
	}

	private void removeDecoration(Window window)
	{
		auto decPtr = window in _decorations;
		if (decPtr is null)
			return;

		auto decoration = *decPtr;

		if (decoration.container.parent !is null)
			decoration.container.parent.removeChild(decoration.container);

		decoration.container.removeChild(window.containerNode);

		window.containerNode.position = Vector2F(window.position.x, window.position.y);
		_scene.layerRoots[window.layer].addChild(window.containerNode);

		_decorations.remove(window);
		_scene.scheduleRepaint();
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
