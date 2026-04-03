// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.wm.imanager;

import trinove.wm.view : WmCapabilityFlags;
import trinove.wm.window : Window;
import trinove.wm.popup : Popup;
import trinove.wm.decoration : DecorationHit;
import trinove.wm.conductor : WindowConductor;
import trinove.output_manager : OutputManager;
import trinove.renderer.canvas : ICanvas, IRenderEntry;
import trinove.math : Vector2I, Vector2U;
import trinove.seat : Seat;
import std.typecons : Nullable;

interface IWindowManager : IRenderEntry
{
	@property string name();

	// Return the set of capabilities this WM supports.
	// The conductor broadcasts these to all client windows when the WM is set or replaced.
	@property WmCapabilityFlags wmCapabilities();

	// Called before any onWindowAdded notifications for existing windows.
	void startup(WindowConductor conductor);

	// Called on compositor shutdown or when this manager is replaced.
	// Implementations should tear down any resources they own (decorations, scene nodes, etc.).
	void shutdown();

	// A new toplevel window has been mapped. WM should place it and set focus.
	void onWindowAdded(Window window);

	// A toplevel window is being removed. WM should tear down decorations.
	// The window is still in the conductor's list at this point.
	void onWindowRemoved(Window window);

	void onPopupAdded(Popup popup);

	void onPopupRemoved(Popup popup);

	// === State-change notifications ===

	// Called when window geometry, layer, or title changes. WM updates its
	// decoration geometry to match.
	void onWindowStateChanged(Window window);

	// Called when keyboard focus changes for this window.
	void onWindowFocusChanged(Window window, bool focused);

	// Called when a window has been raised to the top of its layer.
	// WM reorders its scene nodes accordingly.
	void onWindowRaised(Window window);

	void onMaximizeRequest(Window window);
	void onUnmaximizeRequest(Window window);
	void onFullscreenRequest(Window window, OutputManager.ManagedOutput output);
	void onUnfullscreenRequest(Window window);
	void onMinimizeRequest(Window window);

	// Called when the client expresses a decoration preference.
	// Assume CSD by default.
	void onDecorationPreference(Window window, bool ssd);

	// Called when the client requests a window menu (xdg_toplevel.show_window_menu).
	// localPos is relative to the windows content origin.
	void onShowWindowMenuRequest(Seat seat, Window window, Vector2I localPos);

	// Called when the client requests an interactive move (xdg_toplevel.move).
	void onMoveRequest(Seat seat, Window window);

	// Called when the client requests an interactive resize (xdg_toplevel.resize).
	void onResizeRequest(Seat seat, Window window, DecorationHit edge);

	// === Configure lifecycle ===

	// Called when the client committed a buffer after acking a tracked configure.
	// window.state.* and window.surfaceSize are already updated.
	// `position` carries the intended position from the configure, or is null if
	// none was set — in which case the WM should use window.position.
	// WM should call conductor.applyGeometry to apply the final placement.
	void onWindowConfigureApplied(Window window, Nullable!Vector2I position);

	// Called when the client committed a new buffer size during an interactive
	// resize without an acked configure.
	void onWindowResizeCommitted(Window window, Vector2U newSize);
}
