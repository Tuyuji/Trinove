// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.xdg_shell.popup;

import trinove.protocols.xdg_shell;
import trinove.xdg_shell.surface;
import trinove.xdg_shell.positioner;
import trinove.xdg_shell.toplevel;
import trinove.xdg_shell.pending_config;
import trinove.math;
import trinove.wm.popup;
import trinove.wm.window;
import trinove.seat : Seat;
import trinove.log;
import trinove.util : getResVersion, onDestroyCallDestroy;
import wayland.server;
import trinove.surface.role : IXdgRole;
import trinove.debug_.protocol_tracer : traceEnter, Actor;
import std.algorithm.comparison : min;
import std.format : format;

final class WaiXdgPopup : XdgPopup, IXdgRole
{
	WaiXdgSurface xdgSurface;
	WaiXdgSurface parentXdgSurface;

	// The logical popup managed by WindowManager
	Popup popup;

	struct PendingState
	{
		Vector2I position;
		Vector2U size;
		uint repositionToken; // 0 for initial configure, non-zero for reposition
	}

	PendingConfigQueue!PendingState pendingConfigs;

	this(WaiXdgSurface xdgSurface, WaiXdgSurface parent, WaiXdgPositioner positioner, WlClient cl, uint id)
	{
		this.xdgSurface = xdgSurface;
		this.parentXdgSurface = parent;

		popup = new Popup();
		popup.protocol = this;
		popup.position = positioner.calculatePosition();
		popup.surfaceSize = positioner.size;

		auto ver = min(getResVersion(xdgSurface), XdgPopup.ver);
		super(cl, ver, id);

		mixin(onDestroyCallDestroy);
	}

	// Resolve popup.parentWindow / popup.parentPopup from parentXdgSurface.
	// Returns true if the parent is ready (mapped), false if we should defer.
	private bool resolveParent()
	{
		if (parentXdgSurface is null)
			return false;

		if (parentXdgSurface.toplevel !is null)
		{
			auto toplevel = cast(WaiXdgToplevel) parentXdgSurface.toplevel;
			if (toplevel && toplevel.window && toplevel.window.mapped)
			{
				popup.parentWindow = toplevel.window;
				popup.parentPopup = null;
				return true;
			}
		}
		else if (parentXdgSurface.popup !is null)
		{
			auto parentProto = cast(WaiXdgPopup) parentXdgSurface.popup;
			if (parentProto && parentProto.popup && parentProto.popup.parentWindow !is null)
			{
				popup.parentWindow = parentProto.popup.parentWindow;
				popup.parentPopup = parentProto.popup;
				return true;
			}
		}

		return false;
	}

	void onCommit()
	{
		if (xdgSurface is null || xdgSurface.surface is null)
			return;

		auto surface = xdgSurface.surface;

		if (surface.currentBuffer)
		{
			auto sz = surface.computeSurfaceState().size;

			// Commit pending window geometry, or default to full surface if the client
			// has never called set_window_geometry.
			if (xdgSurface._hasPendingWindowGeometry)
			{
				popup.setClientBounds(xdgSurface._pendingWindowGeometry);
				xdgSurface._hasPendingWindowGeometry = false;
			}
			else if (!xdgSurface._hasExplicitWindowGeometry)
			{
				popup.setClientBounds(Rect(0, 0, sz.x, sz.y));
			}

			if (pendingConfigs.hasAcked())
			{
				auto cfg = pendingConfigs.getAckedData();

				// Apply the acked position/size
				popup.position = cfg.position;
				popup.surfaceSize = cfg.size;

				if (!popup.mapped)
				{
					if (!resolveParent())
						return;

					xdgSurface.wmBase.conductor.addPopup(popup);
				}

				pendingConfigs.clearAcked();
			}
			else if (!popup.mapped)
			{
				if (!resolveParent())
					return;

				popup.surfaceSize = sz;
				xdgSurface.wmBase.conductor.addPopup(popup);
			}
			else if (sz != popup.surfaceSize)
			{
				popup.surfaceSize = sz;
			}

			if (xdgSurface.wmBase && xdgSurface.wmBase.conductor)
				xdgSurface.wmBase.conductor.scheduleRepaint();
		}
	}

	void sendConfigureEvent()
	{
		auto _t = traceEnter(popup.parentWindow, Actor.Popup, format("configure(%d,%d %dx%d)", popup.position.x,
				popup.position.y, popup.surfaceSize.x, popup.surfaceSize.y), Actor.WM);
		sendConfigure(popup.position.x, popup.position.y, popup.surfaceSize.x, popup.surfaceSize.y);
		xdgSurface.sendConfigureEvent();

		pendingConfigs.add(xdgSurface.pendingSerial, PendingState(popup.position, popup.surfaceSize, 0 // Not a reposition
				));
	}

	void onAck(uint serial)
	{
		auto _t = traceEnter(popup.parentWindow, Actor.Popup, format("ack_configure(%d)", serial), Actor.Client);
		pendingConfigs.ack(serial);
	}

	// Dismiss this popup (sends popup_done to client and removes from WM immediately)
	void dismiss()
	{
		// Dismiss children first.
		if (popup.childPopup !is null)
		{
			auto childProto = cast(WaiXdgPopup) popup.childPopup.protocol;
			if (childProto)
				childProto.dismiss();
		}

		if (popup.mapped)
		{
			xdgSurface.wmBase.conductor.removePopup(popup);
		}

		sendPopupDone();
	}

	override void onXdgSurfaceDestroyed()
	{
	}

	override void destroy(WlClient cl)
	{
		auto _t = traceEnter(popup.parentWindow, Actor.Popup, "destroy", Actor.Client);

		// Check topmost requirement
		if (popup.childPopup !is null)
		{
			xdgSurface.postError(XdgWmBase.Error.notTheTopmostPopup, "Cannot destroy popup that is not topmost");
			return;
		}

		if (popup.mapped)
		{
			xdgSurface.wmBase.conductor.removePopup(popup);
		}

		if (xdgSurface)
			xdgSurface.xdgRole = null;
	}

	override void grab(WlClient cl, WlResource seatRes, uint serial)
	{
		auto _t = traceEnter(popup.parentWindow, Actor.Popup, format("grab(serial=%d)", serial), Actor.Client);

		auto wseat = xdgSurface.wmBase.conductor.seatManager.findSeatForResource(seatRes);

		// Nested popup grab: parent popup must already have an active grab from the same seat.
		if (parentXdgSurface !is null && parentXdgSurface.popup !is null)
		{
			auto parentProto = cast(WaiXdgPopup) parentXdgSurface.popup;
			if (parentProto is null || parentProto.popup.grabbedSeat !is wseat)
			{
				logDebug("popup.grab: parent popup has no grab for this seat, dismissing");
				dismiss();
				return;
			}
		}

		if (!wseat.isValidGrabSerial(cl, serial))
			logDebug("popup.grab: invalid serial %d (lenient mode - allowing)", serial);

		popup.grabbedSeat = wseat;
	}

	override void reposition(WlClient cl, XdgPositioner positioner, uint token)
	{
		auto pos = cast(WaiXdgPositioner) positioner;
		if (pos is null)
			return;

		auto newPosition = pos.calculatePosition();
		auto newSize = pos.size;

		auto _t = traceEnter(popup.parentWindow, Actor.Popup, format("reposition(token=%d, %d,%d %dx%d)", token,
				newPosition.x, newPosition.y, newSize.x, newSize.y), Actor.Client);

		// Send repositioned event with token, then configure
		sendRepositioned(token);
		sendConfigure(newPosition.x, newPosition.y, newSize.x, newSize.y);
		xdgSurface.sendConfigureEvent();

		// Track pending state, position/size will be applied after ack+commit
		pendingConfigs.add(xdgSurface.pendingSerial, PendingState(newPosition, newSize, token));
	}
}
