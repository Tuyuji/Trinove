// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.surface.cursor_role;

import trinove.surface.role : ISurfaceRole;
import trinove.surface.surface : WaiSurface;
import trinove.seat : Seat;
import trinove.math.rect : Rect;

class CursorRole : ISurfaceRole
{
	Seat seat;
	WaiSurface surface;

	this(Seat seat, WaiSurface surface)
	{
		this.seat = seat;
		this.surface = surface;
	}

	void onDamage(Rect damage)
	{
		if (seat !is null)
			seat.markCursorDirty();
	}

	void onDamageBuffer(Rect damage)
	{
		if (seat !is null)
			seat.markCursorDirty();
	}

	void onCommit()
	{
		if (seat !is null)
			seat.markCursorDirty();
	}

	void onSurfaceDestroyed()
	{
		if (seat !is null)
			seat.clearCursorSurface(surface);

		seat = null;
		surface = null;
	}
}
