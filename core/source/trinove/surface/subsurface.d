// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.surface.subsurface;

import wayland.server.protocol;
import trinove.util : onDestroyCallDestroy;
import wayland.server;
import trinove.surface.surface : WaiSurface;
import trinove.surface.role : ISurfaceRole;
import trinove.math;
import trinove.math.rect : Rect;
import trinove.damage : DamageList;
import trinove.renderer.scene : RectNode, SceneNode;
import trinove.log;
import std.algorithm : remove, countUntil;

final class WaiSubsurface : WlSubsurface, ISurfaceRole
{
	WaiSurface surface;
	WaiSurface parent;

	// Container node that groups contentNode and any nested subsurface containers.
	// This is what gets reordered in the parent's container children.
	SceneNode containerNode;
	RectNode contentNode;

	private Vector2I _pendingPosition;
	private Vector2I _currentPosition;
	private bool _syncMode = true;
	private bool _hasCachedState = false;
	private DamageList _cachedDamage = DamageList.init;

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

		containerNode = new SceneNode();
		containerNode.visible = true;
		contentNode = new RectNode();
		contentNode.visible = false;
		containerNode.addChild(contentNode);

		// Attach to parent's container node in the scene graph
		auto parentNode = resolveParentContainerNode();
		if (parentNode !is null)
			parentNode.addChild(containerNode);

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
		containerNode.position = Vector2F(_currentPosition.x, _currentPosition.y);

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
		containerNode.visible = false;
		if (containerNode.parent !is null)
			containerNode.parent.removeChild(containerNode);
		parent = null;
		if (surface !is null)
			surface.subsurfaceParent = null;
	}

	// === WlSubsurface protocol requests ===

	override protected void destroy(WlClient cl)
	{
		if (containerNode.parent !is null)
			containerNode.parent.removeChild(containerNode);

		if (parent !is null)
			parent.removeSubsurfaceChild(this);

		if (surface !is null)
		{
			surface.role = null;
			surface.subsurfaceParent = null;
		}

		_cachedDamage.release();

		if (surface !is null && surface.compositor !is null)
			surface.compositor.scene.scheduleRepaint();

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

	private void applyCachedState()
	{
		_hasCachedState = false;

		if (surface is null)
			return;

		auto buf = surface.currentBuffer;
		if (buf !is null)
		{
			auto newTexture = buf.getITexture();
			if (contentNode.texture !is newTexture)
				contentNode.texture = newTexture;

			auto ss = surface.computeSurfaceState();
			contentNode.size = Vector2F(ss.size.x, ss.size.y);
			contentNode.srcRect = ss.srcRect;
			contentNode.uvTransform = ss.uvTransform;
			contentNode.visible = true;

			foreach (dmg; _cachedDamage.clampedTo(contentNode.localBounds()))
				contentNode.addDamage(dmg);

			contentNode.frameListener = surface;
		}
		else
		{
			contentNode.visible = false;
		}

		_cachedDamage.clear();

		if (surface.compositor !is null)
			surface.compositor.scene.scheduleRepaint();
	}

	// Resolve the parent surface's container SceneNode via its role chain.
	private SceneNode resolveParentContainerNode()
	{
		if (parent is null || parent.role is null)
			return null;

		import trinove.shell.surface : WaiXdgSurface;

		if (auto xdgSurf = cast(WaiXdgSurface) parent.role)
		{
			import trinove.shell.toplevel : WaiXdgToplevel;
			import trinove.shell.popup : WaiXdgPopup;

			if (auto tl = cast(WaiXdgToplevel) xdgSurf.xdgRole)
				return tl.window.containerNode;
			if (auto pop = cast(WaiXdgPopup) xdgSurf.xdgRole)
				return pop.popup.containerNode;
		}

		if (auto parentSub = cast(WaiSubsurface) parent.role)
			return parentSub.containerNode;

		return null;
	}

	// Resolve the parent surface's content RectNode (for z-order placement relative to parent)
	private SceneNode resolveParentContentNode()
	{
		if (parent is null || parent.role is null)
			return null;

		import trinove.shell.surface : WaiXdgSurface;

		if (auto xdgSurf = cast(WaiXdgSurface) parent.role)
		{
			import trinove.shell.toplevel : WaiXdgToplevel;
			import trinove.shell.popup : WaiXdgPopup;

			if (auto tl = cast(WaiXdgToplevel) xdgSurf.xdgRole)
				return tl.window.contentNode;
			if (auto pop = cast(WaiXdgPopup) xdgSurf.xdgRole)
				return pop.popup.contentNode;
		}

		if (auto parentSub = cast(WaiSubsurface) parent.role)
			return parentSub.contentNode;

		return null;
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

		auto parentContainer = containerNode.parent;
		if (parentContainer is null || parent is null)
			return;

		if (_pendingZSibling is parent)
		{
			// Place relative to the parent surface's content node.
			// The parent's containerNode holds: [subsurfaces_below..., contentNode, subsurfaces_above...]
			// "above parent" = just after contentNode, "below parent" = just before contentNode.
			auto parentContentNode = resolveParentContentNode();
			reorderInSceneChildren(parentContainer, _pendingZOp == ZOrderOp.placeAbove, parentContentNode);
		}
		else
		{
			// Find sibling subsurface
			WaiSubsurface sibSub;
			foreach (child; parent.subsurfaceChildren)
			{
				if (child.surface is _pendingZSibling)
				{
					sibSub = child;
					break;
				}
			}
			if (sibSub is null)
				return;

			reorderInSceneChildren(parentContainer, _pendingZOp == ZOrderOp.placeAbove, sibSub.containerNode);
		}

		// Also reorder in the subsurfaceChildren array to keep stacking consistent
		reorderInSubsurfaceList();
	}

	// Reorder this subsurface's containerNode relative to a sibling in the parent container's children.
	// siblingNode is either the parent's contentNode (for place relative to parent) or
	// another subsurface's containerNode (for place relative to sibling).
	private void reorderInSceneChildren(SceneNode parentContainer, bool above, SceneNode siblingNode)
	{
		parentContainer.children = parentContainer.children.remove!(c => c is containerNode);

		if (siblingNode is null)
		{
			// Fallback, just place at beginning
			parentContainer.children = [cast(SceneNode) containerNode] ~ parentContainer.children;
		}
		else
		{
			auto idx = parentContainer.children.countUntil!(c => c is siblingNode);
			if (idx < 0)
			{
				parentContainer.children ~= containerNode;
				return;
			}

			auto insertAt = above ? idx + 1 : idx;
			parentContainer.children = parentContainer.children[0 .. insertAt] ~ cast(
					SceneNode) containerNode ~ parentContainer.children[insertAt .. $];
		}
	}

	// Reorder this subsurface in parent.subsurfaceChildren to match scene graph order.
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
