// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.pointer_constraints.locked;

import trinove.pointer_constraints.constraint;
import trinove.math;
import trinove.seat;
import trinove.region : Region;
import trinove.surface.surface : WaiSurface;
import trinove.surface.role : ISurfaceExtension;
import trinove.protocols.pointer_constraints_v1;
import trinove.util : onDestroyCallDestroy;
import wayland.server;
import wayland.native.server : wl_resource;
import wayland.util : WlFixed;

class WaiLockedPointer : ZwpLockedPointerV1, ISurfaceExtension
{
	private WaiSurface _surface;
	private Seat _seat;
	private PointerConstraint _constraint;

	// Pending double-buffered state
	private Rect[] _pendingRegion;
	private bool _pendingRegionDirty;
	private WlFixed _pendingCursorHintX;
	private WlFixed _pendingCursorHintY;
	private bool _pendingCursorHintDirty;

	this(WaiSurface surface, Seat seat, Rect[] region, Lifetime lifetime, WlClient cl, uint id)
	{
		super(cl, ver, id);
		_surface = surface;
		_seat = seat;

		_constraint = new PointerConstraint();
		_constraint.type = ConstraintType.lock;
		_constraint.lifetime = lifetime;
		_constraint.region = region;
		_constraint.onActivated = &this.sendLocked;
		_constraint.onDeactivated = &this.sendUnlocked;
		surface.addExtension(this);
		seat.attachConstraint(surface, _constraint);

		mixin(onDestroyCallDestroy);
	}

	// Apply pending double-buffered state on commit.
	void onCommit()
	{
		if (_constraint is null)
			return;

		if (_pendingRegionDirty)
		{
			_constraint.region = _pendingRegion;
			_pendingRegion = null;
			_pendingRegionDirty = false;
		}

		if (_pendingCursorHintDirty)
		{
			_constraint.cursorHintX = _pendingCursorHintX;
			_constraint.cursorHintY = _pendingCursorHintY;
			_constraint.hasCursorHint = true;
			_pendingCursorHintDirty = false;
		}
	}

	void onSurfaceDestroyed()
	{
		if (_surface !is null && _seat !is null)
			_seat.detachConstraint(_surface);
		_surface = null;
		_seat = null;
		_constraint = null;
	}

	void onPreConfigure() {}

	override protected void destroy(WlClient cl)
	{
		if (_surface !is null)
		{
			if (_seat !is null)
				_seat.detachConstraint(_surface);
			_surface.removeExtension(this);
		}
		_surface = null;
		_seat = null;
		_constraint = null;
	}

	override protected void setCursorPositionHint(WlClient cl, WlFixed surfaceX, WlFixed surfaceY)
	{
		_pendingCursorHintX = surfaceX;
		_pendingCursorHintY = surfaceY;
		_pendingCursorHintDirty = true;
	}

	override protected void setRegion(WlClient cl, wl_resource* region)
	{
		_pendingRegion = Region.rectsFromRegionResource(region);
		_pendingRegionDirty = true;
	}
}
