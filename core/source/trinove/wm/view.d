// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.wm.view;

import trinove.math;
import trinove.renderer.canvas : ICanvas, BufferTransform;
import trinove.surface.surface : WaiSurface;
import trinove.surface.subsurface : WaiSubsurface;
import trinove.output_manager : OutputManager;

// Window management capabilities the WM supports.
enum WmCapabilityFlags : uint
{
	none = 0,
	windowMenu = 1 << 0,
	maximize = 1 << 1,
	fullscreen = 1 << 2,
	minimize = 1 << 3,
}

// Base class for all interactive surfaces managed by the compositor.
// Represents windows, popups, layer surfaces, etc.
abstract class View
{
	// Position of the client content in compositor space.
	// Always the client content origin.
	Vector2I position;

	// Effective surface size in surface-local coordinates.
	// Accounts for buffer_scale and viewporter destination if set.
	// Set by the protocol layer (xdg_toplevel / xdg_popup) on every commit.
	Vector2U surfaceSize;

	// Whether the view is visible/mapped
	bool mapped = false;

	// Back-reference to protocol object (WaiXdgToplevel, WaiXdgPopup, etc.)
	Object protocol;

	private Rect _clientBounds;

	// Set the committed xdg_surface window geometry in surface-local coords.
	// Either the client-provided rect or the full surface rect when the client never calls set_window_geometry.
	void setClientBounds(Rect r)
	{
		_clientBounds = r;
	}

	this()
	{
	}

	// Get the WaiSurface associated with this view
	abstract WaiSurface getSurface();

	// Get position in compositor space (for popups this walks the chain)
	Vector2I absolutePosition()
	{
		return position;
	}

	// Full surface rect in compositor space (position + surfaceSize).
	Rect clientGeometry()
	{
		return Rect(absolutePosition(), surfaceSize);
	}

	// Compositor-space bounding box used for pointer hit-testing.
	Rect inputBounds()
	{
		return Rect(absolutePosition(), surfaceSize);
	}

	// Compositor-space origin of the client content surface.
	Vector2I contentOrigin()
	{
		return absolutePosition();
	}

	// Check if a point (in compositor space) is inside this view's client content.
	bool containsPoint(Vector2I pt)
	{
		return clientGeometry().contains(pt);
	}

	// Committed xdg_surface window geometry in surface-local coords.
	// Always set by the protocol layer before the WM uses this view.
	Rect clientBounds()
	{
		return _clientBounds;
	}

	// Draw this view's surface tree at the given compositor-space origin.
	// You should override this for internal windows but by default
	// it draws the surface from getSurface.
	void draw(ICanvas canvas, Vector2I origin)
	{
		drawSurfaceTree(canvas, getSurface(), origin);
	}

	// Recursively draw a surface and all its subsurfaces at origin.
	void drawSurfaceTree(ICanvas canvas, WaiSurface surf, Vector2I origin)
	{
		if (surf is null)
			return;

		if (surf.currentBuffer !is null)
		{
			auto ss = surf.computeSurfaceState();
			canvas.drawTexture(Vector2F(origin.x, origin.y),
				Vector2F(ss.size.x, ss.size.y),
				surf.currentBuffer.getITexture(),
				ss.srcRect, ss.uvTransform, [1.0f, 1.0f, 1.0f, 1.0f], 1.0f);
		}

		foreach (sub; surf.subsurfaceChildren)
		{
			if (sub.surface is null || sub.surface.currentBuffer is null)
				continue;
			drawSurfaceTree(canvas, sub.surface,
				Vector2I(origin.x + sub.position.x, origin.y + sub.position.y));
		}
	}

	// Recursively fire wl_callback "done" events for this surface and all subsurfaces.
	// The WM calls this in onFramePresented() for every visible view it drew.
	void fireAllCallbacks()
	{
		fireCallbacksFor(getSurface());
	}

	private void fireCallbacksFor(WaiSurface surf)
	{
		if (surf is null)
			return;
		surf.sendFrameCallbacks();
		foreach (sub; surf.subsurfaceChildren)
			fireCallbacksFor(sub.surface);
	}

	// Translate root-surface-local damage to compositor space and push it to the output
	// manager. Damage is clamped to the surface bounds before translation.
	// Clears rootLocalDamage after draining.
	void pushDamage(OutputManager om, OutputManager.ManagedOutput output)
	{
		auto surf = getSurface();
		if (surf is null)
			return;
		auto orig = absolutePosition();
		auto bounds = Rect(0, 0, surfaceSize.x, surfaceSize.y);
		foreach (r; surf.rootLocalDamage.clampedTo(bounds))
			om.addDamage(Rect(r.position.x + orig.x, r.position.y + orig.y, r.size.x, r.size.y));
		surf.rootLocalDamage.clear();
	}
}
