// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan
module trinove.xdg_shell.surface;

import trinove.protocols.xdg_shell;
import trinove.xdg_shell.wm_base;
import trinove.xdg_shell.toplevel;
import trinove.xdg_shell.popup;
import trinove.xdg_shell.positioner;
import trinove.surface;
import trinove.math.rect;
import trinove.surface.role : ISurfaceRole, IXdgRole;
import trinove.display_manager : getDisplay;
import trinove.util : getResVersion, onDestroyCallDestroy;
import wayland.server;
import std.algorithm.comparison : min;

final class WaiXdgSurface : XdgSurface, ISurfaceRole
{
	WaiXdgWmBase wmBase;
	WaiSurface surface;

	IXdgRole xdgRole;

	uint pendingSerial;
	uint lastAckedSerial;
	bool configured;

	package Rect _pendingWindowGeometry;
	package bool _hasPendingWindowGeometry;
	// True once the client has called set_window_geometry at least once.
	package bool _hasExplicitWindowGeometry;

	WaiXdgToplevel toplevel()
	{
		return cast(WaiXdgToplevel) xdgRole;
	}

	WaiXdgPopup popup()
	{
		return cast(WaiXdgPopup) xdgRole;
	}

	this(WaiXdgWmBase wmBase, XdgWmBase.Resource wmBaseRes, WaiSurface surface, WlClient cl, uint id)
	{
		this.wmBase = wmBase;
		this.surface = surface;
		surface.role = this;

		auto ver = min(getResVersion(wmBaseRes), XdgSurface.ver);
		super(cl, ver, id);

		mixin(onDestroyCallDestroy);
	}

	void onDamage(Rect damage)
	{
	}

	void onDamageBuffer(Rect damage)
	{
	}

	void onCommit()
	{
		if (xdgRole !is null)
			xdgRole.onCommit();
	}

	void onSurfaceDestroyed()
	{
		// Handled by the destroy method
	}

	void sendConfigureEvent()
	{
		pendingSerial = getDisplay().nextSerial();
		sendConfigure(pendingSerial);
	}

	override XdgToplevel getToplevel(WlClient cl, uint id)
	{
		if (xdgRole !is null)
		{
			postError(XdgSurface.Error.alreadyConstructed, "xdg_surface already has a role");
			return null;
		}

		auto tl = new WaiXdgToplevel(this, cl, id);
		xdgRole = tl;

		// Send initial configure
		tl.sendConfigureEvent();

		return tl;
	}

	override void ackConfigure(WlClient cl, uint serial)
	{
		lastAckedSerial = serial;
		if (serial == pendingSerial)
			configured = true;

		// Notify role of the ack so it can match with pending config
		if (xdgRole !is null)
		{
			auto tl = toplevel;
			if (tl !is null && tl.window.tracingEnabled)
				tl.window.tracer.ack(serial);

			xdgRole.onAck(serial);
		}
	}

	override void destroy(WlClient cl)
	{
		if (xdgRole !is null)
			xdgRole.onXdgSurfaceDestroyed();

		if (surface)
			surface.role = null;
		surface = null;
	}

	override XdgPopup getPopup(WlClient cl, uint id, XdgSurface parent, XdgPositioner positioner)
	{
		if (xdgRole !is null)
		{
			postError(XdgSurface.Error.alreadyConstructed, "xdg_surface already has a role");
			return null;
		}

		auto parentSurface = cast(WaiXdgSurface) parent;
		auto pos = cast(WaiXdgPositioner) positioner;

		if (parentSurface is null)
		{
			postError(XdgWmBase.Error.invalidPopupParent, "Invalid popup parent");
			return null;
		}

		if (pos is null || pos.size.x == 0 || pos.size.y == 0)
		{
			postError(XdgWmBase.Error.invalidPositioner, "Invalid or incomplete positioner");
			return null;
		}

		auto pop = new WaiXdgPopup(this, parentSurface, pos, cl, id);
		xdgRole = pop;

		// Send initial configure
		pop.sendConfigureEvent();

		return pop;
	}

	override void setWindowGeometry(WlClient cl, int x, int y, int width, int height)
	{
		if (xdgRole is null)
		{
			import trinove.log : logWarn;

			logWarn("set_window_geometry called before role assignment (protocol violation)");
			postError(XdgSurface.Error.notConstructed, "set_window_geometry requires a role to be assigned first");
			return;
		}

		_pendingWindowGeometry = Rect(x, y, cast(uint) width, cast(uint) height);
		_hasPendingWindowGeometry = true;
		_hasExplicitWindowGeometry = true;
	}
}
