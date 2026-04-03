// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.wm.popup;

import trinove.math;
import trinove.surface.surface : WaiSurface;
import trinove.wm.view;
import trinove.wm.window;
import trinove.seat : Seat;

// A popup surface managed by the compositor.
//
// Note: View.position is used as the relative position (to parent).
// Use absolutePosition() to get compositor-space position.
class Popup : View
{
	// The toplevel window this popup chain belongs to
	Window parentWindow;

	// Popup chain for nested popups
	Popup parentPopup; // null if parent is toplevel
	Popup childPopup; // first child popup (submenu)

	// The seat that holds an explicit grab on this popup, or null if ungrabbed
	Seat grabbedSeat;

	// Returns true if this popup has an active explicit grab
	@property bool grabbed() => grabbedSeat !is null;

	// Get absolute position in compositor space (walks popup chain)
	override Vector2I absolutePosition()
	{
		auto pos = position; // relative position

		auto p = parentPopup;
		while (p !is null)
		{
			pos = Vector2I(pos.x + p.position.x, pos.y + p.position.y);
			p = p.parentPopup;
		}

		// Add parent window content position
		if (parentWindow !is null)
		{
			pos = Vector2I(parentWindow.position.x + pos.x, parentWindow.position.y + pos.y);
		}

		return pos;
	}

	// Request that this popup dismiss itself.
	void dismiss()
	{
		import trinove.xdg_shell.popup : WaiXdgPopup;

		auto p = cast(WaiXdgPopup) protocol;
		if (p)
			p.dismiss();
	}

	// Get the WaiSurface associated with this popup (via xdgPopup)
	override WaiSurface getSurface()
	{
		import trinove.xdg_shell.popup : WaiXdgPopup;

		auto popup = cast(WaiXdgPopup) protocol;
		if (popup && popup.xdgSurface)
			return popup.xdgSurface.surface;
		return null;
	}
}
