// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.wm.view;

import trinove.math;
import trinove.renderer.scene;
import trinove.surface.surface : WaiSurface;

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
	// Container/root node that groups contentNode and subsurface children.
	// This is what gets added to the scene graph hierarchy.
	SceneNode containerNode;

	// The scene node for rendering content
	RectNode contentNode;

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
		containerNode = new SceneNode();
		containerNode.visible = false;
		contentNode = new RectNode();
		containerNode.addChild(contentNode);
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
	// Uses the full visual bounds (content + subsurfaces) regardless of window geometry,
	// because xdg_surface window geometry only affects placement/alignment.
	Rect inputBounds()
	{
		auto local = containerNode.visualBounds();
		return Rect(absolutePosition() + local.position, local.size);
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

	// Update content node visibility based on mapped state
	void syncVisibility()
	{
		containerNode.visible = mapped;
	}
}
