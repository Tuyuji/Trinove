// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.cursor.manager;

import trinove.cursor.theme;
import trinove.subsystem;
import trinove.log;

// Subsystem that manages the lifecycle of CursorTheme instances.
class CursorThemeManager : ISubsystem
{
	private CursorTheme[string] _themes;

	override string name()
	{
		return "CursorThemeManager";
	}

	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.CursorThemeManager;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	override void initialize()
	{
		logInfo("CursorThemeManager initialized");
	}

	override void shutdown()
	{
		foreach (n, theme; _themes)
		{
			if (theme.refCount > 0)
				logWarn("CursorTheme '%s' still has %d reference(s) at shutdown", n, theme.refCount);
		}
		_themes = null;
		logInfo("CursorThemeManager shutdown");
	}

	// Return the theme with the given name, creating an empty one if needed.
	// The caller receives an acquired reference and must call releaseTheme when done.
	CursorTheme getTheme(string themeName)
	{
		if (auto p = themeName in _themes)
		{
			(*p).acquire();
			return *p;
		}

		auto theme = new CursorTheme(themeName);
		theme.acquire();
		_themes[themeName] = theme;
		logDebug("Created cursor theme '%s'", themeName);
		return theme;
	}

	// Release a previously acquired reference. Evicts the theme when refcount hits zero.
	void releaseTheme(CursorTheme theme)
	{
		if (theme is null)
			return;
		if (theme.release())
		{
			_themes.remove(theme.name);
			logDebug("Evicted cursor theme '%s'", theme.name);
		}
	}
}
