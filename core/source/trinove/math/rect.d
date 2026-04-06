// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.math.rect;

import trinove.math.vector;

struct Rect
{
	Vector2I position;
	Vector2U size;

	string toString() const
	{
		import std.format : format;

		return format("Rect(x: %d, y: %d, width: %d, height: %d)", position.x, position.y, size.x, size.y);
	}

pure nothrow @safe @nogc:

	this(int x, int y, uint width, uint height)
	{
		this.position = Vector2I(x, y);
		this.size = Vector2U(width, height);
	}

	this(Vector2I pos, Vector2U sz)
	{
		this.position = pos;
		this.size = sz;
	}

	@property int left() const
	{
		return position.x;
	}

	@property int top() const
	{
		return position.y;
	}

	@property int right() const
	{
		return position.x + cast(int) size.x;
	}

	@property int bottom() const
	{
		return position.y + cast(int) size.y;
	}

	@property uint width() const
	{
		return size.x;
	}

	@property uint height() const
	{
		return size.y;
	}

	bool isEmpty() const
	{
		return size.x == 0 || size.y == 0;
	}

	bool contains(int x, int y) const
	{
		return x >= left && x < right && y >= top && y < bottom;
	}

	bool contains(Vector2I point) const
	{
		return contains(point.x, point.y);
	}

	bool intersects(Rect other) const
	{
		return left < other.right && right > other.left && top < other.bottom && bottom > other.top;
	}

	Rect intersection(Rect other) const
	{
		import std.algorithm : max, min;

		auto x = max(left, other.left);
		auto y = max(top, other.top);
		auto w = min(right, other.right) - x;
		auto h = min(bottom, other.bottom) - y;

		if (w <= 0 || h <= 0)
			return Rect(0, 0, 0, 0);

		return Rect(x, y, cast(uint) w, cast(uint) h);
	}

	Rect unionWith(Rect other) const
	{
		import std.algorithm : max, min;

		auto x = min(left, other.left);
		auto y = min(top, other.top);
		auto w = max(right, other.right) - x;
		auto h = max(bottom, other.bottom) - y;

		return Rect(x, y, cast(uint) w, cast(uint) h);
	}

	Rect offset(int dx, int dy) const
	{
		return Rect(position.x + dx, position.y + dy, size.x, size.y);
	}
}

bool rectsNearby(Rect a, Rect b, int threshold) pure nothrow @safe @nogc
{
	return a.left - threshold < b.right && a.right + threshold > b.left && a.top - threshold < b.bottom && a.bottom + threshold > b
		.top;
}

// Merge `region` with nearby rects in `buf[0..count]` using swap-remove.
// Returns new count. Caller should append `region` after this call.
size_t mergeRect(Rect[] buf, size_t count, ref Rect region, int mergeThreshold) pure nothrow @safe @nogc
{
	for (size_t i = 0; i < count;)
	{
		if (rectsNearby(region, buf[i], mergeThreshold))
		{
			region = region.unionWith(buf[i]);
			buf[i] = buf[count - 1];
			count--;
		}
		else
		{
			i++;
		}
	}
	return count;
}
