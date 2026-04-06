// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.backend.input;

import trinove.subsystem;
import trinove.math : Vector2;
import wayland.server;

enum InputDeviceType
{
	keyboard,
	pointer,
	touch,
}

enum InputEventType
{
	keyPress,
	keyRelease,
	pointerMotion,
	pointerMotionAbsolute,
	pointerButton,
	pointerAxis, // Future: touch events
}

struct InputEvent
{
	InputDevice device;
	InputEventType type;
	uint timestampMs; // milliseconds

	union
	{
		KeyEvent key;
		PointerMotionEvent pointerMotion;
		PointerAbsoluteEvent pointerAbsolute;
		PointerButtonEvent pointerButton;
		PointerAxisEvent pointerAxis;
	}
}

struct KeyEvent
{
	uint keycode; // evdev keycode
}

struct PointerMotionEvent
{
	Vector2 delta; // relative motion (accelerated)
	Vector2 deltaUnaccel; // raw unaccelerated motion
}

struct PointerAbsoluteEvent
{
	Vector2 pos; // absolute position (0.0-1.0 normalized)
}

struct PointerButtonEvent
{
	uint button; // evdev button code (BTN_LEFT, etc.)
	bool pressed;
}

struct PointerAxisEvent
{
	uint axis; // 0 = vertical, 1 = horizontal
	double value; // scroll amount
}

// Represents a physical input device.
//
// Each device has a type (keyboard, pointer, or touch) and identity.
abstract class InputDevice
{
	abstract InputDeviceType type();

	// Human readable device name ("Logitech USB Mouse")
	abstract string name();

	// System name ("event5", "js0", etc.)
	abstract string sysname();

	// For keyboards: get XKB keymap fd and size.
	// Returns false if not a keyboard or no keymap.
	bool getKeymap(out int fd, out uint size)
	{
		fd = -1;
		size = 0;
		return false;
	}

	// For keyboards: get current modifier state.
	void getModifiers(out uint depressed, out uint latched, out uint locked, out uint group)
	{
		depressed = latched = locked = group = 0;
	}
}

// Input backend interface.
//
// Detects input devices, provides InputDevice objects, and collects input events.
interface InputBackend
{
	InputDevice[] devices();

	//Register your event loop either fd based or timer based in your subsystem initialize.

	// Compositor uses to receive input events from you.
	void setInputHandler(void delegate(InputEvent) handler);
}

abstract class InputBackendSubsystem : ISubsystem, InputBackend
{
	private void delegate(InputEvent) _inputHandler;

	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.InputBackend;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	void setInputHandler(void delegate(InputEvent) handler)
	{
		_inputHandler = handler;
	}

	void emitEvent(InputEvent event)
	{
		if (_inputHandler !is null)
		{
			_inputHandler(event);
		}
	}
}
