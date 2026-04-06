// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.seat_manager;

import trinove.cursor;
import trinove.seat;
import trinove.log;
import trinove.math;
import trinove.subsystem;
import trinove.display_manager;
import trinove.backend.input;
import trinove.layer : Layer;
import trinove.renderer.canvas : ICanvas, BufferTransform;
import trinove.renderer.subsystem : RenderSubsystem;
import trinove.gpu.itexture : ITexture;
import trinove.output : CursorPlane;
import trinove.output_manager : OutputManager;
import trinove.surface.buffer : IWaylandBuffer;
import wayland.server;
import std.algorithm : remove;

// Per-seat software cursor render state.
private struct SoftwareCursorState
{
	ITexture texture;
	float[4] srcRect = [0.0f, 0.0f, 1.0f, 1.0f];
	Vector2F position;
	Vector2F size;
	bool visible;

	// Pending compositor-space damage rects (max 2: old + new position).
	private Rect[2] _damage;
	private int _damageCount;

	void addDamage(Rect r)
	{
		if (_damageCount < cast(int) _damage.length)
			_damage[_damageCount++] = r;
	}

	Rect[] pendingDamage() { return _damage[0 .. _damageCount]; }
	void clearDamage() { _damageCount = 0; }

	Rect currentRect() const
	{
		return Rect(cast(Vector2I) position, cast(Vector2U) size);
	}
}

// Manages all seats in the compositor.
//
// Handles seat creation/destruction, device assignment, and input routing.
// Receives raw input events, finds the owning seat, and routes through listeners.
// If no listener handles the event, it's dispatched to the client via the seat.
class SeatManager : ISubsystem
{
	override string name()
	{
		return "SeatManager";
	}

	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.SeatManager;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		required ~= Services.OutputManager;
		required ~= Services.InputBackend;
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	override void initialize()
	{
		_display = getDisplay();

		_defaultSeat = new Seat(_display, this, "seat0");
		_seats ~= _defaultSeat;
		Seat.OnSeatAdded.fire(_defaultSeat);

		// Only claim HW cursor if any output has a cursor plane
		if (hasAnyCursorPlane())
			claimHardwareCursor(_defaultSeat);

		// Connect to input backend if available
		auto inputBackend = SubsystemManager.getByService!InputBackend(Services.InputBackend);
		if (inputBackend !is null)
		{
			assignAllDevices(inputBackend);
			connectInputBackend(inputBackend);
		}

		logInfo("SeatManager initialized with default seat: seat0");
	}

	override void shutdown()
	{
		logInfo("SeatManager shutdown");
	}

	private
	{
		WlDisplay _display;
		Seat[] _seats;
		Seat _defaultSeat;

		// Cursor management
		Seat _hwCursorOwner; // Only one seat can use HW cursor
		SoftwareCursorState[Seat] _swCursorStates;
	}

	@property Seat defaultSeat()
	{
		return _defaultSeat;
	}

	@property Seat[] seats()
	{
		return _seats;
	}

	// Find which seat owns a given device
	Seat findSeatForDevice(InputDevice device)
	{
		foreach (seat; _seats)
		{
			if (seat.ownsDevice(device))
				return seat;
		}
		return null;
	}

	// Find seat for a wl_seat resource.
	// Returns the owning seat, or default seat if not found.
	Seat findSeatForResource(WlResource seatRes)
	{
		if (seatRes is null)
			return _defaultSeat;

		foreach (seat; _seats)
		{
			if (seat.ownsResource(seatRes))
				return seat;
		}

		return _defaultSeat;
	}

	void assignDevice(InputDevice device, Seat seat = null)
	{
		if (seat is null)
			seat = _defaultSeat;

		// Remove from any existing seat first
		foreach (s; _seats)
		{
			if (s.ownsDevice(device))
			{
				s.removeDevice(device);
				break;
			}
		}

		seat.addDevice(device);
		logInfo("Assigned device '%s' to seat '%s'", device.name, seat.name);
	}

	// Assign all devices from an input backend to the default seat
	void assignAllDevices(InputBackend backend)
	{
		foreach (device; backend.devices())
		{
			assignDevice(device);
		}
	}

	Seat createSeat(string name)
	{
		auto seat = new Seat(_display, this, name);
		_seats ~= seat;
		logInfo("Created seat: %s", name);
		return seat;
	}

	void removeSeat(Seat seat)
	{
		if (seat is _defaultSeat)
		{
			logWarn("Cannot remove default seat");
			return;
		}

		// Move devices to default seat
		foreach (device; seat.devices)
		{
			assignDevice(device, _defaultSeat);
		}

		Seat.OnSeatRemoved.fire(seat);
		_seats = _seats.remove!(s => s is seat);
		_swCursorStates.remove(seat);
		logInfo("Removed seat: %s", seat.name);
	}

	// === Cursor management ===

	// Claim HW cursor for a seat. Returns false if already claimed by another.
	bool claimHardwareCursor(Seat seat)
	{
		if (_hwCursorOwner !is null && _hwCursorOwner !is seat)
			return false;
		_hwCursorOwner = seat;
		logDebug("Seat '%s' claimed hardware cursor", seat.name);
		return true;
	}

	// Release HW cursor ownership.
	void releaseHardwareCursor(Seat seat)
	{
		if (_hwCursorOwner is seat)
		{
			_hwCursorOwner = null;
			logDebug("Seat '%s' released hardware cursor", seat.name);
		}
	}

	// Check if seat has HW cursor ownership.
	bool hasHardwareCursor(Seat seat)
	{
		return _hwCursorOwner is seat;
	}

	// Called by Seat when cursor image needs update dispatches either to HW or SW.
	void onCursorImageChanged(Seat seat)
	{
		if (seat is _hwCursorOwner)
			updateHardwareCursorImage(seat);
		else
			updateSoftwareCursorImage(seat);
	}

	// Called by Seat when cursor position changes so we can update either the HW or SW cursor position.
	void onCursorPositionChanged(Seat seat, Vector2 pos)
	{
		if (seat is _hwCursorOwner)
			updateHardwareCursorPosition(pos);
		else
			updateSoftwareCursorPosition(seat, pos);
	}

	private void updateHardwareCursorImage(Seat seat)
	{
		auto outputMgr = SubsystemManager.getByService!OutputManager(Services.OutputManager);
		if (outputMgr is null)
			return;

		const(ubyte)[] pixels;
		Vector2U size;
		Vector2I hotspot;

		if (seat.hasClientRequestedCursor())
		{
			auto state = seat.cursorState;
			if (state.surface !is null && state.surface.currentBuffer !is null)
			{
				auto buffer = state.surface.currentBuffer;
				size = buffer.getImageSize();
				hotspot = state.hotspot;
				pixels = buffer.getPixelData();
			}
			else if (state.shapeKey.length > 0)
			{
				if (auto img = seat.resolveThemeCursor())
				{
					size = img.frameSize;
					hotspot = img.hotspot;
					pixels = img.framePixels(0);
				}
			}
			// else: client explicitly wants no cursor
		}
		else if (auto img = seat.resolveThemeCursor())
		{
			size = img.frameSize;
			hotspot = img.hotspot;
			pixels = img.framePixels(0);
		}

		foreach (ref mo; outputMgr.outputs)
		{
			auto plane = mo.output.cursorPlane();
			if (plane is null)
				continue;

			if (pixels.length > 0)
			{
				if (!plane.setImage(pixels, size, hotspot))
					logWarn("Hardware cursor update failed for output %s", mo.output.name);
			}
			else
			{
				plane.hide();
			}
		}
	}

	private void updateHardwareCursorPosition(Vector2 pos)
	{
		auto outputMgr = SubsystemManager.getByService!OutputManager(Services.OutputManager);
		if (outputMgr is null)
			return;

		auto posI = cast(Vector2I) pos;
		foreach (ref mo; outputMgr.outputs)
		{
			auto plane = mo.output.cursorPlane();
			if (plane !is null)
				plane.setPosition(posI);
		}
	}

	private void updateSoftwareCursorImage(Seat seat)
	{
		if (!(seat in _swCursorStates))
			_swCursorStates[seat] = SoftwareCursorState.init;
		auto state = seat in _swCursorStates;

		auto pos = seat.pointerPosition;
		if (seat.hasClientRequestedCursor())
		{
			auto cs = seat.cursorState;
			if (cs.surface !is null && cs.surface.currentBuffer !is null)
			{
				auto buffer = cs.surface.currentBuffer;
				auto imgSize = buffer.getImageSize();

				if (state.visible) state.addDamage(state.currentRect());
				state.texture  = buffer.getITexture();
				state.srcRect  = [0.0f, 0.0f, 1.0f, 1.0f];
				state.size     = Vector2F(imgSize.x, imgSize.y);
				state.visible  = true;
				state.position = Vector2F(cast(int) pos.x - cs.hotspot.x, cast(int) pos.y - cs.hotspot.y);
				state.addDamage(state.currentRect());
				scheduleSceneRepaint();
				return;
			}
			else if (cs.shapeKey.length > 0)
			{
				if (auto img = seat.resolveThemeCursor())
				{
					if (img.texture !is null)
					{
						if (state.visible) state.addDamage(state.currentRect());
						state.texture  = img.texture;
						state.srcRect  = img.frameUVRect(0);
						state.size     = Vector2F(img.frameSize.x, img.frameSize.y);
						state.visible  = true;
						state.position = Vector2F(cast(int) pos.x - img.hotspot.x, cast(int) pos.y - img.hotspot.y);
						state.addDamage(state.currentRect());
						scheduleSceneRepaint();
						return;
					}
				}
			}
			// else: client explicitly wants no cursor
		}
		else if (auto img = seat.resolveThemeCursor())
		{
			if (img.texture !is null)
			{
				if (state.visible) state.addDamage(state.currentRect());
				state.texture  = img.texture;
				state.srcRect  = img.frameUVRect(0);
				state.size     = Vector2F(img.frameSize.x, img.frameSize.y);
				state.visible  = true;
				state.position = Vector2F(cast(int) pos.x - img.hotspot.x, cast(int) pos.y - img.hotspot.y);
				state.addDamage(state.currentRect());
				scheduleSceneRepaint();
				return;
			}
		}

		if (state.visible)
		{
			state.addDamage(state.currentRect());
			state.visible = false;
			scheduleSceneRepaint();
		}
	}

	private void updateSoftwareCursorPosition(Seat seat, Vector2 pos)
	{
		auto state = seat in _swCursorStates;
		if (state is null || !state.visible)
			return;

		auto hotspot = seat.activeCursorHotspot();
		auto newPos = Vector2F(cast(int) pos.x - hotspot.x, cast(int) pos.y - hotspot.y);

		if (state.position.x != newPos.x || state.position.y != newPos.y)
		{
			state.addDamage(state.currentRect()); // old position
			state.position = newPos;
			state.addDamage(state.currentRect()); // new position
			scheduleSceneRepaint();
		}
	}

	private void scheduleSceneRepaint()
	{
		auto renderSub = SubsystemManager.getByService!RenderSubsystem(Services.RenderSubsystem);
		if (renderSub !is null)
			renderSub.scheduleRepaint();
	}

	// Draw all visible software cursors onto the canvas.
	// Called by the WM at the end of its draw() pass to keep cursors on top.
	void drawSoftwareCursors(ICanvas canvas, OutputManager.ManagedOutput output)
	{
		foreach (ref state; _swCursorStates.byValue())
		{
			if (!state.visible || state.texture is null)
				continue;
			canvas.drawTexture(state.position, state.size, state.texture,
				state.srcRect, BufferTransform.normal, [1.0f, 1.0f, 1.0f, 1.0f], 1.0f);
		}
	}

	// Push accumulated cursor damage to the output manager.
	// Called by the WM at the end of its pushDamage() pass.
	void pushCursorDamage(OutputManager om, OutputManager.ManagedOutput output)
	{
		foreach (ref state; _swCursorStates.byValue())
		{
			foreach (r; state.pendingDamage())
				om.addDamage(r);
			state.clearDamage();
		}
	}

	private bool hasAnyCursorPlane()
	{
		auto outputMgr = SubsystemManager.getByService!OutputManager(Services.OutputManager);
		if (outputMgr is null)
			return false;
		foreach (ref mo; outputMgr.outputs)
			if (mo.output.cursorPlane() !is null)
				return true;
		return false;
	}

	// === Input routing ===

	void connectInputBackend(InputBackend backend)
	{
		backend.setInputHandler(&handleRawInput);
	}

	// Handle raw input from backend.
	// Fires Seat.OnInputEvent, the WM (subscriber) decides whether to dispatch to the client.
	private void handleRawInput(InputEvent event)
	{
		auto seat = findSeatForDevice(event.device);
		if (seat is null)
		{
			if (event.device !is null)
			{
				assignDevice(event.device);
				seat = _defaultSeat;
			}
			else
			{
				return;
			}
		}

		Seat.OnInputEvent.fire(seat, event);
	}

}
