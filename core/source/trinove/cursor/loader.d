// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.cursor.loader;

import trinove.cursor.image;
import trinove.cursor.theme;
import trinove.cursor.xcursor;
import trinove.log;

private string[] cursorSearchDirs(string themeName)
{
	import std.process : environment;
	import std.string : split;
	import std.path : buildPath;

	string[] basePaths;

	auto xcursorPath = environment.get("XCURSOR_PATH", "");
	if (xcursorPath.length > 0)
	{
		basePaths = xcursorPath.split(":");
	}
	else
	{
		auto home = environment.get("HOME", "");
		auto xdgDataHome = environment.get("XDG_DATA_HOME", home.length > 0 ? home ~ "/.local/share" : "");
		auto xdgDataDirs = environment.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share");

		if (home.length > 0)
			basePaths ~= home ~ "/.icons";
		if (xdgDataHome.length > 0)
			basePaths ~= xdgDataHome ~ "/icons";
		foreach (dir; xdgDataDirs.split(":"))
			basePaths ~= dir ~ "/icons";
		basePaths ~= "/usr/share/pixmaps";
	}

	string[] result;
	foreach (base; basePaths)
		result ~= buildPath(base, themeName, "cursors");
	return result;
}

uint preferredCursorSize()
{
	import std.process : environment;
	import std.conv : to, ConvException;

	try
		return environment.get("XCURSOR_SIZE", "24").to!uint;
	catch (ConvException)
		return 24;
}

// Load every cursor in the theme into `theme`.
void loadSystemCursorTheme(CursorTheme theme, string themeName, uint size = 0)
{
	import std.file : exists, isDir, dirEntries, SpanMode, isSymlink, readLink;
	import std.path : buildPath, baseName;

	if (size == 0)
		size = preferredCursorSize();

	// Find the first cursors directory that actually exists.
	string cursorsDir;
	foreach (dir; cursorSearchDirs(themeName))
	{
		if (exists(dir) && isDir(dir))
		{
			cursorsDir = dir;
			break;
		}
	}

	if (cursorsDir.length == 0)
	{
		logWarn("cursor: no cursors directory found for theme '%s'", themeName);
		return;
	}

	CursorImage[string] images; // name -> loaded image
	string[string] symlinks; // alias -> target name
	uint uniqueCount;

	// Load real files.
	foreach (entry; dirEntries(cursorsDir, SpanMode.shallow))
	{
		auto name = baseName(entry.name);
		if (isSymlink(entry.name))
		{
			symlinks[name] = baseName(readLink(entry.name));
		}
		else
		{
			auto img = loadXCursorFile(entry.name, size);
			if (img !is null)
			{
				images[name] = img;
				uniqueCount++;
			}
		}
	}

	// Deal with symlinks.
	foreach (alias_, target; symlinks)
	{
		string cur = target;
		foreach (_; 0 .. 8)
		{
			if (auto p = cur in images)
			{
				images[alias_] = *p;
				break;
			}
			if (auto p = cur in symlinks)
				cur = *p;
			else
				break;
		}
	}

	foreach (name, img; images)
		theme.add(name, img);

	logInfo("Loaded %d cursor names (%d unique images) from theme '%s' at size %d", images.length, uniqueCount, themeName,
			size);
}
