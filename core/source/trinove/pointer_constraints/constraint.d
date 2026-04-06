// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.pointer_constraints.constraint;

import trinove.math;
import trinove.log;
import trinove.protocols.pointer_constraints_v1;
import wayland.util : WlFixed;
import std.algorithm.comparison : max, min;

enum ConstraintType
{
	none,
	lock,
	confine,
}

alias Lifetime = ZwpPointerConstraintsV1.Lifetime;

// Pointer constraint state stored by Seat.
class PointerConstraint
{
	ConstraintType type;
	bool active;
	Lifetime lifetime;
	Rect[] region; // surface-local, empty = entire surface

	// Lock-specific: cursor position hint (surface-local)
	WlFixed cursorHintX;
	WlFixed cursorHintY;
	bool hasCursorHint;

	// Protocol event callbacks (set by protocol objects)
	void delegate() onActivated;
	void delegate() onDeactivated;

	void activate()
	{
		if (active || type == ConstraintType.none)
			return;
		active = true;
		logDebug("Pointer constraint activated (type=%s)", type == ConstraintType.lock ? "lock" : "confine");
		if (onActivated !is null)
			onActivated();
	}

	void deactivate()
	{
		if (!active)
			return;
		active = false;
		hasCursorHint = false;
		logDebug("Pointer constraint deactivated (type=%s)", type == ConstraintType.lock ? "lock" : "confine");
		if (onDeactivated !is null)
			onDeactivated();
		if (lifetime == Lifetime.oneshot)
		{
			type = ConstraintType.none;
			onActivated = null;
			onDeactivated = null;
		}
	}

	// Check if a surface-local point is within the constraint region.
	bool pointInRegion(int sx, int sy)
	{
		if (region.length == 0)
			return true; // null region = entire surface

		foreach (r; region)
		{
			if (sx >= r.position.x && sx < r.position.x + cast(int) r.size.x && sy >= r.position.y && sy < r.position.y + cast(
					int) r.size.y)
				return true;
		}
		return false;
	}

	// Clamp a surface-local point to the constraint region.
	// surfaceSize is used when region is empty (entire surface).
	Vector2I clampToRegion(int sx, int sy, Vector2U surfaceSize)
	{
		if (region.length == 0)
		{
			return Vector2I(max(0, min(sx, cast(int) surfaceSize.x - 1)), max(0, min(sy, cast(int) surfaceSize.y - 1)));
		}

		// Check if already inside any rect
		foreach (r; region)
		{
			if (sx >= r.position.x && sx < r.position.x + cast(int) r.size.x && sy >= r.position.y && sy < r.position.y + cast(
					int) r.size.y)
				return Vector2I(sx, sy);
		}

		// Find nearest point on nearest rect boundary
		long bestDist = long.max;
		Vector2I best = Vector2I(sx, sy);

		foreach (r; region)
		{
			int right = r.position.x + cast(int) r.size.x - 1;
			int bottom = r.position.y + cast(int) r.size.y - 1;
			int cx = sx < r.position.x ? r.position.x : (sx > right ? right : sx);
			int cy = sy < r.position.y ? r.position.y : (sy > bottom ? bottom : sy);
			long dx = sx - cx;
			long dy = sy - cy;
			long dist = dx * dx + dy * dy;
			if (dist < bestDist)
			{
				bestDist = dist;
				best = Vector2I(cx, cy);
			}
		}

		return best;
	}

	// Reset this constraint, called by the seat when the protocol object is destroyed.
	void reset()
	{
		if (active)
			deactivate();
		type = ConstraintType.none;
		onActivated = null;
		onDeactivated = null;
	}
}
