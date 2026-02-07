// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.cursor.theme;

import trinove.cursor.image;
import core.atomic;

// A named set of cursor images (e.g. "default", "text", "pointer").
class CursorTheme
{
	private
	{
		string _name;
		shared(int) _refCount = 0;
		CursorImage[string] _cursors;
	}

	this(string name)
	{
		_name = name;
	}

	@property string name() const => _name;

	void acquire()
	{
		atomicOp!"+="(_refCount, 1);
	}

	bool release()
	{
		return atomicOp!"-="(_refCount, 1) == 0;
	}

	int refCount() const => atomicLoad(_refCount);

	// Add or replace a cursor image.
	void add(string cursorName, CursorImage image)
	{
		_cursors[cursorName] = image;
	}

	// Returns null if the cursor doesn't exist.
	CursorImage get(string cursorName)
	{
		if (auto p = cursorName in _cursors)
			return *p;
		return null;
	}
}
