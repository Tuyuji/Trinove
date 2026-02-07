// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan
module trinove.shell.wm_base;

import trinove.protocols.xdg_shell;
import trinove.wm.conductor : WindowConductor;
import trinove.shell.surface;
import trinove.shell.positioner;
import trinove.surface;
import wayland.server;
import trinove.display_manager;

class WaiXdgWmBase : XdgWmBase
{
	WindowConductor conductor;

	this(WindowConductor conductor)
	{
		this.conductor = conductor;
		super(getDisplay(), XdgWmBase.ver);
	}

	override void destroy(WlClient cl, Resource res)
	{
		// Client is done with this xdg_wm_base
	}

	override XdgPositioner createPositioner(WlClient cl, Resource res, uint id)
	{
		return new WaiXdgPositioner(cl, id);
	}

	override XdgSurface getXdgSurface(WlClient cl, Resource res, uint id, WlResource surfaceRes)
	{
		auto surface = cast(WaiSurface) surfaceRes;
		if (surface is null)
		{
			res.postError(XdgWmBase.Error.role, "Invalid surface");
			return null;
		}

		if (surface.role !is null)
		{
			res.postError(XdgWmBase.Error.role, "Surface already has a role");
			return null;
		}

		return new WaiXdgSurface(this, res, surface, cl, id);
	}

	override void pong(WlClient cl, Resource res, uint serial)
	{
		// Client responded to ping
	}
}
