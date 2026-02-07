// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.backends.sdl.subsystem;

import trinove.subsystem;
import trinove.log;
import bindbc.sdl;
import bindbc.loader;
import std.string : fromStringz;

class SdlSubsystem : ISubsystem
{
	override string name()
	{
		return "SdlSubsystem";
	}

	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.SDL;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	override void initialize()
	{
		// Load SDL library
		auto result = loadSDL();
		if (result != LoadMsg.success)
		{
			foreach (error; bindbc.loader.errors)
				logError("SDL load error: %s", error.message.fromStringz);
			throw new Exception("Failed to load SDL library");
		}

		if (!SDL_Init(SDL_INIT_VIDEO))
		{
			auto err = SDL_GetError();
			throw new Exception("Failed to initialize SDL: " ~ (err ? err.fromStringz.idup : "unknown error"));
		}

		SDL_SetHint(SDL_HINT_MOUSE_RELATIVE_SYSTEM_SCALE, "1");

		debug logDebug("SDL initialized");
	}

	override void shutdown()
	{
		SDL_Quit();
		debug logDebug("SDL shutdown");
	}
}
