// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.relative_pointer;

import trinove.protocols.relative_pointer_v1;
import trinove.seat;
import trinove.log;
import trinove.util : onDestroyCallDestroy;
import wayland.server;
import wayland.util : WlFixed;
import std.algorithm : remove;

class WaiRelativePointerManager : ZwpRelativePointerManagerV1
{
	this(WlDisplay display)
	{
		super(display, ver);
	}

	override protected void destroy(WlClient cl, Resource res)
	{

	}

	override protected ZwpRelativePointerV1 getRelativePointer(WlClient cl, Resource res, uint id, WlResource pointer)
	{
		auto waiPointer = cast(WaiPointer) pointer;
		if (waiPointer is null || waiPointer.clientSeat is null || waiPointer.clientSeat.state is null)
		{
			res.postError(0, "Invalid pointer");
			return null;
		}

		auto relPtr = new WaiRelativePointer(waiPointer.clientSeat, cl, id);
		waiPointer.clientSeat.state.relativePointers ~= relPtr;
		return relPtr;
	}
}

class WaiRelativePointer : ZwpRelativePointerV1
{
	Seat.WaiClientSeat clientSeat;

	this(Seat.WaiClientSeat clientSeat, WlClient cl, uint id)
	{
		this.clientSeat = clientSeat;
		super(cl, ver, id);

		mixin(onDestroyCallDestroy);
	}

	override protected void destroy(WlClient cl)
	{
		if (clientSeat !is null && clientSeat.seat !is null)
			clientSeat.seat.removeRelativePointer(this);
		clientSeat = null;
	}
}
