// SPDX-License-Identifier: GPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.surface.surface;

import trinove.compositor;
import trinove.surface.buffer;
import trinove.surface.role : ISurfaceRole, ISurfaceExtension;
import trinove.surface.cursor_role : CursorRole;
import trinove.surface.subsurface : WaiSubsurface;
import trinove.math : Vector2I, Vector2U;
import trinove.math.rect : Rect;
import trinove.damage : DamageList;
import trinove.renderer.canvas : BufferTransform;
import trinove.subsystem : Services;
import trinove.util : onDestroyCallDestroy;
import trinove.log;
import wayland.server.protocol;
import wayland.server;
import wayland.native.server;
import wayland.native.util;
import wayland.util : ObjectCache;
import core.time : MonoTime;
import std.algorithm : remove;

enum InputRegionMode : ubyte
{
	infinite, // Whole surface accepts input (default, or set_input_region(null))
	passThrough, // Empty region. No point accepted, input falls through to surface below
	explicit, // Explicit region with rects. Check inputRegion for hit
}

final class WaiSurface : WlSurface
{
	TrinoveCompositor compositor;

	//Pending state
	struct
	{
		IWaylandBuffer pendingBuffer;
		bool pendingBufferAttached;
		ResourceList pendingFrameCallbacks;
		Region pendingInputRegion;
		bool pendingInputRegionReset;
	}

	IWaylandBuffer currentBuffer;
	InputRegionMode inputRegionMode = InputRegionMode.infinite;
	Rect[] inputRegion;
	ResourceList frameCallbacks;

	ISurfaceRole role;

	// Protocol extensions (viewporter, pointer constraints, etc...)
	ISurfaceExtension[] extensions;

	// Subsurface children of this surface, ordered by stacking (bottom to top).
	WaiSubsurface[] subsurfaceChildren;

	// Back-reference to parent surface if this surface is a subsurface child.
	WaiSurface subsurfaceParent;

	// Accumulated damage in root-surface-local coordinates.
	DamageList rootLocalDamage;

	// Pending damage staged by wl_surface.damage / wl_surface.damage_buffer before commit.
	// Flushed into rootLocalDamage on wl_surface.commit.
	private DamageList _pendingRootDamage;

	void addSubsurfaceChild(WaiSubsurface child)
	{
		subsurfaceChildren ~= child;
	}

	void removeSubsurfaceChild(WaiSubsurface child)
	{
		subsurfaceChildren = subsurfaceChildren.remove!(c => c is child);
	}

	// written by WaiViewport extension on commit.
	ViewportState viewport;

	// Result of applying the buffer -> surface coordinate transform chain.
	struct SurfaceState
	{
		Vector2U size; // Effective surface size in surface-local coords.
		float[4] srcRect; // UV rect into the buffer texture [u0, v0, u1, v1].
		BufferTransform uvTransform; // Client-applied transform, renderer applies the inverse when sampling
	}

	// Compute effective surface size and texture source rect by applying the full transform chain.
	SurfaceState computeSurfaceState()
	{
		if (currentBuffer is null)
			return SurfaceState(Vector2U(0, 0), [0.0f, 0.0f, 1.0f, 1.0f], BufferTransform.normal);

		auto bufSz = currentBuffer.getImageSize();
		auto bufW = cast(float) bufSz.x;
		auto bufH = cast(float) bufSz.y;

		// buffer_transform: client has pre-applied this rotation/flip to the buffer content.
		// 90/270-degree variants swap the surface dimensions.
		bool swapDims = (bufferTransform & 1) != 0;

		float surfW = bufW / bufferScale;
		float surfH = bufH / bufferScale;

		if (swapDims)
		{
			auto tmp = surfW;
			surfW = surfH;
			surfH = tmp;
		}

		auto vp = viewport;
		float[4] srcRect = [0.0f, 0.0f, 1.0f, 1.0f];
		auto size = Vector2U(cast(uint) surfW, cast(uint) surfH);

		if (vp.hasSource && bufW > 0 && bufH > 0)
		{
			srcRect = [vp.srcX / surfW, vp.srcY / surfH, (vp.srcX + vp.srcWidth) / surfW, (vp.srcY + vp.srcHeight) / surfH];

			if (!vp.hasDest)
				size = Vector2U(cast(uint) vp.srcWidth, cast(uint) vp.srcHeight);
		}

		if (vp.hasDest)
			size = Vector2U(cast(uint) vp.destWidth, cast(uint) vp.destHeight);

		return SurfaceState(size, srcRect, bufferTransform);
	}

	void addExtension(ISurfaceExtension ext)
	{
		extensions ~= ext;
	}

	void removeExtension(ISurfaceExtension ext)
	{
		extensions = extensions.remove!(e => e is ext);
	}

	this(TrinoveCompositor compositor, WlClient cl, uint id)
	{
		this.compositor = compositor;
		super(cl, WlSurface.ver, id);
		mixin(onDestroyCallDestroy);
	}

	override void destroy(WlClient cl)
	{
		foreach (child; subsurfaceChildren)
			child.onParentDestroyed();
		subsurfaceChildren = null;

		// Remove ourselves from parent's children list if we're a subsurface
		if (subsurfaceParent !is null)
		{
			if (auto sub = cast(WaiSubsurface) role)
				subsurfaceParent.removeSubsurfaceChild(sub);
			subsurfaceParent = null;
		}

		foreach (seat; compositor.seatManager.seats)
			seat.clearFocusForSurface(this);

		foreach (ext; extensions)
			ext.onSurfaceDestroyed();
		extensions = null;

		if (role !is null)
		{
			role.onSurfaceDestroyed();
			role = null;
		}

		if (currentBuffer !is null)
		{
			currentBuffer.release();
			currentBuffer = null;
		}
		pendingBuffer = null;
		pendingFrameCallbacks.clear();
		frameCallbacks.clear();
		rootLocalDamage.release();
		_pendingRootDamage.release();
	}

	override void attach(WlClient cl, WlBuffer buffer, int x, int y)
	{
		pendingBufferAttached = true;
		pendingBuffer = cast(IWaylandBuffer) buffer;
	}

	override void damage(WlClient cl, int x, int y, int width, int height)
	{
		if (width > 0 && height > 0 && subsurfaceParent is null)
			_pendingRootDamage.add(Rect(x, y, cast(uint) width, cast(uint) height));

		if (role !is null)
			role.onDamage(Rect(x, y, cast(uint) width, cast(uint) height));
	}

	override void frame(WlClient cl, uint callback)
	{
		auto res = wl_resource_create(cl.native, WlCallback.iface.native, WlCallback.ver, callback);
		pendingFrameCallbacks.add(res);
	}

	override void setOpaqueRegion(WlClient cl, wl_resource* region)
	{
		// logWarn("Opaque regions are not supported");
	}

	override void setInputRegion(WlClient cl, wl_resource* region)
	{
		if (region is null)
		{
			pendingInputRegion = null;
			pendingInputRegionReset = true;
			return;
		}
		pendingInputRegion = cast(Region) ObjectCache.get(region);
		pendingInputRegionReset = false;
	}

	override void commit(WlClient cl)
	{
		if (pendingBufferAttached)
		{
			if (pendingBuffer)
				pendingBuffer.fetch(); // Upload to GPU

			if (currentBuffer && currentBuffer !is pendingBuffer)
				currentBuffer.release();

			currentBuffer = pendingBuffer;
			pendingBuffer = null;
			pendingBufferAttached = false;
		}

		bufferScale = _pendingBufferScale;
		bufferTransform = _pendingBufferTransform;

		if (pendingInputRegionReset)
		{
			inputRegionMode = InputRegionMode.infinite;
			inputRegion = null;
			pendingInputRegionReset = false;
		}
		else if (pendingInputRegion !is null)
		{
			if (pendingInputRegion.rects.length == 0)
			{
				inputRegionMode = InputRegionMode.passThrough;
				inputRegion = null;
			}
			else
			{
				inputRegionMode = InputRegionMode.explicit;
				inputRegion = pendingInputRegion.rects.dup;
			}
			pendingInputRegion = null;
		}

		if (subsurfaceParent is null)
			rootLocalDamage.swapWith(_pendingRootDamage);

		foreach (ext; extensions)
			ext.onCommit();

		if (role !is null)
			role.onCommit();

		// Move frame callbacks after role.onCommit() so sync subsurfaces can steal
		// them into their cached state before this runs.
		frameCallbacks.takeAll(pendingFrameCallbacks);

		foreach (child; subsurfaceChildren)
			child.parentCommitted();
	}

	override void setBufferTransform(WlClient cl, int transform)
	{
		_pendingBufferTransform = cast(BufferTransform) transform;
	}

	int bufferScale = 1;
	private int _pendingBufferScale = 1;

	BufferTransform bufferTransform = BufferTransform.normal;
	private BufferTransform _pendingBufferTransform = BufferTransform.normal;

	override void setBufferScale(WlClient cl, int scale)
	{
		_pendingBufferScale = scale < 1 ? 1 : scale;
	}

	override void damageBuffer(WlClient cl, int x, int y, int w, int h)
	{
		// damage_buffer coords are in the buffer's pixel space, need to transform into rootDamage space.
		if (w > 0 && h > 0 && subsurfaceParent is null)
		{
			auto sx = x / bufferScale, sy = y / bufferScale;
			auto sw = (w + bufferScale - 1) / bufferScale;
			auto sh = (h + bufferScale - 1) / bufferScale;
			_pendingRootDamage.add(Rect(sx, sy, cast(uint) sw, cast(uint) sh));
		}

		if (role !is null)
			role.onDamageBuffer(Rect(x, y, cast(uint) w, cast(uint) h));
	}

	void sendFrameCallbacks()
	{
		uint time = cast(uint)(MonoTime.currTime - compositor.startTime).total!"msecs";
		foreach (cb; frameCallbacks.items)
		{
			wl_resource_post_event(cb, WlCallback.doneOpCode, time);
			wl_resource_destroy(cb);
		}
		frameCallbacks.clear();
	}

}

struct ViewportState
{
	bool hasSource;
	float srcX = 0, srcY = 0, srcWidth = 0, srcHeight = 0;
	bool hasDest;
	int destWidth = 0, destHeight = 0;
}

struct ResourceList
{
	private enum Capacity = 16;
	private wl_resource*[Capacity] _items;
	private size_t _count;

	void add(wl_resource* res)
	{
		if (_count < Capacity)
			_items[_count++] = res;
	}

	// Move all entries from `other` into this list, clearing `other`.
	void takeAll(ref ResourceList other)
	{
		foreach (i; 0 .. other._count)
		{
			if (_count >= Capacity)
				break;
			_items[_count++] = other._items[i];
		}
		other.clear();
	}

	wl_resource*[] items()
	{
		return _items[0 .. _count];
	}

	void clear()
	{
		_items[0 .. _count] = null;
		_count = 0;
	}
}

// Result of a surface hit test: the deepest visible (sub)surface at a point.
struct SurfaceHit
{
	WaiSurface surface; // null if nothing was hit
	WaiSubsurface subsurface; // null if the hit is on the main surface
	Vector2I local; // surface-local coordinates of the hit point
}

// Find the topmost visible surface (main surface or any subsurface) at a given point.
// cursor must be relative to the root surface's origin.
SurfaceHit findSurfaceAt(WaiSurface root, Vector2I rootSize, Vector2I cursor)
{
	return findSurfaceAtAbs(root, null, Vector2I(0, 0), rootSize, cursor);
}

private bool pointInInputRegion(WaiSurface surface, Vector2I local)
{
	final switch (surface.inputRegionMode)
	{
	case InputRegionMode.infinite:
		return true;
	case InputRegionMode.passThrough:
		return false;
	case InputRegionMode.explicit:
		foreach (r; surface.inputRegion)
		{
			if (local.x >= r.position.x && local.x < r.position.x + cast(int) r.size.x && local.y >= r.position.y
					&& local.y < r.position.y + cast(int) r.size.y)
				return true;
		}
		return false;
	}
}

private SurfaceHit findSurfaceAtAbs(WaiSurface root, WaiSubsurface rootSub, Vector2I absPos, Vector2I size, Vector2I cursor)
{
	// Check subsurfaces topmost-first (last in array = drawn on top).
	foreach_reverse (sub; root.subsurfaceChildren)
	{
		if (sub.surface is null || sub.surface.currentBuffer is null)
			continue;
		auto subState = sub.surface.computeSurfaceState();
		auto subPos = absPos + sub.position;
		auto subSize = cast(Vector2I) subState.size;
		if (cursor.x >= subPos.x && cursor.x < subPos.x + subSize.x && cursor.y >= subPos.y && cursor.y < subPos.y + subSize
				.y)
		{
			auto nested = findSurfaceAtAbs(sub.surface, sub, subPos, subSize, cursor);
			if (nested.surface !is null)
				return nested;

			auto local = cursor - subPos;
			if (pointInInputRegion(sub.surface, local))
				return SurfaceHit(sub.surface, sub, local);
		}
	}
	if (cursor.x >= absPos.x && cursor.x < absPos.x + size.x && cursor.y >= absPos.y && cursor.y < absPos.y + size.y)
	{
		auto local = cursor - absPos;
		if (pointInInputRegion(root, local))
			return SurfaceHit(root, rootSub, local);
	}
	return SurfaceHit(null, null, Vector2I(0, 0));
}
