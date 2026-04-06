// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.region;

import trinove.math.rect : Rect;
import wayland.server;
import wayland.native.server : wl_resource;
import wayland.util : ObjectCache;

class Region : WlRegion
{
	Rect[] rects;

	this(WlClient cl, int id)
	{
		super(cl, WlRegion.ver, id);
	}

	static Rect[] rectsFromRegionResource(wl_resource* resource)
	{
		if (resource is null)
			return null;
		auto r = cast(Region) ObjectCache.get(resource);
		return r !is null ? r.rects : null;
	}

	override void destroy(WlClient cl)
	{

	}

	override void add(WlClient cl, int x, int y, int width, int height)
	{
		rects ~= Rect(x, y, width, height);
	}

	override void subtract(WlClient cl, int x, int y, int width, int height)
	{
		immutable rs = Rect(x, y, width, height);
		foreach (i, r; rects)
		{
			if (r == rs)
			{
				import std.algorithm.mutation : remove;

				rects = rects.remove(i);
				return;
			}
		}
	}

	override string toString() const
	{
		string result = "Rects{ ";
		foreach (r; rects)
		{
			result ~= r.toString() ~ " ";
		}
		result ~= "}";
		return result;
	}
}
