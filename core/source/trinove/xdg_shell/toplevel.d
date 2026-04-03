// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan
module trinove.xdg_shell.toplevel;

import trinove.protocols.xdg_shell;
import trinove.xdg_shell.surface;
import trinove.xdg_shell.pending_config;
import trinove.math;
import wayland.server;
import trinove.wm;
import trinove.seat;
import trinove.display_manager;
import trinove.log;
import trinove.util : wlArrayAdd, getResVersion, onDestroyCallDestroy;
import std.algorithm.comparison : min;
import trinove.debug_.protocol_tracer : traceEnter, Actor;
import std.format : format;
import wayland.native.util : wl_array, wl_array_init;
import trinove.surface.role : IXdgRole;
import trinove.surface.surface : WaiSurface;
import trinove.layer : Layer;
import std.typecons : Nullable;

final class XdgToplevelWindow : Window
{
	private WaiXdgToplevel _protocol;
	private PendingConfigQueue!WindowConfigureData _configQueue;
	private WindowConfigureData _ackedFolded;
	private bool _addedToWc;

	this(WaiXdgToplevel protocol)
	{
		_protocol = protocol;
	}

	override WaiSurface getSurface()
	{
		if (_protocol !is null && _protocol.xdgSurface !is null)
			return _protocol.xdgSurface.surface;
		return null;
	}

	override void close()
	{
		_protocol.sendClose();
	}

	override void onWmCapabilitiesChanged(WmCapabilityFlags caps)
	{
		if (_protocol is null)
			return;
		if (getResVersion(_protocol) < XdgToplevel.wmCapabilitiesSinceVersion)
			return;

		wl_array arr;
		wl_array_init(&arr);
		if (caps & WmCapabilityFlags.windowMenu)
			wlArrayAdd(&arr, XdgToplevel.WmCapabilities.windowMenu);
		if (caps & WmCapabilityFlags.maximize)
			wlArrayAdd(&arr, XdgToplevel.WmCapabilities.maximize);
		if (caps & WmCapabilityFlags.fullscreen)
			wlArrayAdd(&arr, XdgToplevel.WmCapabilities.fullscreen);
		if (caps & WmCapabilityFlags.minimize)
			wlArrayAdd(&arr, XdgToplevel.WmCapabilities.minimize);
		_protocol.sendWmCapabilities(&arr);

		if (_addedToWc)
			configure().send();
	}

	override protected void deliverConfigure(ref WindowConfigureData data)
	{
		if (!data.maximized.isNull)
			pendingState.maximized = data.maximized.get;
		if (!data.fullscreen.isNull)
			pendingState.fullscreen = data.fullscreen.get;

		// Resolve effective absolute state for the wire configure.
		// Peek at the last queued delta to carry forward any in-flight changes.
		WindowConfigureData last;
		if (_configQueue.peekLastData(last))
			last.mergeFrom(data);
		else
			last = data;

		auto maximized = last.maximized.isNull ? state.maximized : last.maximized.get;
		auto fullscreen = last.fullscreen.isNull ? state.fullscreen : last.fullscreen.get;
		auto sz = last.size.isNull ? surfaceSize : last.size.get;

		_protocol.sendConfigureWire(sz, maximized, fullscreen);
		_configQueue.add(_protocol.xdgSurface.pendingSerial, data);
	}

	override protected void deliverResizeHint(ref WindowConfigureData data)
	{
		WindowConfigureData last;
		if (!_configQueue.peekLastData(last))
			last = WindowConfigureData.init;

		auto maximized = last.maximized.isNull ? state.maximized : last.maximized.get;
		auto fullscreen = last.fullscreen.isNull ? state.fullscreen : last.fullscreen.get;
		auto sz = data.size.isNull ? surfaceSize : data.size.get;

		_protocol.sendConfigureSizeWithState(sz.x, sz.y, maximized, fullscreen);
	}

	package void sendInitialConfigure()
	{
		_protocol.sendConfigureWire(Vector2U(0, 0), false, false);
		_configQueue.add(_protocol.xdgSurface.pendingSerial, WindowConfigureData.init);
	}

	// Called by WaiXdgToplevel when the client sends ack_configure.
	package void onAck(uint serial)
	{
		_ackedFolded = WindowConfigureData.init;
		_configQueue.foldAndAck(serial, (ref const WindowConfigureData delta) { _ackedFolded.mergeFrom(delta); });
	}

	// Handle the configure lifecycle portion of a commit.
	//
	// Returns false if the window is not yet ready to map (waiting on the initial ack).
	// Otherwise applies any acked state and notifies the conductor.
	package bool handleCommit(Vector2U newSize)
	{
		auto wm = _protocol.xdgSurface.wmBase.conductor;

		if (!_addedToWc)
		{
			if (!_configQueue.hasAcked())
				return false;

			_configQueue.clearAcked();
			surfaceSize = newSize;
			mapped = true;
			_addedToWc = true;

			wm.addWindow(this);
			wm.notifyWindowConfigureApplied(this, Nullable!Vector2I.init);
			return true;
		}

		if (_configQueue.hasAcked())
		{
			auto _t = traceEnter(this, Actor.Toplevel, "handleCommit(ack'ed)", Actor.Surface);

			auto folded = _ackedFolded;
			_configQueue.clearAcked();

			surfaceSize = newSize;

			if (tracingEnabled)
				tracer.commitToToplevel(newSize.x, newSize.y, true);

			if (!folded.maximized.isNull)
				state.maximized = folded.maximized.get;

			if (!folded.fullscreen.isNull)
			{
				state.fullscreen = folded.fullscreen.get;
				wm.setLayer(this, folded.fullscreen.get ? Layer.Fullscreen : Layer.Normal);
			}

			wm.notifyWindowConfigureApplied(this, folded.position);
		}
		else if (newSize != surfaceSize)
		{
			// Client committed a new size during interactive resize without an acked configure.
			wm.notifyWindowResizeCommitted(this, newSize);
		}

		return true;
	}
}

final class WaiXdgToplevel : XdgToplevel, IXdgRole
{
	WaiXdgSurface xdgSurface;
	XdgToplevelWindow window;

	this(WaiXdgSurface xdgSurface, WlClient cl, uint id)
	{
		this.xdgSurface = xdgSurface;

		window = new XdgToplevelWindow(this);
		window.protocol = this;

		auto ver = min(getResVersion(xdgSurface), XdgToplevel.ver);
		super(cl, ver, id);

		mixin(onDestroyCallDestroy);

		// Send wm_capabilities to client (version check is done inside onWmCapabilitiesChanged)
		auto conductor = xdgSurface.wmBase.conductor;
		window.onWmCapabilitiesChanged(conductor.wmCapabilities);
	}

	void sendConfigureEvent()
	{
		window.sendInitialConfigure();
	}

	override void onCommit()
	{
		auto surface = xdgSurface.surface;
		if (surface is null)
			return;

		if (!surface.currentBuffer)
			return;

		auto newSize = surface.computeSurfaceState().size;

		// Commit pending window geometry, or default to full surface if the client
		// has never called set_window_geometry.
		if (xdgSurface._hasPendingWindowGeometry)
		{
			window.setClientBounds(xdgSurface._pendingWindowGeometry);
			xdgSurface._hasPendingWindowGeometry = false;
		}
		else if (!xdgSurface._hasExplicitWindowGeometry)
		{
			window.setClientBounds(Rect(0, 0, newSize.x, newSize.y));
		}

		if (!window.handleCommit(newSize))
			return;

		// Schedule a repaint if we have surface damage
		if (!surface.rootLocalDamage.empty)
			xdgSurface.wmBase.conductor.scheduleRepaint();
	}

	override void onAck(uint serial)
	{
		window.onAck(serial);
	}

	override void onXdgSurfaceDestroyed()
	{
	}

	override void destroy(WlClient cl)
	{
		auto wm = xdgSurface.wmBase.conductor;
		wm.removeWindow(window);
		xdgSurface.xdgRole = null;
	}

	override void setParent(WlClient cl, XdgToplevel parent)
	{
		Window parentWindow = null;

		if (parent !is null)
		{
			auto parentToplevel = cast(WaiXdgToplevel) parent;
			if (parentToplevel !is null && parentToplevel.window !is null && parentToplevel.window.mapped)
			{
				parentWindow = parentToplevel.window;
			}
			// Unmapped parent is treated as null per spec
		}

		if (parentWindow !is null)
		{
			// Reject if parent is self or a descendant of this window
			auto w = parentWindow;
			while (w !is null)
			{
				if (w is window)
				{
					postError(XdgToplevel.Error.invalidParent, "parent must not be the surface itself or one of its descendants");
					return;
				}
				w = w.parentWindow;
			}
		}

		auto wm = xdgSurface.wmBase.conductor;
		wm.setWindowParent(window, parentWindow);
	}

	override void setTitle(WlClient cl, string t)
	{
		window.title = t;
		if (window.mapped)
			xdgSurface.wmBase.conductor.notifyWindowTitleChanged(window);
	}

	override void setAppId(WlClient cl, string id)
	{
		window.appId = id;
	}

	override void showWindowMenu(WlClient cl, WlResource seat, uint serial, int x, int y)
	{
		auto _t = traceEnter(window, Actor.Toplevel, format("showWindowMenu(serial=%d, %d, %d)", serial, x, y), Actor
				.Client);

		auto wseat = findSeatForResource(seat);
		if (wseat is null)
			return;

		if (!wseat.isValidMoveResizeSerial(cl, serial))
			logDebug("showWindowMenu: invalid serial %d (lenient mode, allowing)", serial);

		auto wm = xdgSurface.wmBase.conductor;
		wm.requestShowWindowMenu(wseat, window, Vector2I(x, y));
	}

	override void move(WlClient cl, WlResource seatRes, uint serial)
	{
		auto _t = traceEnter(window, Actor.Toplevel, format("move(serial=%d)", serial), Actor.Client);

		auto wseat = findSeatForResource(seatRes);
		if (wseat is null)
			return;

		if (!wseat.isValidMoveResizeSerial(cl, serial))
			logDebug("move: invalid serial %d (lenient mode, allowing)", serial);

		auto wm = xdgSurface.wmBase.conductor;
		wm.requestMove(wseat, window);
	}

	override void resize(WlClient cl, WlResource seatRes, uint serial, ResizeEdge edges)
	{
		auto _t = traceEnter(window, Actor.Toplevel, format("resize(serial=%d, %s)", serial, edges), Actor.Client);

		auto wseat = findSeatForResource(seatRes);
		if (wseat is null)
			return;

		if (!wseat.isValidMoveResizeSerial(cl, serial))
			logDebug("resize: invalid serial %d (lenient mode, allowing)", serial);

		auto wm = xdgSurface.wmBase.conductor;
		wm.requestResize(wseat, window, xdgEdgeToDecorationHit(edges));
	}

	override void setMaxSize(WlClient cl, int width, int height)
	{
		auto _t = traceEnter(window, Actor.Toplevel, format("setMaxSize(%d, %d)", width, height), Actor.Client);
		window.maxSize = Vector2U(cast(uint) width, cast(uint) height);
	}

	override void setMinSize(WlClient cl, int width, int height)
	{
		auto _t = traceEnter(window, Actor.Toplevel, format("setMinSize(%d, %d)", width, height), Actor.Client);
		window.minSize = Vector2U(cast(uint) width, cast(uint) height);
	}

	override void setMaximized(WlClient cl)
	{
		auto _t = traceEnter(window, Actor.Toplevel, "setMaximized", Actor.Client);
		auto wm = xdgSurface.wmBase.conductor;
		wm.requestMaximize(window);
	}

	override void unsetMaximized(WlClient cl)
	{
		auto _t = traceEnter(window, Actor.Toplevel, "unsetMaximized", Actor.Client);
		auto wm = xdgSurface.wmBase.conductor;
		wm.requestUnmaximize(window);
	}

	override void setFullscreen(WlClient cl, WlResource output)
	{
		auto _t = traceEnter(window, Actor.Toplevel, "setFullscreen", Actor.Client);
		auto wm = xdgSurface.wmBase.conductor;
		wm.requestFullscreen(window);
	}

	override void unsetFullscreen(WlClient cl)
	{
		auto _t = traceEnter(window, Actor.Toplevel, "unsetFullscreen", Actor.Client);
		auto wm = xdgSurface.wmBase.conductor;
		wm.requestUnfullscreen(window);
	}

	override void setMinimized(WlClient cl)
	{
		auto _t = traceEnter(window, Actor.Toplevel, "setMinimized", Actor.Client);
		auto wm = xdgSurface.wmBase.conductor;
		wm.requestMinimize(window);
	}

	private Seat findSeatForResource(WlResource seatRes)
	{
		return xdgSurface.wmBase.conductor.seatManager.findSeatForResource(seatRes);
	}

	private DecorationHit xdgEdgeToDecorationHit(ResizeEdge edges)
	{
		final switch (edges)
		{
		case ResizeEdge.none:
			return DecorationHit.None;
		case ResizeEdge.top:
			return DecorationHit.ResizeTop;
		case ResizeEdge.bottom:
			return DecorationHit.ResizeBottom;
		case ResizeEdge.left:
			return DecorationHit.ResizeLeft;
		case ResizeEdge.right:
			return DecorationHit.ResizeRight;
		case ResizeEdge.topLeft:
			return DecorationHit.ResizeTopLeft;
		case ResizeEdge.topRight:
			return DecorationHit.ResizeTopRight;
		case ResizeEdge.bottomLeft:
			return DecorationHit.ResizeBottomLeft;
		case ResizeEdge.bottomRight:
			return DecorationHit.ResizeBottomRight;
		}
	}

	private void sendConfigureWire(Vector2U sz, bool maximized, bool fullscreen)
	{
		auto _t = traceEnter(window, Actor.Toplevel, "sendConfigureWire");
		wl_array states;
		wl_array_init(&states);

		if (window.state.resizing)
		{
			wlArrayAdd(&states, State.resizing);
		}
		if (window.state.focused)
		{
			wlArrayAdd(&states, State.activated);
		}
		if (maximized)
		{
			wlArrayAdd(&states, State.maximized);
		}
		if (fullscreen)
		{
			wlArrayAdd(&states, State.fullscreen);
		}

		sendConfigure(cast(int) sz.x, cast(int) sz.y, &states);

		if (xdgSurface.surface !is null)
		{
			foreach (ext; xdgSurface.surface.extensions)
				ext.onPreConfigure();
		}

		xdgSurface.sendConfigureEvent();

		if (window.tracingEnabled)
		{
			string[] stateNames;
			if (maximized)
			{
				stateNames ~= "maximized";
			}
			if (fullscreen)
			{
				stateNames ~= "fullscreen";
			}
			if (window.state.resizing)
			{
				stateNames ~= "resizing";
			}
			if (window.state.focused)
			{
				stateNames ~= "activated";
			}
			window.tracer.configureState(xdgSurface.pendingSerial, sz.x, sz.y, stateNames);
		}
	}

	// Send an untracked configure. For resize hints only.
	private void sendConfigureSizeWithState(uint width, uint height, bool maximized, bool fullscreen)
	{
		wl_array states;
		wl_array_init(&states);

		if (window.state.resizing)
		{
			wlArrayAdd(&states, State.resizing);
		}
		if (window.state.focused)
		{
			wlArrayAdd(&states, State.activated);
		}
		if (maximized)
		{
			wlArrayAdd(&states, State.maximized);
		}
		if (fullscreen)
		{
			wlArrayAdd(&states, State.fullscreen);
		}

		sendConfigure(cast(int) width, cast(int) height, &states);
		xdgSurface.sendConfigureEvent();

		if (window.tracingEnabled)
		{
			string[] stateNames;
			if (maximized)
			{
				stateNames ~= "maximized";
			}
			if (fullscreen)
			{
				stateNames ~= "fullscreen";
			}
			if (window.state.resizing)
			{
				stateNames ~= "resizing";
			}
			if (window.state.focused)
			{
				stateNames ~= "activated";
			}
			window.tracer.configureState(xdgSurface.pendingSerial, width, height, stateNames);
		}
	}
}
