// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.surface.role;

import trinove.math.rect : Rect;

// A surface can only have one role.
// Role assignment is done by protocol requests like get_xdg_surface, set_cursor, etc.
interface ISurfaceRole
{
	void onDamage(Rect damage);
	void onDamageBuffer(Rect damage);

	void onCommit();

	// Called when the wl_surface hosting this role is destroyed.
	// Clean up any references to the surface here.
	// If you inherit some wayland class then cleanup in your destroy listener instead.
	void onSurfaceDestroyed();
}

// Sub-role interface for XdgSurface (toplevel/popup).
// XdgSurface holds this to delegate to the appropriate role.
interface IXdgRole
{
	// Called when the parent XdgSurface receives a commit.
	void onCommit();

	// Called when XdgSurface.ackConfigure is received.
	void onAck(uint serial);

	// Called when the xdg_surface hosting this role is destroyed.
	void onXdgSurfaceDestroyed();
}

// Interface for protocol extensions that attach to a surface and need commit notifications.
// Unlike roles (one per surface), multiple extensions can be active simultaneously.
interface ISurfaceExtension
{
	// Called during wl_surface.commit, before role.onCommit().
	void onCommit();

	// Called when the wl_surface hosting this extension is destroyed.
	void onSurfaceDestroyed();

	// Called by XdgTopLevel's sendConfigureWire just before xdg_surface.configure
	// is sent, so injected events share the same serial.
	void onPreConfigure();
}
