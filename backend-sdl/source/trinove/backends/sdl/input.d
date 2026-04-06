// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.backends.sdl.input;

import trinove.subsystem;
import trinove.backend.input;
import trinove.log;
import trinove.display_manager;
import wayland.server;
import bindbc.sdl;
import xkbcommon.xkbcommon;
import core.sys.posix.sys.mman;
import core.sys.posix.unistd : close;
import core.stdc.string : memcpy, strlen;

class SdlInputBackend : InputBackendSubsystem
{
	private SdlKeyboardDevice _keyboard;
	private SdlPointerDevice _pointer;
	private InputDevice[] _devices;
	private bool _devicesChanged;
	private WlTimerEventSource _loop;

	override string name()
	{
		return "SdlInputBackend";
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		required ~= Services.SDL;
	}

	override void initialize()
	{
		_keyboard = new SdlKeyboardDevice();
		_pointer = new SdlPointerDevice();

		_devices ~= _keyboard;
		_devices ~= _pointer;
		_devicesChanged = true;

		_loop = getDisplay().eventLoop.addTimer(&poll);
		_loop.update(1);

		debug logDebug("SDL input backend initialized");
	}

	override void shutdown()
	{
		if (_keyboard)
		{
			_keyboard.cleanup();
			_keyboard = null;
		}
		_pointer = null;
		_devices.length = 0;

		debug logDebug("SDL input backend shutdown");
	}

	// InputBackend interface
	override InputDevice[] devices()
	{
		return _devices;
	}

	int poll()
	{
		SDL_Event event;
		while (SDL_PollEvent(&event))
		{
			processEvent(event);
		}
		//checks every 1ms, not sure if this is great for responsiveness but for libinput we'd
		//be reacting to the fd and sdl is just for development / debugging so should be fine.
		_loop.update(1);
		return 0;
	}

	private void processEvent(ref SDL_Event event)
	{
		InputEvent inputEvent;
		inputEvent.timestampMs = cast(uint) event.common.timestamp;

		switch (event.type)
		{
		case SDL_EVENT_KEY_DOWN:
		case SDL_EVENT_KEY_UP:
			inputEvent.device = _keyboard;
			inputEvent.type = event.type == SDL_EVENT_KEY_DOWN ? InputEventType.keyPress : InputEventType.keyRelease;
			inputEvent.key.keycode = sdlScancodeToEvdev(event.key.scancode);

			// Update XKB state
			_keyboard.updateKey(inputEvent.key.keycode, event.type == SDL_EVENT_KEY_DOWN);

			emitEvent(inputEvent);
			break;

		case SDL_EVENT_MOUSE_MOTION:
			inputEvent.device = _pointer;
			inputEvent.type = InputEventType.pointerMotion;
			inputEvent.pointerMotion.delta.x = event.motion.xrel;
			inputEvent.pointerMotion.delta.y = event.motion.yrel;
			inputEvent.pointerMotion.deltaUnaccel.x = event.motion.xrel;
			inputEvent.pointerMotion.deltaUnaccel.y = event.motion.yrel;
			emitEvent(inputEvent);
			break;

		case SDL_EVENT_MOUSE_BUTTON_DOWN:
		case SDL_EVENT_MOUSE_BUTTON_UP:
			inputEvent.device = _pointer;
			inputEvent.type = InputEventType.pointerButton;
			inputEvent.pointerButton.button = sdlButtonToEvdev(event.button.button);
			inputEvent.pointerButton.pressed = event.type == SDL_EVENT_MOUSE_BUTTON_DOWN;
			emitEvent(inputEvent);
			break;

		case SDL_EVENT_MOUSE_WHEEL:
			if (event.wheel.y != 0)
			{
				inputEvent.device = _pointer;
				inputEvent.type = InputEventType.pointerAxis;
				inputEvent.pointerAxis.axis = 0; // vertical
				inputEvent.pointerAxis.value = event.wheel.y * -15.0;
				emitEvent(inputEvent);
			}
			if (event.wheel.x != 0)
			{
				inputEvent.device = _pointer;
				inputEvent.type = InputEventType.pointerAxis;
				inputEvent.pointerAxis.axis = 1; // horizontal
				inputEvent.pointerAxis.value = event.wheel.x * 15.0;
				emitEvent(inputEvent);
			}
			break;

		default:
			break;
		}
	}
}

class SdlKeyboardDevice : InputDevice
{
	private xkb_context* _xkbContext;
	private xkb_keymap* _xkbKeymap;
	private xkb_state* _xkbState;
	private int _keymapFd = -1;
	private uint _keymapSize;

	private uint _modsDepressed;
	private uint _modsLatched;
	private uint _modsLocked;
	private uint _group;

	this()
	{
		initializeKeymap();
	}

	override InputDeviceType type()
	{
		return InputDeviceType.keyboard;
	}

	override string name()
	{
		return "SDL Keyboard";
	}

	override string sysname()
	{
		return "sdl-keyboard";
	}

	override bool getKeymap(out int fd, out uint size)
	{
		fd = _keymapFd;
		size = _keymapSize;
		return _keymapFd >= 0;
	}

	override void getModifiers(out uint depressed, out uint latched, out uint locked, out uint group)
	{
		depressed = _modsDepressed;
		latched = _modsLatched;
		locked = _modsLocked;
		group = _group;
	}

	void updateKey(uint keycode, bool pressed)
	{
		if (!_xkbState)
			return;

		// XKB uses evdev keycodes + 8
		uint xkbKey = keycode + 8;

		auto direction = pressed ? xkb_key_direction.XKB_KEY_DOWN : xkb_key_direction.XKB_KEY_UP;

		xkb_state_update_key(_xkbState, xkbKey, direction);

		_modsDepressed = xkb_state_serialize_mods(_xkbState, xkb_state_component.XKB_STATE_MODS_DEPRESSED);
		_modsLatched = xkb_state_serialize_mods(_xkbState, xkb_state_component.XKB_STATE_MODS_LATCHED);
		_modsLocked = xkb_state_serialize_mods(_xkbState, xkb_state_component.XKB_STATE_MODS_LOCKED);
		_group = xkb_state_serialize_layout(_xkbState, xkb_state_component.XKB_STATE_LAYOUT_EFFECTIVE);
	}

	void cleanup()
	{
		if (_keymapFd >= 0)
		{
			close(_keymapFd);
			_keymapFd = -1;
		}
		if (_xkbState)
		{
			xkb_state_unref(_xkbState);
			_xkbState = null;
		}
		if (_xkbKeymap)
		{
			xkb_keymap_unref(_xkbKeymap);
			_xkbKeymap = null;
		}
		if (_xkbContext)
		{
			xkb_context_unref(_xkbContext);
			_xkbContext = null;
		}
	}

	private void initializeKeymap()
	{
		import wayland.util.shm_helper : createMmapableFile;

		_xkbContext = xkb_context_new(xkb_context_flags.XKB_CONTEXT_NO_FLAGS);
		if (!_xkbContext)
			throw new Exception("Failed to create XKB context");

		// Load default keymap (respects XKB_DEFAULT_* environment variables)
		_xkbKeymap = xkb_keymap_new_from_names(_xkbContext, null, xkb_keymap_compile_flags.XKB_KEYMAP_COMPILE_NO_FLAGS);
		if (!_xkbKeymap)
			throw new Exception("Failed to create XKB keymap");

		_xkbState = xkb_state_new(_xkbKeymap);
		if (!_xkbState)
			throw new Exception("Failed to create XKB state");

		// Create mmap'd keymap file for Wayland clients
		auto keymapStr = xkb_keymap_get_as_string(_xkbKeymap, xkb_keymap_format.XKB_KEYMAP_FORMAT_TEXT_V1);
		if (!keymapStr)
			throw new Exception("Failed to get keymap string");

		_keymapSize = cast(uint)(strlen(keymapStr) + 1);
		_keymapFd = createMmapableFile(_keymapSize);
		if (_keymapFd < 0)
			throw new Exception("Failed to create keymap file");

		auto ptr = mmap(null, _keymapSize, PROT_READ | PROT_WRITE, MAP_SHARED, _keymapFd, 0);
		if (ptr == MAP_FAILED)
		{
			close(_keymapFd);
			_keymapFd = -1;
			throw new Exception("Failed to mmap keymap file");
		}

		memcpy(ptr, keymapStr, _keymapSize);
		munmap(ptr, _keymapSize);

		logInfo("XKB keymap initialized");
	}
}

class SdlPointerDevice : InputDevice
{
	override InputDeviceType type()
	{
		return InputDeviceType.pointer;
	}

	override string name()
	{
		return "SDL Pointer";
	}

	override string sysname()
	{
		return "sdl-pointer";
	}
}

// Scancode/button conversion helpers

private uint sdlButtonToEvdev(ubyte sdlButton)
{
	import linux.input;

	switch (sdlButton)
	{
	case SDL_BUTTON_LEFT:
		return BTN_LEFT;
	case SDL_BUTTON_MIDDLE:
		return BTN_MIDDLE;
	case SDL_BUTTON_RIGHT:
		return BTN_RIGHT;
	case SDL_BUTTON_X1:
		return BTN_SIDE;
	case SDL_BUTTON_X2:
		return BTN_EXTRA;
	default:
		return BTN_LEFT;
	}
}

private uint sdlScancodeToEvdev(SDL_Scancode scancode)
{
	import linux.input;

	// Map SDL scancodes to evdev keycodes
	static immutable uint[uint] evdevMap = [
		SDL_Scancode.a: KEY_A, SDL_Scancode.b: KEY_B, SDL_Scancode.c: KEY_C, SDL_Scancode.d: KEY_D, SDL_Scancode.e: KEY_E,
		SDL_Scancode.f: KEY_F, SDL_Scancode.g: KEY_G, SDL_Scancode.h: KEY_H, SDL_Scancode.i: KEY_I, SDL_Scancode.j: KEY_J,
		SDL_Scancode.k: KEY_K, SDL_Scancode.l: KEY_L, SDL_Scancode.m: KEY_M, SDL_Scancode.n: KEY_N, SDL_Scancode.o: KEY_O,
		SDL_Scancode.p: KEY_P, SDL_Scancode.q: KEY_Q, SDL_Scancode.r: KEY_R, SDL_Scancode.s: KEY_S, SDL_Scancode.t: KEY_T,
		SDL_Scancode.u: KEY_U, SDL_Scancode.v: KEY_V, SDL_Scancode.w: KEY_W, SDL_Scancode.x: KEY_X, SDL_Scancode.y: KEY_Y,
		SDL_Scancode.z: KEY_Z, 30: KEY_1, 31: KEY_2, 32: KEY_3, 33: KEY_4, 34: KEY_5, 35: KEY_6, 36: KEY_7,
		37: KEY_8, 38: KEY_9, 39: KEY_0, SDL_Scancode.return_: KEY_ENTER, SDL_Scancode.escape: KEY_ESC,
		SDL_Scancode.backspace: KEY_BACKSPACE, SDL_Scancode.tab: KEY_TAB, SDL_Scancode.space: KEY_SPACE,
		SDL_Scancode.minus: KEY_MINUS, SDL_Scancode.equals: KEY_EQUAL, SDL_Scancode.leftBracket: KEY_LEFTBRACE,
		SDL_Scancode.rightBracket: KEY_RIGHTBRACE, SDL_Scancode.backslash: KEY_BACKSLASH,
		SDL_Scancode.semicolon: KEY_SEMICOLON, SDL_Scancode.apostrophe: KEY_APOSTROPHE, SDL_Scancode.grave: KEY_GRAVE,
		SDL_Scancode.comma: KEY_COMMA, SDL_Scancode.period: KEY_DOT, SDL_Scancode.slash: KEY_SLASH,
		SDL_Scancode.capsLock: KEY_CAPSLOCK, SDL_Scancode.f1: KEY_F1, SDL_Scancode.f2: KEY_F2, SDL_Scancode.f3: KEY_F3,
		SDL_Scancode.f4: KEY_F4, SDL_Scancode.f5: KEY_F5, SDL_Scancode.f6: KEY_F6, SDL_Scancode.f7: KEY_F7,
		SDL_Scancode.f8: KEY_F8, SDL_Scancode.f9: KEY_F9, SDL_Scancode.f10: KEY_F10, SDL_Scancode.f11: KEY_F11,
		SDL_Scancode.f12: KEY_F12, SDL_Scancode.printScreen: KEY_SYSRQ, SDL_Scancode.scrollLock: KEY_SCROLLLOCK,
		SDL_Scancode.pause: KEY_PAUSE, SDL_Scancode.insert: KEY_INSERT, SDL_Scancode.home: KEY_HOME,
		SDL_Scancode.pageUp: KEY_PAGEUP, SDL_Scancode.delete_: KEY_DELETE, SDL_Scancode.end: KEY_END,
		SDL_Scancode.pageDown: KEY_PAGEDOWN, SDL_Scancode.right: KEY_RIGHT, SDL_Scancode.left: KEY_LEFT,
		SDL_Scancode.down: KEY_DOWN, SDL_Scancode.up: KEY_UP, 83: KEY_NUMLOCK, SDL_Scancode.kpDivide: KEY_KPSLASH,
		SDL_Scancode.kpMultiply: KEY_KPASTERISK, SDL_Scancode.kpMinus: KEY_KPMINUS, SDL_Scancode.kpPlus: KEY_KPPLUS,
		SDL_Scancode.kpEnter: KEY_KPENTER, SDL_Scancode.kp1: KEY_KP1, SDL_Scancode.kp2: KEY_KP2, SDL_Scancode.kp3: KEY_KP3,
		SDL_Scancode.kp4: KEY_KP4, SDL_Scancode.kp5: KEY_KP5, SDL_Scancode.kp6: KEY_KP6, SDL_Scancode.kp7: KEY_KP7,
		SDL_Scancode.kp8: KEY_KP8, SDL_Scancode.kp9: KEY_KP9, SDL_Scancode.kp0: KEY_KP0, SDL_Scancode.kpPeriod: KEY_KPDOT,
		100: KEY_102ND, SDL_Scancode.lCtrl: KEY_LEFTCTRL, SDL_Scancode.lShift: KEY_LEFTSHIFT,
		SDL_Scancode.lAlt: KEY_LEFTALT, SDL_Scancode.lGui: KEY_LEFTMETA, SDL_Scancode.rCtrl: KEY_RIGHTCTRL,
		SDL_Scancode.rShift: KEY_RIGHTSHIFT, SDL_Scancode.rAlt: KEY_RIGHTALT, SDL_Scancode.rGui: KEY_RIGHTMETA,
	];

	if (auto p = scancode in evdevMap)
		return *p;

	// Fallback
	return cast(uint) scancode;
}
