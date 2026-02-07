// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.viewporter;

import trinove.protocols.viewporter;
import trinove.surface.surface : WaiSurface, ViewportState;
import trinove.surface.role : ISurfaceExtension;
import trinove.util : onDestroyCallDestroy;
import wayland.server;
import wayland.util : WlFixed;

// Convert WlFixed to double. wayland-d's opCast!double has issues.
private double fixedToDouble(WlFixed f)
{
	return cast(double) cast(int) f.raw / 256.0;
}

class WaiViewporter : WpViewporter
{
	this(WlDisplay display)
	{
		super(display, ver);
	}

	override protected void destroy(WlClient cl, Resource res)
	{
	}

	override protected WpViewport getViewport(WlClient cl, Resource res, uint id, WlResource surface)
	{
		auto waiSurface = cast(WaiSurface) surface;
		if (waiSurface is null)
		{
			res.postError(Error.viewportExists, "Invalid surface");
			return null;
		}

		foreach (ext; waiSurface.extensions)
		{
			if (cast(WaiViewport) ext !is null)
			{
				res.postError(Error.viewportExists, "Surface already has a viewport object associated");
				return null;
			}
		}

		return new WaiViewport(waiSurface, cl, id);
	}
}

final class WaiViewport : WpViewport, ISurfaceExtension
{
	private WaiSurface _surface;
	private ViewportState _pending;
	private bool _dirty;
	private bool _destroyed;

	this(WaiSurface surface, WlClient cl, uint id)
	{
		super(cl, ver, id);
		_surface = surface;
		surface.addExtension(this);

		mixin(onDestroyCallDestroy);
	}

	void onCommit()
	{
		if (_surface is null)
			return;

		if (_dirty)
		{
			_surface.viewport = _pending;
			_dirty = false;
		}

		if (_destroyed)
		{
			_surface.removeExtension(this);
			_surface = null;
		}
	}

	void onSurfaceDestroyed()
	{
		_surface = null;
	}

	override protected void destroy(WlClient cl)
	{
		if (_surface !is null)
		{
			// "If the wp_viewport object is destroyed, the crop and scale
			//  state is removed from the wl_surface. The change will be applied
			//  on the next wl_surface.commit."
			_pending = ViewportState.init;
			_dirty = true;
			_destroyed = true;
		}
	}

	override protected void setSource(WlClient cl, WlFixed x, WlFixed y, WlFixed width, WlFixed height)
	{
		if (_surface is null)
		{
			postError(Error.noSurface, "wl_surface for this viewport is no longer valid");
			return;
		}

		double fx = fixedToDouble(x);
		double fy = fixedToDouble(y);
		double fw = fixedToDouble(width);
		double fh = fixedToDouble(height);

		// All -1.0 = unset
		if (fx == -1.0 && fy == -1.0 && fw == -1.0 && fh == -1.0)
		{
			_pending.hasSource = false;
			_pending.srcX = 0;
			_pending.srcY = 0;
			_pending.srcWidth = 0;
			_pending.srcHeight = 0;
			_dirty = true;
			return;
		}

		if (fx < 0 || fy < 0 || fw <= 0 || fh <= 0)
		{
			postError(Error.badValue, "Invalid source rectangle values");
			return;
		}

		_pending.hasSource = true;
		_pending.srcX = cast(float) fx;
		_pending.srcY = cast(float) fy;
		_pending.srcWidth = cast(float) fw;
		_pending.srcHeight = cast(float) fh;
		_dirty = true;
	}

	override protected void setDestination(WlClient cl, int width, int height)
	{
		if (_surface is null)
		{
			postError(Error.noSurface, "wl_surface for this viewport is no longer valid");
			return;
		}

		// Both -1 = unset
		if (width == -1 && height == -1)
		{
			_pending.hasDest = false;
			_pending.destWidth = 0;
			_pending.destHeight = 0;
			_dirty = true;
			return;
		}

		if (width <= 0 || height <= 0)
		{
			postError(Error.badValue, "Invalid destination size");
			return;
		}

		_pending.hasDest = true;
		_pending.destWidth = width;
		_pending.destHeight = height;
		_dirty = true;
	}
}
