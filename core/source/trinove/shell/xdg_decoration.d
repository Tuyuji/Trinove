// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.shell.xdg_decoration;

import trinove.protocols.xdg_decoration_v1;
import trinove.shell.toplevel : WaiXdgToplevel;
import trinove.surface.surface : WaiSurface;
import trinove.surface.role : ISurfaceExtension;
import trinove.wm.conductor : WindowConductor;
import trinove.util : onDestroyCallDestroy;
import trinove.display_manager : getDisplay;
import trinove.log;
import wayland.server;

class WaiXdgDecorationManager : ZxdgDecorationManagerV1
{
    private WindowConductor _conductor;

    this(WlDisplay display, WindowConductor conductor)
    {
        super(display, ver);
        _conductor = conductor;
    }

    override protected void destroy(WlClient cl, Resource res) {}

    override protected ZxdgToplevelDecorationV1 getToplevelDecoration(
        WlClient cl, Resource res, uint id, WlResource toplevelRes)
    {
        auto toplevel = cast(WaiXdgToplevel) toplevelRes;
        if (toplevel is null || toplevel.xdgSurface is null || toplevel.xdgSurface.surface is null)
        {
            res.postError(0, "Invalid xdg_toplevel");
            return null;
        }

        // Check for an existing decoration on this surface.
        foreach (ext; toplevel.xdgSurface.surface.extensions)
        {
            if (cast(WaiXdgToplevelDecoration) ext !is null)
            {
                res.postError(cast(uint) ZxdgToplevelDecorationV1.Error.alreadyConstructed,
                    "xdg_toplevel already has a decoration object");
                return null;
            }
        }

        return new WaiXdgToplevelDecoration(_conductor, toplevel, cl, id);
    }
}

final class WaiXdgToplevelDecoration : ZxdgToplevelDecorationV1, ISurfaceExtension
{
    private WindowConductor _conductor;
    private WaiXdgToplevel _toplevel;
    private WaiSurface _surface;

    this(WindowConductor conductor, WaiXdgToplevel toplevel, WlClient cl, uint id)
    {
        super(cl, ver, id);
        _conductor = conductor;
        _toplevel = toplevel;
        _surface = toplevel.xdgSurface.surface;

        _surface.addExtension(this);

        mixin(onDestroyCallDestroy);
        toplevel.window.configure().send();
    }

    override void onCommit() {}

    override void onSurfaceDestroyed()
    {
        if (_toplevel !is null)
            _conductor.notifyDecorationPreference(_toplevel.window, false);
        _toplevel = null;
        _surface  = null;
    }

    override void onPreConfigure()
    {
        if (_toplevel is null)
            return;
        auto mode = _toplevel.window.state.serverDecorations ? Mode.serverSide : Mode.clientSide;
        sendConfigure(mode);
    }

    override protected void destroy(WlClient cl)
    {
        if (_surface !is null)
        {
            _surface.removeExtension(this);
            _surface = null;
        }
        if (_toplevel !is null)
        {
            _conductor.notifyDecorationPreference(_toplevel.window, false);
            _toplevel = null;
        }
    }

    override protected void setMode(WlClient cl, Mode mode)
    {
        if (_toplevel is null) return;

        bool preferSsd = (mode == Mode.serverSide);
        _conductor.notifyDecorationPreference(_toplevel.window, preferSsd);

        _toplevel.window.configure().send();
    }

    override protected void unsetMode(WlClient cl)
    {
        if (_toplevel is null) return;
        _conductor.notifyDecorationPreference(_toplevel.window, true);
        _toplevel.window.configure().send();
    }
}
