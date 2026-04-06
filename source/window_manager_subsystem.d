// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module default_compositor;

import trinove.compositor;
import trinove.subsystem;
import trinove.wm;
import trinove.math;
import trinove.layer;
import trinove.renderer.canvas : ICanvas, IRenderEntry;
import trinove.seat;
import trinove.output_manager;
import trinove.backend.input;
import trinove.events;
import trinove.log;
import std.traits : EnumMembers;
import std.typecons : Nullable;

//This is a pretty simple compositor implementation that makes use of compositor space.
class DefaultCompositor : TrinoveCompositor, IRenderEntry
{
	private
	{
		SeatInteraction[Seat] _seatInteractions;
		Vector2I _nextWindowPos = Vector2I(50, 50);
	}

	override string name()
	{
		return "DefaultCompositor";
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		super.getRequiredServices(required);
	}

	override void initialize()
	{
		super.initialize();
		renderSubsystem.addEntry(this);
		Seat.OnInputEvent.subscribe(&handleInput);
		Seat.OnSeatAdded.subscribe(&onSeatAdded);
		Seat.OnSeatRemoved.subscribe(&onSeatRemoved);
	}

	override void shutdown()
	{
		Seat.OnSeatRemoved.unsubscribe(&onSeatRemoved);
		Seat.OnSeatAdded.unsubscribe(&onSeatAdded);
		Seat.OnInputEvent.unsubscribe(&handleInput);
		renderSubsystem.removeEntry(this);
		super.shutdown();
	}

	// === Window lifecycle ===

	override void addWindow(Window window)
	{
		super.addWindow(window);

		window.onWmCapabilitiesChanged(WmCapabilityFlags.maximize | WmCapabilityFlags.fullscreen);

		Vector2I pos;
		if (window.parentWindow !is null && window.parentWindow.mapped)
		{
			auto p = window.parentWindow;
			pos = Vector2I(
				p.position.x + (cast(int) p.surfaceSize.x - cast(int) window.surfaceSize.x) / 2,
				p.position.y + (cast(int) p.surfaceSize.y - cast(int) window.surfaceSize.y) / 2);
		}
		else
		{
			pos = _nextWindowPos;
			_nextWindowPos.x += 10;
			_nextWindowPos.y += 10;
			if (_nextWindowPos.x > 400) _nextWindowPos.x = 100;
			if (_nextWindowPos.y > 400) _nextWindowPos.y = 100;
		}

		window.position = pos;

		foreach (seat; seatManager.seats)
			seat.setKeyboardFocusView(window);

		raiseWindow(window);
		OnWindowAdded.fire(window);
		renderSubsystem.scheduleRepaint();
	}

	override void removeWindow(Window window)
	{
		foreach (seat; _seatInteractions.byKey())
		{
			if (auto si = seat in _seatInteractions)
			{
				if (si.interactionView is window)
					si.endInteraction();
			}
		}

		super.removeWindow(window);

		OnWindowRemoved.fire(window);
		renderSubsystem.scheduleRepaint();
	}

	// === Abstract hooks from TrinoveCompositor ===

	override void onApplyGeometry(Window window, Vector2I position, Vector2U size)
	{
		applyWindowGeometry(window, position, size);
	}

	override void onMaximizeRequest(Window window, bool bWantsMaximize)
	{
		if (bWantsMaximize)
		{
			if (window.state.maximized) return;
			auto geom = window.clientBounds();
			window.savedGeometry = Rect(window.position + geom.position, geom.size);
			auto output = outputManager.findPrimaryOutput(window.clientGeometry());
			if (output is null) return;
			auto area = output.viewport();
			window.configure().maximize().size(area.size).position(area.position).send();
		}
		else
		{
			if (!window.state.maximized) return;
			auto restoreGeo = window.savedGeometry;
			window.configure().unmaximize().size(restoreGeo.size).position(restoreGeo.position).send();
		}
	}

	override void onFullscreenRequest(Window window, bool bWantsFullscreen, OutputManager.ManagedOutput requestedOutput)
	{
		if (bWantsFullscreen)
		{
			if (window.state.fullscreen) return;
			if (!window.state.maximized)
			{
				auto geom = window.clientBounds();
				window.savedGeometry = Rect(window.position + geom.position, geom.size);
			}
			auto output = requestedOutput !is null ? requestedOutput : outputManager.findPrimaryOutput(window.clientGeometry());
			if (output is null) return;
			auto area = output.viewport();
			window.configure().fullscreen().size(area.size).position(area.position).send();
		}
		else
		{
			if (!window.state.fullscreen) return;
			auto restoreGeo = window.savedGeometry;
			if (window.state.maximized)
			{
				auto o = outputManager.findPrimaryOutput(window.clientGeometry());
				if (o !is null)
					restoreGeo = o.viewport();
			}
			window.configure().unfullscreen().size(restoreGeo.size).position(restoreGeo.position).send();
		}
	}

	override void onMinimizeRequest(Window window)
	{
		window.state.minimized = true;
		outputManager.addDamage(window.clientGeometry());
		renderSubsystem.scheduleRepaint();
	}

	override void onWindowTitleChange(Window window)
	{
	}

	override void onWindowDecorationPreferenceChange(Window window, bool bWantsSSD)
	{
		window.state.serverDecorations = false;
	}

	override void onShowWindowMenuRequest(Window window, Seat seat, Vector2I localPos)
	{
	}

	override void onMoveWindowRequest(Window window, Seat seat)
	{
		auto si = getOrCreateSeatInteraction(seat);
		si.beginMove(window, cast(Vector2I) seat.pointerPosition, window.position);
	}

	override void onResizeWindowRequest(Window window, Seat seat, DecorationHit edges)
	{
		auto si = getOrCreateSeatInteraction(seat);
		si.beginResize(window, cast(Vector2I) seat.pointerPosition, window.position, window.clientBounds().size, edges);
		window.state.resizing = true;
		window.configure().size(window.clientBounds().size).send();
	}

	override void onWindowConfigureApplied(Window window, Nullable!Vector2I position)
	{
		auto pos = position.isNull ? window.position : position.get;
		applyWindowGeometry(window, pos, window.surfaceSize);
	}

	override void onWindowResizeCommited(Window window, Vector2U newSize)
	{
		foreach (seat; seatManager.seats)
		{
			if (auto si = seat in _seatInteractions)
			{
				if (si.interactionView is window && si.interaction == InteractionType.Resize)
				{
					auto adj = si.getResizePositionAdjustment(window.surfaceSize, newSize);
					applyWindowGeometry(window,
						Vector2I(window.position.x + adj.x, window.position.y + adj.y),
						newSize);
					return;
				}
			}
		}
		applyWindowGeometry(window, window.position, newSize);
	}

	// === IRenderEntry ===

	override @property bool visible()
	{
		return true;
	}

	override void draw(ICanvas canvas, OutputManager.ManagedOutput output)
	{
		foreach (layer; EnumMembers!Layer)
		{
			foreach (window; _windows)
			{
				if (window.layer != layer) continue;
				if (!window.mapped || window.state.minimized) continue;
				window.draw(canvas, window.position);
				drawPopupChain(canvas, window.popup);
			}
		}
		seatManager.drawSoftwareCursors(canvas, output);
	}

	override void pushDamage(OutputManager om, OutputManager.ManagedOutput output)
	{
		foreach (window; _windows)
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
		seatManager.pushCursorDamage(om, output);
	}

	override void onFramePresented(OutputManager.ManagedOutput output)
	{
		foreach (window; _windows)
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

	// === Helpers ===

	void raiseWindow(Window window)
	{
		reorderWindowToTop(window);
		renderSubsystem.scheduleRepaint();
	}

	void toggleMaximize(Window window)
	{
		onMaximizeRequest(window, !window.state.maximized);
	}

	void dismissPopups(Window window)
	{
		if (window.popup !is null)
			window.popup.dismiss();
	}

	void dismissPopupsOutside(Seat seat, Vector2I pos)
	{
		foreach (window; _windows)
		{
			if (window.popup is null) continue;
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
		foreach (window; _windows)
		{
			if (!window.mapped) continue;
			if (window.inputBounds().contains(pos) && (best is null || window.layer >= best.layer))
				best = window;
		}
		return best;
	}

	// === Seat events ===

	private void onSeatAdded(Seat seat)
	{
		// Focus the top window on the new seat if any are mapped
		foreach_reverse (window; _windows)
		{
			if (window.mapped && !window.state.minimized)
			{
				seat.setKeyboardFocusView(window);
				break;
			}
		}
	}

	private void onSeatRemoved(Seat seat)
	{
		if (auto si = seat in _seatInteractions)
		{
			si.endInteraction();
			_seatInteractions.remove(seat);
		}
	}

	// === Input ===

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
			if (handleLockedPointerMotion(seat, event))
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

		if (!shiftHeld) return false;

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
		renderSubsystem.showDamageOverlay = !renderSubsystem.showDamageOverlay;
		logInfo("Damage overlay: %s", renderSubsystem.showDamageOverlay ? "on" : "off");
		outputManager.damageAll();
		renderSubsystem.scheduleRepaint();
	}

	private bool handlePointerMotion(Seat seat, Vector2 pos)
	{
		pos = outputManager.constrainToOutputs(pos);

		auto focusView = seat.pointerFocus.view;
		if (focusView !is null && hasActivePointerConfine(seat))
		{
			auto localPos = pos - cast(Vector2) focusView.contentOrigin();
			auto confined = applyPointerConfine(seat, localPos);
			pos = cast(Vector2) focusView.contentOrigin() + confined;
		}

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
						applyWindowGeometry(window, newPos, window.surfaceSize);
					}
					else if (si.interaction == InteractionType.Resize && newSize != window.clientBounds().size)
						window.configure().size(newSize).position(newPos).send();
				}
				return true;
			}
		}

		auto popup = popupAt(posI);
		if (popup !is null)
		{
			seat.setPointerFocusView(popup, seat.pointerPosition - cast(Vector2) popup.contentOrigin());
			return false;
		}

		auto window = windowAt(posI);
		seat.setPointerFocusView(window, window !is null ? seat.pointerPosition - cast(Vector2) window.contentOrigin() : Vector2.init);
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

		auto popup = popupAt(pos);
		if (popup !is null)
		{
			seat.setPointerFocusView(popup, seat.pointerPosition - cast(Vector2) popup.contentOrigin());
			return false;
		}

		dismissPopupsOutside(seat, pos);

		auto window = windowAt(pos);
		if (window is null) return false;

		seat.setKeyboardFocusView(window);
		raiseWindow(window);
		return false;
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

	private void applyWindowGeometry(Window window, Vector2I position, Vector2U size)
	{
		auto oldBounds = window.clientGeometry();
		window.position = position;
		window.surfaceSize = size;

		//Output manager works in compositor space which is what outputs are positioned in.
		//Since our compositor positions windows in output / compositor space we can directly
		// add the damage without needing to do any coordinate translation.
		outputManager.addDamage(oldBounds);
		outputManager.addDamage(window.clientGeometry());
		renderSubsystem.scheduleRepaint();
	}
}
