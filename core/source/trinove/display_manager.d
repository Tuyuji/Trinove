// SPDX-License-Identifier: GPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.display_manager;

import wayland.server;

private __gshared WlDisplay _gdisplay;
private __gshared string _gdisplayName;

pragma(inline):
WlDisplay getDisplay()
{
	return _gdisplay;
}

string getDisplayName()
{
	return _gdisplayName;
}

void setDisplayName(string name)
{
	_gdisplayName = name;
}

void initDisplay()
{
	_gdisplay = WlDisplay.create();
	_gdisplay.setDefaultMaxBufferSize(128 * 1024);
}
