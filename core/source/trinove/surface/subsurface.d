// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.surface.subsurface;

import wayland.server.protocol;
import trinove.util : onDestroyCallDestroy;
import wayland.server;
import trinove.surface.surface : WaiSurface, ResourceList;
import trinove.surface.role : ISurfaceRole;
import trinove.math;
import trinove.math.rect : Rect;
import trinove.damage : DamageList;
import trinove.log;
import std.algorithm : remove, countUntil;

final class WaiSubsurface : WlSubsurface, ISurfaceRole
{
	WaiSurface surface;
	WaiSurface parent;

	private Vector2I _pendingPosition;
	private Vector2I _currentPosition;
	private bool _syncMode = true;
	private bool _hasCachedState = false;
	private DamageList _cachedDamage = DamageList.init;
	private ResourceList _cachedFrameCallbacks;

	private enum ZOrderOp
	{
		none,
		placeAbove,
		placeBelow,
	}

	private ZOrderOp _pendingZOp = ZOrderOp.none;
	private WaiSurface _pendingZSibling;

	this(WaiSurface surface, WaiSurface parent, WlClient cl, uint id)
	{
		this.surface = surface;
		this.parent = parent;
		surface.role = this;
		surface.subsurfaceParent = parent;
		parent.addSubsurfaceChild(this);

		super(cl, WlSubsurface.ver, id);
		mixin(onDestroyCallDestroy);
	}

	// === ISurfaceRole ===

	void onDamage(Rect damage)
	{
		if (damage.width > 0 && damage.height > 0)
			_cachedDamage.add(damage);
	}

	void onDamageBuffer(Rect damage)
	{
		if (damage.width > 0 && damage.height > 0)
			_cachedDamage.add(damage);
	}

	void onCommit()
	{
		if (isEffectivelySync())
		{
			_cachedFrameCallbacks.takeAll(surface.pendingFrameCallbacks);
			_hasCachedState = true;
		}
		else
		{
			applyCachedState();
		}
	}

	void onSurfaceDestroyed()
	{
		// Handled by destroy()
	}

	bool isEffectivelySync()
	{
		if (_syncMode)
			return true;

		// If any ancestor subsurface is sync, we're effectively sync
		auto p = parent;
		while (p !is null)
		{
			auto parentSub = cast(WaiSubsurface) p.role;
			if (parentSub is null)
				break;
			if (parentSub._syncMode)
				return true;
			p = p.subsurfaceParent;
		}
		return false;
	}

	void parentCommitted()
	{
		_currentPosition = _pendingPosition;

		applyPendingZOrder();

		if (_hasCachedState)
			applyCachedState();

		if (surface !is null)
		{
			foreach (child; surface.subsurfaceChildren)
				child.parentCommitted();
		}
	}

	void onParentDestroyed()
	{
		parent = null;
		if (surface !is null)
			surface.subsurfaceParent = null;
	}

	// === WlSubsurface protocol requests ===

	override protected void destroy(WlClient cl)
	{
		if (parent !is null)
			parent.removeSubsurfaceChild(this);

		if (surface !is null)
		{
			surface.role = null;
			surface.subsurfaceParent = null;
		}

		_cachedDamage.release();

		if (surface !is null && surface.compositor !is null)
			surface.compositor.scheduleRepaint();

		parent = null;
		surface = null;
	}

	// Committed position relative to the parent surface, in surface-local coordinates.
	@property Vector2I position() const
	{
		return _currentPosition;
	}

	// Parent WaiSubsurface in the nesting hierarchy, or null if the parent surface is
	// a top-level (non-subsurface) surface.
	WaiSubsurface parentSubsurface()
	{
		if (surface is null || surface.subsurfaceParent is null)
			return null;
		return cast(WaiSubsurface) surface.subsurfaceParent.role;
	}

	override protected void setPosition(WlClient cl, int x, int y)
	{
		_pendingPosition = Vector2I(x, y);
	}

	override protected void placeAbove(WlClient cl, WlSurface sibling)
	{
		auto waiSibling = cast(WaiSurface) sibling;
		if (!isValidSibling(waiSibling))
		{
			postError(Error.badSurface, "Invalid sibling surface");
			return;
		}
		_pendingZOp = ZOrderOp.placeAbove;
		_pendingZSibling = waiSibling;
	}

	override protected void placeBelow(WlClient cl, WlSurface sibling)
	{
		auto waiSibling = cast(WaiSurface) sibling;
		if (!isValidSibling(waiSibling))
		{
			postError(Error.badSurface, "Invalid sibling surface");
			return;
		}
		_pendingZOp = ZOrderOp.placeBelow;
		_pendingZSibling = waiSibling;
	}

	override protected void setSync(WlClient cl)
	{
		_syncMode = true;
	}

	override protected void setDesync(WlClient cl)
	{
		_syncMode = false;

		if (!isEffectivelySync() && _hasCachedState)
			applyCachedState();
	}

	// === Internal helpers ===

	// Walk up to the topmost non-subsurface ancestor.
	private WaiSurface findRootSurface()
	{
		auto s = surface;
		while (s.subsurfaceParent !is null)
			s = s.subsurfaceParent;
		return s;
	}

	// Accumulate position offsets from this subsurface up to but not including
	// the root surface, giving the subsurface's position in root-surface-local coords.
	private Vector2I offsetToRoot()
	{
		Vector2I offset = _currentPosition;
		auto p = parent;
		while (p !is null && p.subsurfaceParent !is null)
		{
			auto ps = cast(WaiSubsurface) p.role;
			if (ps is null)
				break;
			offset += ps._currentPosition;
			p = ps.parent;
		}
		return offset;
	}

	private void applyCachedState()
	{
		_hasCachedState = false;

		if (surface is null)
			return;

		surface.frameCallbacks.takeAll(_cachedFrameCallbacks);

		// Propagate damage to root surface in root-local coordinates.
		auto root = findRootSurface();
		if (surface.currentBuffer !is null)
		{
			auto off = offsetToRoot();
			foreach (r; _cachedDamage.rects)
				root.rootLocalDamage.add(Rect(r.position.x + off.x, r.position.y + off.y, r.size.x, r.size.y));
		}

		_cachedDamage.clear();

		if (surface.compositor !is null)
			surface.compositor.scheduleRepaint();
	}

	private bool isValidSibling(WaiSurface sibling)
	{
		if (sibling is null)
			return false;
		if (sibling is parent)
			return true;
		foreach (child; parent.subsurfaceChildren)
		{
			if (child.surface is sibling && child !is this)
				return true;
		}
		return false;
	}

	private void applyPendingZOrder()
	{
		if (_pendingZOp == ZOrderOp.none)
			return;

		scope (exit)
		{
			_pendingZOp = ZOrderOp.none;
			_pendingZSibling = null;
		}

		reorderInSubsurfaceList();
	}

	// Reorder this subsurface in parent.subsurfaceChildren to match z-order.
	private void reorderInSubsurfaceList()
	{
		if (parent is null)
			return;

		parent.subsurfaceChildren = parent.subsurfaceChildren.remove!(c => c is this);

		if (_pendingZSibling is parent)
		{
			if (_pendingZOp == ZOrderOp.placeAbove)
				parent.subsurfaceChildren = [this] ~ parent.subsurfaceChildren;
			else
				parent.subsurfaceChildren = parent.subsurfaceChildren ~ this;
		}
		else
		{
			auto idx = parent.subsurfaceChildren.countUntil!(c => c.surface is _pendingZSibling);
			if (idx < 0)
			{
				parent.subsurfaceChildren ~= this;
				return;
			}

			auto insertAt = (_pendingZOp == ZOrderOp.placeAbove) ? idx + 1 : idx;
			parent.subsurfaceChildren = parent.subsurfaceChildren[0 .. insertAt] ~ this ~ parent.subsurfaceChildren[insertAt .. $];
		}
	}
}
