// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.seat;

import trinove.bus;
import trinove.cursor;
import trinove.math;
import trinove.backend.input;
import trinove.seat_manager : SeatManager;
import trinove.relative_pointer : WaiRelativePointer;
import trinove.log;
import trinove.surface.surface : WaiSurface;
import trinove.pointer_constraints.constraint : PointerConstraint, ConstraintType;
import trinove.wm.view : View;
import trinove.surface.subsurface : WaiSubsurface;
import trinove.util;
import wayland.server;
import wayland.server.protocol;
import wayland.native.server : wl_client, wl_resource_get_client;
import wayland.native.util : wl_array, wl_array_init;
import wayland.util : WlFixed;
import core.time : MonoTime;
import std.algorithm.comparison;

// Identifies the specific surface (main or subsurface) currently under the pointer.
struct PointerFocus
{
	View view;
	WaiSubsurface subsurface; // null = pointer is on the main surface

	bool opCast(T : bool)() const
	{
		return view !is null;
	}

	@property WaiSurface surface()
	{
		if (subsurface !is null)
			return subsurface.surface;
		if (view !is null)
			return view.getSurface();
		return null;
	}

	// Absolute compositor-space origin of the focused surface.
	// For subsurfaces, this walks the ancestry chain and adds each offset.
	@property Vector2I surfaceOrigin()
	{
		if (view is null)
			return Vector2I(0, 0);

		auto origin = view.contentOrigin();

		WaiSubsurface[16] chain;
		int depth = 0;
		for (auto s = subsurface; s !is null && depth < chain.length; s = s.parentSubsurface())
			chain[depth++] = s;
		foreach_reverse (i; 0 .. depth)
			origin = origin + chain[i].position;

		return origin;
	}

	Vector2 surfaceLocalPosition(Vector2 cursor)
	{
		auto origin = surfaceOrigin;
		return Vector2(cursor.x - origin.x, cursor.y - origin.y);
	}
}

class Seat : WlSeat
{
	// Fired for input events. The WM (or any subscriber) decides whether to dispatch to the client.
	mixin DefineEvent!("OnInputEvent", Seat, InputEvent);

	// Per-client seat state, shared across all wl_seat bindings for the same client.
	class ClientSeatState
	{
		uint pointerEnterSerial;
		uint keyboardEnterSerial;
		uint[uint] buttonSerials; // button code -> serial
		uint[uint] keySerials; // keycode -> serial
		// TODO: touchSerials when touch is implemented

		// Resources owned by this client (aggregated across all seat bindings)
		WaiClientSeat[] seatResources;
		WaiPointer[] pointers;
		WaiKeyboard[] keyboards;
		WaiRelativePointer[] relativePointers;

		int bindingCount; // number of active WaiClientSeat resources
	}

	class WaiClientSeat : WlSeat.Resource
	{
		Seat seat;
		ClientSeatState state;

		this(Seat seat, ClientSeatState state, WlClient client, uint ver, uint id)
		{
			this.seat = seat;
			this.state = state;
			state.bindingCount++;
			super(client, ver, id);

			addDestroyListener((WlResource) { onDestroy(); });
		}

		private void onDestroy()
		{
			seat.removeClientSeatBinding(this);
		}
	}

	// Client-set cursor state
	struct CursorState
	{
		WaiSurface surface; // Client's cursor surface (null = hidden or not set)
		string shapeKey;
		Vector2I hotspot;
		bool dirty;
		// True when the client explicitly sets the cursor, either with surface or shape.
		bool requested;
	}

	// Which View currently has keyboard focus on this seat (null if none)
	View keyboardFocusView;

	// Pointer focus state: which view/subsurface is under the cursor
	PointerFocus pointerFocus;

	private
	{
		WlDisplay _display;
		SeatManager _seatManager;
		MonoTime _startTime;
		string _name;
		InputDevice[] _devices;
		Capability _capabilities;

		// Pointer state
		Vector2 _pointerPosition;
		WaiSurface _pointerFocusSurface;

		// Pointer constraint state
		PointerConstraint[WaiSurface] _registeredConstraints;
		PointerConstraint _activeConstraint;

		// Keyboard state
		WaiSurface _keyboardFocusSurface;
		bool[256] _pressedKeys; // Index by evdev keycode

		CursorState _cursorState;
		CursorTheme _cursorTheme;

		ClientSeatState[wl_client* ] _clientStates;
	}

	this(WlDisplay display, SeatManager seatManager, string name)
	{
		super(display, WlSeat.ver);
		_display = display;
		_seatManager = seatManager;
		_name = name;
		_startTime = MonoTime.currTime;
	}

	private uint currentTimeMs()
	{
		return cast(uint)(MonoTime.currTime - _startTime).total!"msecs";
	}

	@property string name()
	{
		return _name;
	}

	// === Device management ===

	void addDevice(InputDevice device)
	{
		_devices ~= device;
		updateCapabilities();
	}

	void removeDevice(InputDevice device)
	{
		import std.algorithm : remove;

		_devices = _devices.remove!(d => d is device);
		updateCapabilities();
	}

	@property InputDevice[] devices()
	{
		return _devices;
	}

	bool ownsDevice(InputDevice device)
	{
		import std.algorithm.searching : canFind;

		if (_devices.canFind(device))
			return true;
		return false;
	}

	private void updateCapabilities()
	{
		Capability caps;
		foreach (device; _devices)
		{
			final switch (device.type)
			{
			case InputDeviceType.keyboard:
				caps |= Capability.keyboard;
				break;
			case InputDeviceType.pointer:
				caps |= Capability.pointer;
				break;
			case InputDeviceType.touch:
				caps |= Capability.touch;
				break;
			}
		}

		if (caps != _capabilities)
		{
			_capabilities = caps;
			foreach (state; _clientStates.byValue)
				foreach (res; state.seatResources)
					res.sendCapabilities(_capabilities);
		}
	}

	// === Pointer state ===

	@property Vector2 pointerPosition()
	{
		return _pointerPosition;
	}

	@property void pointerPosition(Vector2 pos)
	{
		_pointerPosition = pos;
		if (_seatManager !is null)
			_seatManager.onCursorPositionChanged(this, pos);
	}

	// Calculate surface-local position from global pointer position using current pointer focus.
	Vector2 surfaceLocalPosition(Vector2 pointerPos)
	{
		return pointerFocus.surfaceLocalPosition(pointerPos);
	}

	@property WaiSurface pointerFocusSurface()
	{
		return _pointerFocusSurface;
	}

	// The constraint currently being enforced by this seat's pointer (null if none).
	@property PointerConstraint pointerConstraint()
	{
		return _activeConstraint;
	}

	// Returns the registered constraint for (this seat, surface), or null.
	PointerConstraint constraintFor(WaiSurface surface)
	{
		auto cp = surface in _registeredConstraints;
		return cp ? *cp : null;
	}

	// Register a constraint for this seat on the given surface.
	// Called by protocol objects (WaiLockedPointer / WaiConfinedPointer) on construction.
	void attachConstraint(WaiSurface surface, PointerConstraint c)
	{
		_registeredConstraints[surface] = c;

		// Activate immediately if this seat's pointer is already on the surface.
		if (_pointerFocusSurface is surface && _activeConstraint is null)
		{
			auto localPos = pointerFocus.surfaceLocalPosition(_pointerPosition);
			if (c.pointInRegion(cast(int) localPos.x, cast(int) localPos.y))
				c.activate();
			_activeConstraint = c;
		}
	}

	// Unregister the constraint for this seat on the given surface.
	// Called by protocol objects on destroy. Does NOT warp the cursor.
	void detachConstraint(WaiSurface surface)
	{
		auto cp = surface in _registeredConstraints;
		if (cp is null)
			return;

		auto c = *cp;
		if (c is _activeConstraint)
		{
			c.reset();
			_activeConstraint = null;
		}
		else
		{
			c.reset();
		}
		_registeredConstraints.remove(surface);
	}

	// Activate/deactivate constraints when pointer focus changes.
	// Called by WindowConductor.setPointerFocus after resolving the new focused surface.
	void updateConstraintForFocus(WaiSurface newSurface, Vector2 localPos)
	{
		// Deactivate current constraint, warping cursor to hint if this was a lock.
		if (_activeConstraint !is null)
		{
			if (_activeConstraint.type == ConstraintType.lock && _activeConstraint.hasCursorHint)
			{
				auto origin = pointerFocus.surfaceOrigin;
				auto hint = origin + Vector2I(cast(int) _activeConstraint.cursorHintX, cast(int) _activeConstraint
						.cursorHintY);
				_pointerPosition = Vector2(hint.x, hint.y);
				if (_seatManager !is null)
					_seatManager.onCursorPositionChanged(this, _pointerPosition);
			}
			_activeConstraint.deactivate();
			_activeConstraint = null;
		}

		if (newSurface is null)
			return;

		auto cp = newSurface in _registeredConstraints;
		if (cp is null || (*cp).type == ConstraintType.none)
			return;

		auto c = *cp;
		_activeConstraint = c;
		if (!c.active && c.pointInRegion(cast(int) localPos.x, cast(int) localPos.y))
			c.activate();
	}

	// Set pointer focus to a surface with enter event at given surface-local position.
	void setPointerFocusSurface(WaiSurface surface, int surfaceLocalX, int surfaceLocalY)
	{
		if (_pointerFocusSurface is surface)
			return;

		auto serial = _display.nextSerial();
		auto oldSurface = _pointerFocusSurface;
		_pointerFocusSurface = surface;

		clearClientCursor();

		if (oldSurface !is null && isClientValid(oldSurface))
		{
			if (auto state = oldSurface.client.native in _clientStates)
			{
				state.pointerEnterSerial = 0;
				foreach (p; state.pointers)
				{
					p.sendLeave(serial, oldSurface);
					if (getResVersion(p) >= WlPointer.frameSinceVersion)
						p.sendFrame();
				}
			}
		}

		if (surface !is null && isClientValid(surface))
		{
			if (auto state = surface.client.native in _clientStates)
			{
				state.pointerEnterSerial = serial;
				foreach (p; state.pointers)
				{
					p.sendEnter(serial, surface, WlFixed.create(surfaceLocalX), WlFixed.create(surfaceLocalY));
					if (getResVersion(p) >= WlPointer.frameSinceVersion)
						p.sendFrame();
				}
			}
		}
	}

	void clearFocusForSurface(WaiSurface surface)
	{
		if (_pointerFocusSurface is surface)
		{
			_pointerFocusSurface = null;
			clearClientCursor();
		}
		if (_keyboardFocusSurface is surface)
			_keyboardFocusSurface = null;
	}

	// === Keyboard state ===

	@property WaiSurface keyboardFocusSurface()
	{
		return _keyboardFocusSurface;
	}

	// Set keyboard focus to a surface with enter/leave events.
	void setKeyboardFocusSurface(WaiSurface surface)
	{
		if (_keyboardFocusSurface is surface)
			return;

		auto serial = _display.nextSerial();
		auto oldSurface = _keyboardFocusSurface;
		_keyboardFocusSurface = surface;

		if (oldSurface !is null && isClientValid(oldSurface))
		{
			if (auto state = oldSurface.client.native in _clientStates)
			{
				state.keyboardEnterSerial = 0;
				foreach (kb; state.keyboards)
					kb.sendLeave(serial, oldSurface);
			}
		}

		if (surface !is null && isClientValid(surface))
		{
			if (auto state = surface.client.native in _clientStates)
			{
				state.keyboardEnterSerial = serial;
				uint[256] keybuf = void;
				wl_array keys;
				wl_array_init(&keys);
				fillPressedKeysArray(keys, keybuf[]);
				foreach (kb; state.keyboards)
					kb.sendEnter(serial, surface, &keys);
			}
		}
	}

	// === Cursor state ===

	@property ref CursorState cursorState()
	{
		return _cursorState;
	}

	// Set client cursor surface and hotspot.
	// Called from WaiPointer.setCursor after serial validation.
	void setClientCursor(WaiSurface surface, Vector2I hotspot)
	{
		import trinove.surface.cursor_role : CursorRole;

		if (_cursorState.surface is surface && _cursorState.hotspot == hotspot)
			return;

		if (_cursorState.surface !is null)
		{
			if (auto oldRole = cast(CursorRole) _cursorState.surface.role)
				oldRole.seat = null;
		}

		if (surface !is null)
		{
			if (auto existingRole = cast(CursorRole) surface.role)
			{
				// Surface already has cursor role, just update seat
				existingRole.seat = this;
			}
			else
			{
				// Assign new cursor role
				surface.role = new CursorRole(this, surface);
			}
		}

		_cursorState.surface = surface;
		_cursorState.hotspot = hotspot;
		_cursorState.shapeKey = null;
		_cursorState.dirty = true;
		_cursorState.requested = true;

		if (_seatManager !is null)
			_seatManager.onCursorImageChanged(this);
	}

	// Clear client cursor (called on focus change).
	void clearClientCursor()
	{
		import trinove.surface.cursor_role : CursorRole;

		if (_cursorState.surface !is null)
		{
			if (auto cursorRole = cast(CursorRole) _cursorState.surface.role)
				cursorRole.seat = null;
		}

		_cursorState.surface = null;
		_cursorState.hotspot = Vector2I(0, 0);
		_cursorState.shapeKey = null;
		_cursorState.dirty = true;
		_cursorState.requested = false;

		if (_seatManager !is null)
			_seatManager.onCursorImageChanged(this);
	}

	// Set cursor using a string, clears any client surface cursor.
	void setClientCursorShape(string themeKey)
	{
		import trinove.surface.cursor_role : CursorRole;

		if (_cursorState.surface is null && _cursorState.shapeKey == themeKey)
			return;

		if (_cursorState.surface !is null)
		{
			if (auto cursorRole = cast(CursorRole) _cursorState.surface.role)
				cursorRole.seat = null;
			_cursorState.surface = null;
			_cursorState.hotspot = Vector2I(0, 0);
		}

		_cursorState.shapeKey = themeKey;
		_cursorState.dirty = true;
		_cursorState.requested = true;

		if (_seatManager !is null)
			_seatManager.onCursorImageChanged(this);
	}

	// True if the client explicitly set a cursor (surface, shape, or hidden).
	// False means the client hasn't responded to enter yet.
	bool hasClientRequestedCursor()
	{
		return _cursorState.requested;
	}

	// Called when cursor surface commits.
	void markCursorDirty()
	{
		_cursorState.dirty = true;
		if (_seatManager !is null)
			_seatManager.onCursorImageChanged(this);
	}

	// Clear cursor surface if it matches (called when surface is destroyed).
	void clearCursorSurface(WaiSurface surface)
	{
		if (_cursorState.surface is surface)
		{
			_cursorState.surface = null;
			_cursorState.shapeKey = null;
			_cursorState.dirty = true;
			_cursorState.requested = false;
			if (_seatManager !is null)
				_seatManager.onCursorImageChanged(this);
		}
	}

	@property CursorTheme cursorTheme()
	{
		return _cursorTheme;
	}

	// Set the cursor theme for this seat.
	// Triggers a cursor image update.
	void setCursorTheme(CursorTheme theme)
	{
		_cursorTheme = theme;
		if (_seatManager !is null)
			_seatManager.onCursorImageChanged(this);
	}

	// Resolve the active cursor image from the theme for the current cursor state.
	// Returns the shape image if set, the "default" image otherwise, or null if unavailable.
	CursorImage resolveThemeCursor()
	{
		if (_cursorTheme is null)
			return null;
		if (_cursorState.shapeKey.length > 0)
			return _cursorTheme.get(_cursorState.shapeKey);
		return _cursorTheme.get("default");
	}

	// Effective hotspot for the currently active cursor layer.
	Vector2I activeCursorHotspot()
	{
		if (_cursorState.requested)
		{
			if (_cursorState.surface !is null)
				return _cursorState.hotspot;
			if (_cursorState.shapeKey.length > 0)
			{
				auto img = resolveThemeCursor();
				if (img !is null)
					return img.hotspot;
			}
			return Vector2I(0, 0);
		}
		auto img = resolveThemeCursor();
		return img !is null ? img.hotspot : Vector2I(0, 0);
	}

	// === Keyboard event forwarding ===

	private void fillPressedKeysArray(ref wl_array arr, uint[] buf)
	{
		uint count = 0;
		foreach (uint i, bool p; _pressedKeys)
			if (p && count < buf.length)
				buf[count++] = i;
		arr.data = buf.ptr;
		arr.size = count * uint.sizeof;
		arr.alloc = 0;
	}

	void notifyKey(uint keycode, bool pressed)
	{
		if (keycode < _pressedKeys.length)
			_pressedKeys[keycode] = pressed;

		if (_keyboardFocusSurface is null)
			return;

		if (auto state = _keyboardFocusSurface.client.native in _clientStates)
		{
			auto serial = _display.nextSerial();
			auto time = currentTimeMs();
			auto keyState = pressed ? WlKeyboard.KeyState.pressed : WlKeyboard.KeyState.released;

			if (pressed)
				state.keySerials[keycode] = serial;

			foreach (kb; state.keyboards)
				kb.sendKey(serial, time, keycode, keyState);
		}
	}

	void notifyModifiers(uint depressed, uint latched, uint locked, uint group)
	{
		if (_keyboardFocusSurface is null)
			return;

		if (auto state = _keyboardFocusSurface.client.native in _clientStates)
		{
			auto serial = _display.nextSerial();
			foreach (kb; state.keyboards)
				kb.sendModifiers(serial, depressed, latched, locked, group);
		}
	}

	// === Pointer event forwarding ===

	// Send pointer motion to focused client (surface-local coordinates)
	// Caller must send sendPointerFrame() after all pointer events in the group.
	void notifyPointerMotion(Vector2 surfaceLocal)
	{
		if (_pointerFocusSurface is null)
			return;

		if (auto state = _pointerFocusSurface.client.native in _clientStates)
		{
			auto time = currentTimeMs();
			foreach (p; state.pointers)
				p.sendMotion(time, WlFixed.create(surfaceLocal.x), WlFixed.create(surfaceLocal.y));
		}
	}

	// Send relative pointer motion to focused client (unclipped delta)
	// Caller must send sendPointerFrame() after all pointer events in the group.
	void notifyRelativeMotion(uint timestampMs, Vector2 delta, Vector2 deltaUnaccel)
	{
		if (_pointerFocusSurface is null)
			return;

		if (auto state = _pointerFocusSurface.client.native in _clientStates)
		{
			if (state.relativePointers.length == 0)
				return;

			ulong utimeUsec = cast(ulong) timestampMs * 1000;
			uint utimeHi = cast(uint)(utimeUsec >> 32);
			uint utimeLo = cast(uint)(utimeUsec & 0xFFFFFFFF);

			foreach (rp; state.relativePointers)
			{
				rp.sendRelativeMotion(utimeHi, utimeLo,
						WlFixed.create(delta.x), WlFixed.create(delta.y),
						WlFixed.create(deltaUnaccel.x), WlFixed.create(deltaUnaccel.y));
			}
		}
	}

	// Send wl_pointer.frame to mark the end of a pointer event group.
	// Must be called after batching motion + relative_motion (or button, axis, etc.)
	void sendPointerFrame()
	{
		if (_pointerFocusSurface is null)
			return;

		if (auto state = _pointerFocusSurface.client.native in _clientStates)
		{
			foreach (p; state.pointers)
				if (getResVersion(p) >= WlPointer.frameSinceVersion)
					p.sendFrame();
		}
	}

	void notifyPointerButton(uint button, bool pressed)
	{
		if (_pointerFocusSurface is null)
			return;

		if (auto state = _pointerFocusSurface.client.native in _clientStates)
		{
			auto serial = _display.nextSerial();
			auto time = currentTimeMs();
			auto btnState = pressed ? WlPointer.ButtonState.pressed : WlPointer.ButtonState.released;

			if (pressed)
				state.buttonSerials[button] = serial;

			foreach (p; state.pointers)
			{
				p.sendButton(serial, time, button, btnState);
				if (getResVersion(p) >= WlPointer.frameSinceVersion)
					p.sendFrame();
			}
		}
	}

	void notifyPointerAxis(WlPointer.Axis axis, int value)
	{
		if (_pointerFocusSurface is null)
			return;

		if (auto state = _pointerFocusSurface.client.native in _clientStates)
		{
			auto time = currentTimeMs();
			foreach (p; state.pointers)
			{
				p.sendAxis(time, axis, WlFixed.create(value));
				if (getResVersion(p) >= WlPointer.frameSinceVersion)
					p.sendFrame();
			}
		}
	}

	void notifyFocusedClient(InputEvent event, Vector2 surfaceLocal)
	{
		final switch (event.type)
		{
		case InputEventType.pointerMotion:
			if (pointerFocusSurface !is null)
			{
				notifyPointerMotion(surfaceLocal);
				notifyRelativeMotion(event.timestampMs, event.pointerMotion.delta, event.pointerMotion.deltaUnaccel);
				sendPointerFrame();
			}
			break;

		case InputEventType.pointerMotionAbsolute:
			if (pointerFocusSurface !is null)
			{
				notifyPointerMotion(surfaceLocal);
				sendPointerFrame();
			}
			break;

		case InputEventType.pointerButton:
			notifyPointerButton(event.pointerButton.button, event.pointerButton.pressed);
			break;

		case InputEventType.pointerAxis:
			auto axis = event.pointerAxis.axis == 0 ? WlPointer.Axis.verticalScroll
				: WlPointer.Axis.horizontalScroll;
			notifyPointerAxis(axis, cast(int) event.pointerAxis.value);
			break;

		case InputEventType.keyPress:
			notifyKey(event.key.keycode, true);
			if (event.device !is null)
			{
				uint depressed, latched, locked, group;
				event.device.getModifiers(depressed, latched, locked, group);
				notifyModifiers(depressed, latched, locked, group);
			}
			break;

		case InputEventType.keyRelease:
			notifyKey(event.key.keycode, false);
			if (event.device !is null)
			{
				uint depressed, latched, locked, group;
				event.device.getModifiers(depressed, latched, locked, group);
				notifyModifiers(depressed, latched, locked, group);
			}
			break;
		}
	}

	// === WlSeat protocol implementation ===

	override Resource bind(WlClient cl, uint ver, uint id)
	{
		// Reuse existing client state or create new one (a client may bind wl_seat multiple times)
		if (cl.native !in _clientStates)
			_clientStates[cl.native] = new ClientSeatState();

		auto clientSeat = new WaiClientSeat(this, _clientStates[cl.native], cl, ver, id);
		_clientStates[cl.native].seatResources ~= clientSeat;

		// Send capabilities and name
		clientSeat.sendCapabilities(_capabilities);
		if (ver >= WlSeat.nameSinceVersion)
			clientSeat.sendName(_name);

		return clientSeat;
	}

	package void removeClientSeatBinding(WaiClientSeat clientSeat)
	{
		if (clientSeat.state is null)
			return;

		import std.algorithm : remove;

		clientSeat.state.seatResources = clientSeat.state.seatResources.remove!(r => r is clientSeat);
		clientSeat.state.bindingCount--;
		if (clientSeat.state.bindingCount <= 0)
		{
			auto nativeClient = wl_resource_get_client(clientSeat.native);
			_clientStates.remove(nativeClient);
		}
		clientSeat.state = null;
	}

	bool ownsResource(WlResource seatRes)
	{
		auto cs = cast(WaiClientSeat) seatRes;
		return cs !is null && cs.seat is this;
	}

	override protected WlPointer getPointer(WlClient cl, Resource res, uint id)
	{
		if ((_capabilities & Capability.pointer) == 0)
		{
			res.postError(0, "Seat has no pointer capability");
			return null;
		}

		auto clientSeat = cast(WaiClientSeat) res;
		if (clientSeat is null || clientSeat.state is null)
			return null;

		auto ptr = new WaiPointer(clientSeat, cl, id);
		clientSeat.state.pointers ~= ptr;

		// If this client's surface already has pointer focus, send enter to the new resource
		if (_pointerFocusSurface !is null && isClientValid(_pointerFocusSurface)
				&& wl_resource_get_client(_pointerFocusSurface.native) == cl.native)
		{
			auto state = clientSeat.state;
			auto localPos = surfaceLocalPosition(_pointerPosition);
			auto serial = state.pointerEnterSerial;
			if (serial == 0)
			{
				serial = _display.nextSerial();
				state.pointerEnterSerial = serial;
			}
			ptr.sendEnter(serial, _pointerFocusSurface, WlFixed.create(localPos.x), WlFixed.create(localPos.y));
			if (getResVersion(ptr) >= WlPointer.frameSinceVersion)
				ptr.sendFrame();
		}

		return ptr;
	}

	package void removePointer(WaiPointer ptr)
	{
		import std.algorithm : remove;

		if (ptr.clientSeat !is null && ptr.clientSeat.state !is null)
			ptr.clientSeat.state.pointers = ptr.clientSeat.state.pointers.remove!(p => p is ptr);
	}

	package void removeRelativePointer(WaiRelativePointer rp)
	{
		import std.algorithm : remove;

		if (rp.clientSeat !is null && rp.clientSeat.state !is null)
			rp.clientSeat.state.relativePointers = rp.clientSeat.state.relativePointers.remove!(p => p is rp);
	}

	override protected WlKeyboard getKeyboard(WlClient cl, Resource res, uint id)
	{
		if ((_capabilities & Capability.keyboard) == 0)
		{
			res.postError(0, "Seat has no keyboard capability");
			return null;
		}

		auto clientSeat = cast(WaiClientSeat) res;
		if (clientSeat is null || clientSeat.state is null)
			return null;

		auto kb = new WaiKeyboard(clientSeat, cl, id);
		clientSeat.state.keyboards ~= kb;

		// Find a keyboard device and send keymap
		foreach (device; _devices)
		{
			if (device.type == InputDeviceType.keyboard)
			{
				int fd;
				uint size;
				if (device.getKeymap(fd, size))
					kb.sendKeymap(WlKeyboard.KeymapFormat.xkbV1, fd, size);
				break;
			}
		}

		// Send repeat info (25 keys/sec, 600ms delay) version 4+
		if (getResVersion(kb) >= WlKeyboard.repeatInfoSinceVersion)
			kb.sendRepeatInfo(25, 600);

		// If this client's surface already has keyboard focus, send enter to the new resource
		if (_keyboardFocusSurface !is null && isClientValid(_keyboardFocusSurface)
				&& wl_resource_get_client(_keyboardFocusSurface.native) == cl.native)
		{
			auto state = clientSeat.state;
			auto serial = state.keyboardEnterSerial;
			if (serial == 0)
			{
				serial = _display.nextSerial();
				state.keyboardEnterSerial = serial;
			}
			uint[256] keybuf = void;
			wl_array keys;
			wl_array_init(&keys);
			fillPressedKeysArray(keys, keybuf[]);
			kb.sendEnter(serial, _keyboardFocusSurface, &keys);
		}

		return kb;
	}

	package void removeKeyboard(WaiKeyboard kb)
	{
		import std.algorithm : remove;

		if (kb.clientSeat !is null && kb.clientSeat.state !is null)
			kb.clientSeat.state.keyboards = kb.clientSeat.state.keyboards.remove!(k => k is kb);
	}

	override protected WlTouch getTouch(WlClient cl, Resource res, uint id)
	{
		if ((_capabilities & Capability.touch) == 0)
		{
			res.postError(0, "Seat has no touch capability");
			return null;
		}

		// TODO: implement WaiTouch
		return null;
	}

	override protected void release(WlClient cl, Resource res)
	{
		auto clientSeat = cast(WaiClientSeat) res;
		if (clientSeat is null)
			return;

		if (clientSeat.state !is null)
		{
			if (clientSeat.state.pointers.length > 0)
				logWarn("Client releasing wl_seat while still holding %d wl_pointer resource(s)", clientSeat.state
						.pointers.length);
			if (clientSeat.state.keyboards.length > 0)
				logWarn("Client releasing wl_seat while still holding %d wl_keyboard resource(s)", clientSeat.state
						.keyboards.length);
		}
	}

	// === Input serial validation ===

	ClientSeatState getClientState(WlClient client)
	{
		if (auto state = client.native in _clientStates)
			return *state;
		return null;
	}

	bool isValidMoveResizeSerial(WlClient client, uint serial)
	{
		auto state = getClientState(client);
		if (state is null)
			return false;

		foreach (s; state.buttonSerials.byValue())
			if (s == serial)
				return true;
		// TODO: check touch serials when implemented
		return false;
	}

	bool isValidGrabSerial(WlClient client, uint serial)
	{
		auto state = getClientState(client);
		if (state is null)
		{
			logDebug("isValidGrabSerial: no client state for client");
			return false;
		}

		foreach (s; state.buttonSerials.byValue())
			if (s == serial)
				return true;
		foreach (s; state.keySerials.byValue())
			if (s == serial)
				return true;

		import std.conv : to;

		string buttons = state.buttonSerials.byValue().to!string;
		string keys = state.keySerials.byValue().to!string;
		logDebug("isValidGrabSerial: serial %d not found. buttons=%s keys=%s pointerEnter=%d", serial, buttons, keys,
				state.pointerEnterSerial);

		// TODO: check touch serials when implemented
		return false;
	}

	bool isValidCursorSerial(WlClient client, uint serial)
	{
		auto state = getClientState(client);
		if (state is null)
			return false;
		return state.pointerEnterSerial == serial;
	}
}

// Per-client wl_keyboard resource
class WaiKeyboard : WlKeyboard
{
	Seat.WaiClientSeat clientSeat;

	this(Seat.WaiClientSeat clientSeat, WlClient cl, uint id)
	{
		this.clientSeat = clientSeat;
		auto v = clamp(getResVersion(clientSeat), 1, WlKeyboard.ver);
		super(cl, v, id);

		mixin(onDestroyCallRelease);
	}

	@property Seat seat()
	{
		return clientSeat ? clientSeat.seat : null;
	}

	override void release(WlClient cl)
	{
		if (clientSeat && clientSeat.seat)
			clientSeat.seat.removeKeyboard(this);
		clientSeat = null;
	}
}

// Per-client wl_pointer resource
class WaiPointer : WlPointer
{
	Seat.WaiClientSeat clientSeat;

	this(Seat.WaiClientSeat clientSeat, WlClient cl, uint id)
	{
		this.clientSeat = clientSeat;
		auto v = clamp(getResVersion(clientSeat), 1, WlPointer.ver);
		super(cl, v, id);

		mixin(onDestroyCallRelease);
	}

	@property Seat seat()
	{
		return clientSeat ? clientSeat.seat : null;
	}

	override void setCursor(WlClient cl, uint serial, WlSurface surface, int hotspotX, int hotspotY)
	{
		import trinove.surface.cursor_role : CursorRole;

		if (seat is null)
			return;

		if (!seat.isValidCursorSerial(cl, serial))
			return;

		auto waiSurface = cast(WaiSurface) surface;

		if (waiSurface !is null && waiSurface.role !is null)
		{
			if (cast(CursorRole) waiSurface.role is null)
			{
				import wayland.server.protocol : WlPointer;

				postError(WlPointer.Error.role, "Surface already has another role");
				return;
			}
		}

		seat.setClientCursor(waiSurface, Vector2I(hotspotX, hotspotY));
	}

	override void release(WlClient cl)
	{
		if (clientSeat && clientSeat.seat)
			clientSeat.seat.removePointer(this);
		clientSeat = null;
	}
}
