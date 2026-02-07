// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.pointer_constraints.manager;

import trinove.pointer_constraints.constraint;
import trinove.pointer_constraints.locked;
import trinove.pointer_constraints.confined;
import trinove.math;
import trinove.seat;
import trinove.region : Region;
import trinove.surface.surface : WaiSurface;
import trinove.protocols.pointer_constraints_v1;
import wayland.server;
import wayland.native.server : wl_resource;

class WaiPointerConstraints : ZwpPointerConstraintsV1
{
	this(WlDisplay display)
	{
		super(display, ver);
	}

	override protected void destroy(WlClient cl, Resource res)
	{
	}

	override protected ZwpLockedPointerV1 lockPointer(WlClient cl, Resource res, uint id, WlResource surface,
			WlResource pointer, wl_resource* region, Lifetime lifetime)
	{
		auto waiSurface = cast(WaiSurface) surface;
		if (waiSurface is null)
		{
			res.postError(0, "Invalid surface");
			return null;
		}

		auto waiPointer = cast(WaiPointer) pointer;
		if (waiPointer is null || waiPointer.clientSeat is null)
		{
			res.postError(0, "Invalid pointer");
			return null;
		}

		auto seat = waiPointer.clientSeat.seat;
		if (seat.constraintFor(waiSurface) !is null)
		{
			res.postError(Error.alreadyConstrained, "Seat already has a pointer constraint on this surface");
			return null;
		}

		return new WaiLockedPointer(waiSurface, seat, Region.rectsFromRegionResource(region), lifetime, cl, id);
	}

	override protected ZwpConfinedPointerV1 confinePointer(WlClient cl, Resource res, uint id, WlResource surface,
			WlResource pointer, wl_resource* region, Lifetime lifetime)
	{
		auto waiSurface = cast(WaiSurface) surface;
		if (waiSurface is null)
		{
			res.postError(0, "Invalid surface");
			return null;
		}

		auto waiPointer = cast(WaiPointer) pointer;
		if (waiPointer is null || waiPointer.clientSeat is null)
		{
			res.postError(0, "Invalid pointer");
			return null;
		}

		auto seat = waiPointer.clientSeat.seat;
		if (seat.constraintFor(waiSurface) !is null)
		{
			res.postError(Error.alreadyConstrained, "Seat already has a pointer constraint on this surface");
			return null;
		}

		return new WaiConfinedPointer(waiSurface, seat, Region.rectsFromRegionResource(region), lifetime, cl, id);
	}
}
