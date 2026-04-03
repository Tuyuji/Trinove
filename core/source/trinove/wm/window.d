// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.wm.window;

import trinove.math;
import trinove.layer;
import trinove.surface.surface : WaiSurface;
import trinove.wm.view;
import trinove.wm.popup;
import trinove.debug_.protocol_tracer : ProtocolTracer;
import std.typecons : Nullable;

struct WindowFlags
{
	bool maximized : 1;
	bool fullscreen : 1;
}

// Data bag for a pending window configure intent.
// Set only the fields that are changing; the protocol layer resolves effective state.
struct WindowConfigureData
{
	Nullable!bool maximized;
	Nullable!bool fullscreen;
	Nullable!Vector2U size;
	Nullable!Vector2I position;

	void mergeFrom(ref const WindowConfigureData other)
	{
		if (!other.maximized.isNull)
			maximized = other.maximized;
		if (!other.fullscreen.isNull)
			fullscreen = other.fullscreen;
		if (!other.size.isNull)
			size = other.size;
		if (!other.position.isNull)
			position = other.position;
	}
}

// Fluent builder returned by Window.configure().
// Build up intent fields, then call send() for tracked or sendHint() for untracked.
struct WindowConfigurer
{
	private Window _window;
	private WindowConfigureData _data;

	ref WindowConfigurer maximize()
	{
		_data.maximized = true;
		return this;
	}

	ref WindowConfigurer unmaximize()
	{
		_data.maximized = false;
		return this;
	}

	ref WindowConfigurer fullscreen()
	{
		_data.fullscreen = true;
		return this;
	}

	ref WindowConfigurer unfullscreen()
	{
		_data.fullscreen = false;
		return this;
	}

	ref WindowConfigurer size(Vector2U s)
	{
		_data.size = s;
		return this;
	}

	ref WindowConfigurer position(Vector2I p)
	{
		_data.position = p;
		return this;
	}

	// Send a tracked configure. The WM receives onWindowConfigureApplied when it lands.
	void send()
	{
		_window.deliverConfigure(_data);
	}

	// Send an untracked size hint (e.g. during interactive resize). No ack tracking.
	void sendHint()
	{
		_window.deliverResizeHint(_data);
	}
}

struct WindowState
{
	WindowFlags flags;
	alias flags this; // window.state.maximized / .fullscreen work as before.

	bool serverDecorations : 1;
	bool focused : 1;
	bool minimized : 1;
	bool resizing : 1;
}

// A window managed by the compositor.
//
// Represents a toplevel surface and its logical state.
// Subclasses bridge to the underlying protocol (e.g. XdgToplevelWindow for xdg_toplevel).
// Configure handle tracking and serial management are entirely internal to the subclass.
abstract class Window : View
{
	Layer layer = Layer.Normal;

	string title;
	string appId;

	// Confirmed state: updated when the client has acked and committed a configure.
	WindowState state;

	// In-flight state: set when a configure is queued, before the client confirms.
	// WMs may read this for optimistic feedback; use state.* for confirmed values.
	WindowFlags pendingState;

	Vector2U minSize = Vector2U(0, 0);
	Vector2U maxSize = Vector2U(0, 0);

	// Saved geometry for restoring from maximized/fullscreen state.
	Rect savedGeometry;
	// First popup in the chain (null if no popups).
	Popup popup;
	// Parent window for transient/dialog windows (null if top-level).
	Window parentWindow;

	// Tracer lives on the WaiSurface so it survives xdg_toplevel recreation.
	@property bool tracingEnabled()
	{
		auto s = getSurface();
		return s !is null && s.tracingEnabled;
	}

	void enableTracing()
	{
		if (auto s = getSurface())
			s.enableTracing();
	}

	void disableTracing()
	{
		if (auto s = getSurface())
			s.disableTracing();
	}

	// Only call if tracingEnabled is true.
	@property ProtocolTracer tracer()
	{
		return getSurface().tracer;
	}

	// Begin a configure chain for this window.
	// Use the returned builder to set changed fields, then call .send() or .sendHint().
	final WindowConfigurer configure()
	{
		return WindowConfigurer(this);
	}

	// Request that the client close this window.
	abstract void close();

	// Called by the conductor when the active WM's advertised capabilities change.
	void onWmCapabilitiesChanged(WmCapabilityFlags)
	{
	}

	override WaiSurface getSurface()
	{
		return null;
	}

protected:
	// Deliver a tracked configure to the protocol layer.
	// Called via WindowConfigurer.send(). The protocol layer queues it, sends the wire
	// configure, and notifies the conductor via onWindowConfigureApplied on ack+commit.
	abstract void deliverConfigure(ref WindowConfigureData data);

	// Deliver an untracked configure hint to the protocol layer.
	// Called via WindowConfigurer.sendHint(). Used for frequent size updates during
	// interactive resize where ack tracking is not needed.
	abstract void deliverResizeHint(ref WindowConfigureData data);
}
