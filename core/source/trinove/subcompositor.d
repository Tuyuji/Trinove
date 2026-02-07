// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.subcompositor;

import wayland.server.protocol;
import wayland.server;
import trinove.surface.surface : WaiSurface;
import trinove.surface.subsurface : WaiSubsurface;

class WaiSubcompositor : WlSubcompositor
{
	this(WlDisplay display)
	{
		super(display, ver);
	}

	override protected void destroy(WlClient cl, Resource res)
	{
	}

	override protected WlSubsurface getSubsurface(WlClient cl, Resource res, uint id, WlSurface surface, WlSurface parent)
	{
		auto waiSurface = cast(WaiSurface) surface;
		auto waiParent = cast(WaiSurface) parent;

		if (waiSurface is null || waiParent is null)
		{
			res.postError(Error.badSurface, "Invalid surface");
			return null;
		}

		if (waiSurface.role !is null)
		{
			res.postError(Error.badSurface, "Surface already has a role");
			return null;
		}

		if (waiSurface is waiParent)
		{
			res.postError(Error.badSurface, "Surface cannot be its own parent");
			return null;
		}

		// Parent can't be a descendant of surface
		if (isAncestorOf(waiSurface, waiParent))
		{
			res.postError(Error.badSurface, "Creating subsurface would form a cycle");
			return null;
		}

		return new WaiSubsurface(waiSurface, waiParent, cl, id);
	}

	// Check if candidate is an ancestor of surface through subsurface chains.
	private static bool isAncestorOf(WaiSurface candidate, WaiSurface surface)
	{
		auto current = surface.subsurfaceParent;
		while (current !is null)
		{
			if (current is candidate)
				return true;
			current = current.subsurfaceParent;
		}
		return false;
	}
}
