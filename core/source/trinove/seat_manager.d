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
import trinove.renderer.scene : SceneGraph, RectNode;
import trinove.renderer.subsystem : RenderSubsystem;
import trinove.output : CursorPlane;
import trinove.output_manager : OutputManager;
import trinove.surface.buffer : IWaylandBuffer;
import wayland.server;
import std.algorithm : remove;

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
		RectNode[Seat] _cursorNodes; // Per-seat software cursor scene nodes
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

		_seats = _seats.remove!(s => s is seat);
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

		auto posI = Vector2I(cast(int) pos.x, cast(int) pos.y);
		foreach (ref mo; outputMgr.outputs)
		{
			auto plane = mo.output.cursorPlane();
			if (plane !is null)
				plane.setPosition(posI);
		}
	}

	private void updateSoftwareCursorImage(Seat seat)
	{
		auto cursorNode = getOrCreateCursorNode(seat);
		if (cursorNode is null)
			return;

		auto pos = seat.pointerPosition;
		if (seat.hasClientRequestedCursor())
		{
			auto state = seat.cursorState;
			if (state.surface !is null && state.surface.currentBuffer !is null)
			{
				auto buffer = state.surface.currentBuffer;
				auto imgSize = buffer.getImageSize();

				cursorNode.texture = buffer.getITexture();
				cursorNode.size = Vector2F(imgSize.x, imgSize.y);
				cursorNode.visible = true;
				cursorNode.position = Vector2F(cast(int) pos.x - state.hotspot.x, cast(int) pos.y - state.hotspot.y);
				cursorNode.addFullDamage();
				scheduleSceneRepaint();
				return;
			}
			else if (state.shapeKey.length > 0)
			{
				if (auto img = seat.resolveThemeCursor())
				{
					if (img.texture !is null)
					{
						cursorNode.texture = img.texture;
						cursorNode.srcRect = img.frameUVRect(0);
						cursorNode.size = Vector2F(img.frameSize.x, img.frameSize.y);
						cursorNode.visible = true;
						cursorNode.position = Vector2F(cast(int) pos.x - img.hotspot.x, cast(int) pos.y - img.hotspot.y);
						cursorNode.addFullDamage();
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
				cursorNode.texture = img.texture;
				cursorNode.srcRect = img.frameUVRect(0);
				cursorNode.size = Vector2F(img.frameSize.x, img.frameSize.y);
				cursorNode.visible = true;
				cursorNode.position = Vector2F(cast(int) pos.x - img.hotspot.x, cast(int) pos.y - img.hotspot.y);
				cursorNode.addFullDamage();
				scheduleSceneRepaint();
				return;
			}
		}

		if (cursorNode.visible)
		{
			damageCursorOldPosition(cursorNode);
			cursorNode.visible = false;
			scheduleSceneRepaint();
		}
	}

	private void updateSoftwareCursorPosition(Seat seat, Vector2 pos)
	{
		auto cursorNode = getOrCreateCursorNode(seat);
		if (cursorNode is null || !cursorNode.visible)
			return;

		auto hotspot = seat.activeCursorHotspot();
		auto newPos = Vector2F(cast(int) pos.x - hotspot.x, cast(int) pos.y - hotspot.y);

		if (cursorNode.position.x != newPos.x || cursorNode.position.y != newPos.y)
		{
			damageCursorOldPosition(cursorNode);
			cursorNode.position = newPos;
			cursorNode.addFullDamage();
			scheduleSceneRepaint();
		}
	}

	private RectNode getOrCreateCursorNode(Seat seat)
	{
		if (auto p = seat in _cursorNodes)
			return *p;

		auto renderSub = SubsystemManager.getByService!RenderSubsystem(Services.RenderSubsystem);
		if (renderSub is null)
			return null;

		auto cursorNode = new RectNode();
		cursorNode.visible = false;
		renderSub.scene.layerRoots[Layer.Cursor].addChild(cursorNode);
		_cursorNodes[seat] = cursorNode;
		return cursorNode;
	}

	// Damage the area where the cursor currently sits (before moving/hiding it).
	private void damageCursorOldPosition(RectNode cursorNode)
	{
		if (cursorNode.parent !is null)
		{
			cursorNode.parent.addDamage(Rect(cast(int) cursorNode.position.x, cast(int) cursorNode.position.y,
					cast(uint) cursorNode.size.x, cast(uint) cursorNode.size.y));
		}
	}

	private void scheduleSceneRepaint()
	{
		auto renderSub = SubsystemManager.getByService!RenderSubsystem(Services.RenderSubsystem);
		if (renderSub !is null)
			renderSub.scene.scheduleRepaint();
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
