// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.layer;

// Window stacking layers.
// Used by both the WindowManager (logical state) and SceneGraph (rendering).
enum Layer
{
	Desktop, // Wallpaper
	Below, // User requested below normal
	Normal, // Regular windows
	Dock, // Panels, taskbars
	Above, // Always on top
	Notification, // Transient notifications
	Fullscreen, // Active fullscreen window
	Overlay, // Lock screen, critical dialogs
	Cursor, // Software cursor (always on top)
}
