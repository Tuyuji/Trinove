// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.renderer.scene;

import trinove.math;
import trinove.layer;
import trinove.output_manager;
import std.algorithm : remove;
import trinove.gpu.itexture : ITexture;
import wayland.server.protocol : WlOutput;

alias BufferTransform = WlOutput.Transform;

// Interface for objects that want to be notified when their node is rendered.
interface IFrameListener
{
	void onFrame(OutputManager.ManagedOutput output);
}

// Base class for all renderable scene nodes.
//
// Scene nodes form a tree structure with transforms, visibility, and damage tracking.
// The scene graph is a pure rendering abstraction, no knowledge of windows or input.
class SceneNode
{
	// Parent node (null for root nodes)
	SceneNode parent;
	SceneNode[] children;

	// Position relative to parent
	Vector2F position = Vector2F(0, 0);

	// Computed size in pixels.
	// The visual bounding box of this node's own content and all its children.
	// Container nodes (base SceneNode) have no own content so size
	// equals visualBounds().size; leaf nodes (RectNode, ShadowNode) add their own area.
	@property Vector2F size()
	{
		auto vb = visualBounds();
		return Vector2F(cast(float) vb.size.x, cast(float) vb.size.y);
	}

	// The node's own content area in local coordinates, excluding children.
	// Override in subclasses that have drawable content.
	protected @property Vector2F ownSize()
	{
		return Vector2F(0, 0);
	}

	// Scale factor
	Vector2F scale = Vector2F(1, 1);

	// Transform origin (0,0 = top-left, 0.5,0.5 = center)
	Vector2F anchor = Vector2F(0, 0);

	// Rotation in radians
	float rotation = 0;

	// 0.0 = invisible, 1.0 = fully opaque
	float opacity = 1.0;

	bool visible = true;

	// Damaged regions in node-local coordinates
	NodeDamageList damage;

	// Whether this node has damage that needs rendering
	bool dirty() const
	{
		return !damage.empty;
	}

	void addChild(SceneNode child)
	{
		if (child.parent !is null)
			child.parent.removeChild(child);

		child.parent = this;
		children ~= child;

		if (damage.arena !is null)
			child.setDamageArena(damage.arena);
	}

	void removeChild(SceneNode child)
	{
		// Mark the area occupied by the child (including its descendants) as damaged
		if (child.parent is this)
		{
			auto bounds = child.visualBounds();
			addDamage(Rect(cast(int)(child.position.x + bounds.position.x),
					cast(int)(child.position.y + bounds.position.y), bounds.size.x, bounds.size.y));
		}

		children = children.remove!(c => c is child);
		if (child.parent is this)
			child.parent = null;
	}

	void addDamage(Rect region)
	{
		damage.add(region, 32);
	}

	void addFullDamage()
	{
		damage.setFull(visualBounds());
	}

	void clearDamage()
	{
		damage.clear();
	}

	void setDamageArena(DamageArena* arena)
	{
		damage.arena = arena;
		foreach (child; children)
			child.setDamageArena(arena);
	}

	// Own content area in local coordinates (excludes children).
	// Used for damage clamping within the node's own drawable region.
	Rect localBounds()
	{
		auto s = ownSize();
		return Rect(0, 0, cast(uint) s.x, cast(uint) s.y);
	}

	// Get visual bounds including own content and all children in local coordinates.
	// The returned Rect may have a negative position when children extend above or
	// to the left of the node's origin (e.g. XWayland subsurface titlebars at y=-25).
	Rect visualBounds()
	{
		auto own = ownSize();
		bool hasOwn = own.x > 0 || own.y > 0;

		int minX = hasOwn ? 0 : int.max;
		int minY = hasOwn ? 0 : int.max;
		int maxX = hasOwn ? cast(int) own.x : int.min;
		int maxY = hasOwn ? cast(int) own.y : int.min;

		foreach (child; children)
		{
			auto childBounds = child.visualBounds();
			int childMinX = cast(int) child.position.x + childBounds.position.x;
			int childMinY = cast(int) child.position.y + childBounds.position.y;
			int childMaxX = childMinX + cast(int) childBounds.size.x;
			int childMaxY = childMinY + cast(int) childBounds.size.y;

			if (childMinX < minX)
				minX = childMinX;
			if (childMinY < minY)
				minY = childMinY;
			if (childMaxX > maxX)
				maxX = childMaxX;
			if (childMaxY > maxY)
				maxY = childMaxY;
		}

		if (minX == int.max)
			return Rect(0, 0, 0, 0);

		return Rect(minX, minY, cast(uint)(maxX - minX), cast(uint)(maxY - minY));
	}

	// Calculate world position by walking up the parent chain
	Vector2F worldPosition()
	{
		auto pos = position;
		auto p = parent;
		while (p !is null)
		{
			pos = Vector2F(pos.x + p.position.x, pos.y + p.position.y);
			p = p.parent;
		}
		return pos;
	}
}

// A textured rectangle with optional color tint.
class RectNode : SceneNode
{
	// null = no texture, draw solid color
	ITexture texture = null;

	float[4] color = [1.0f, 1.0f, 1.0f, 1.0f];

	// Source rectangle in UV space: [u0, v0, u1, v1].
	// Default [0,0,1,1] = entire texture. Set by viewporter.
	float[4] srcRect = [0.0f, 0.0f, 1.0f, 1.0f];

	// Optional listener for frame callbacks.
	IFrameListener frameListener;

	// Texture-applied buffer transform.
	BufferTransform uvTransform = BufferTransform.normal;

	private Vector2F _size = Vector2F(0, 0);

	protected override @property Vector2F ownSize()
	{
		return _size;
	}

	alias size = SceneNode.size;

	// Set explicit size (required for solid-colour rects and viewporter-scaled content).
	@property void size(Vector2F s)
	{
		_size = s;
	}
}

class ShadowNode : SceneNode
{
	float[4] color = [0.0f, 0.0f, 0.0f, 0.5f];

	// Size of the content area being shadowed (excludes the extents themselves).
	Vector2U contentSize;

	// How far the shadow extends beyond the content on each side.
	uint extentTop = 4;
	uint extentBottom = 16;
	uint extentLeft = 12;
	uint extentRight = 12;

	uint blurRadius = 12;
	uint cornerRadius = 8;

	protected override @property Vector2F ownSize()
	{
		return Vector2F(contentSize.x + extentLeft + extentRight, contentSize.y + extentTop + extentBottom);
	}
}

@("SceneNode: addChild sets parent")
unittest
{
	auto parent = new SceneNode();
	auto child = new SceneNode();

	parent.addChild(child);

	assert(child.parent is parent);
	assert(parent.children.length == 1);
	assert(parent.children[0] is child);
}

@("SceneNode: addChild reparents from old parent")
unittest
{
	auto parent1 = new SceneNode();
	auto parent2 = new SceneNode();
	auto child = new SceneNode();

	parent1.addChild(child);
	assert(parent1.children.length == 1);

	parent2.addChild(child);
	assert(child.parent is parent2);
	assert(parent1.children.length == 0);
	assert(parent2.children.length == 1);
}

@("SceneNode: removeChild clears parent and array")
unittest
{
	auto parent = new SceneNode();
	auto child = new SceneNode();

	parent.addChild(child);
	parent.removeChild(child);

	assert(child.parent is null);
	assert(parent.children.length == 0);
}

@("SceneNode: worldPosition with no parent")
unittest
{
	auto node = new SceneNode();
	node.position = Vector2F(100, 200);

	auto wp = node.worldPosition();
	assert(wp.x == 100 && wp.y == 200);
}

@("SceneNode: worldPosition walks parent chain")
unittest
{
	auto root = new SceneNode();
	root.position = Vector2F(10, 20);

	auto mid = new SceneNode();
	mid.position = Vector2F(30, 40);
	root.addChild(mid);

	auto leaf = new SceneNode();
	leaf.position = Vector2F(5, 5);
	mid.addChild(leaf);

	auto wp = leaf.worldPosition();
	assert(wp.x == 45 && wp.y == 65); // 10+30+5, 20+40+5
}

@("RectNode: localBounds reflects explicit size")
unittest
{
	auto node = new RectNode();
	node.size = Vector2F(200, 100);

	auto b = node.localBounds();
	assert(b.position.x == 0 && b.position.y == 0);
	assert(b.size.x == 200 && b.size.y == 100);
}

@("SceneNode: container visualBounds with no children is empty")
unittest
{
	auto node = new SceneNode();

	auto b = node.visualBounds();
	assert(b.size.x == 0 && b.size.y == 0);
}

@("RectNode: visualBounds with no children equals own size")
unittest
{
	auto node = new RectNode();
	node.size = Vector2F(100, 50);

	auto b = node.visualBounds();
	assert(b.size.x == 100 && b.size.y == 50);
}

@("SceneNode: visualBounds expands to include children")
unittest
{
	auto parent = new RectNode();
	parent.size = Vector2F(100, 100);

	auto child = new RectNode();
	child.position = Vector2F(50, 50);
	child.size = Vector2F(200, 200);
	parent.addChild(child);

	auto b = parent.visualBounds();
	// Parent own: 0,0 to 100,100. Child: 50,50 to 250,250.
	// Union: 0,0 to 250,250
	assert(b.position.x == 0 && b.position.y == 0);
	assert(b.size.x == 250 && b.size.y == 250);
}

@("SceneNode: container visualBounds is union of children")
unittest
{
	auto parent = new SceneNode();

	auto child = new RectNode();
	child.position = Vector2F(10, 20);
	child.size = Vector2F(80, 60);
	parent.addChild(child);

	auto b = parent.visualBounds();
	assert(b.position.x == 10 && b.position.y == 20);
	assert(b.size.x == 80 && b.size.y == 60);
}

@("SceneNode: visualBounds includes negative-offset children")
unittest
{
	auto parent = new RectNode();
	parent.size = Vector2F(100, 100);

	auto child = new RectNode();
	child.position = Vector2F(-20, -10);
	child.size = Vector2F(50, 50);
	parent.addChild(child);

	auto b = parent.visualBounds();
	// Parent own: 0,0 to 100,100. Child: -20,-10 to 30,40.
	// Union: -20,-10 to 100,100 → size 120,110
	assert(b.position.x == -20 && b.position.y == -10);
	assert(b.size.x == 120 && b.size.y == 110);
}

@("SceneNode: damage tracking")
unittest
{
	DamageArena arena;
	arena.initialize();
	scope (exit)
		arena.release();

	auto node = new SceneNode();
	node.setDamageArena(&arena);
	assert(!node.dirty);

	node.addDamage(Rect(0, 0, 10, 10));
	assert(node.dirty);

	node.clearDamage();
	assert(!node.dirty);
}

@("RectNode: addFullDamage covers visual bounds")
unittest
{
	DamageArena arena;
	arena.initialize();
	scope (exit)
		arena.release();

	auto node = new RectNode();
	node.setDamageArena(&arena);
	node.size = Vector2F(200, 100);

	node.addFullDamage();
	assert(node.dirty);

	// Should have one rect covering the full area
	foreach (rect; node.damage)
	{
		assert(rect.position.x == 0 && rect.position.y == 0);
		assert(rect.size.x == 200 && rect.size.y == 100);
	}
}

@("SceneNode: container addFullDamage covers all children")
unittest
{
	DamageArena arena;
	arena.initialize();
	scope (exit)
		arena.release();

	auto container = new SceneNode();
	container.setDamageArena(&arena);

	auto child = new RectNode();
	child.position = Vector2F(0, -25);
	child.size = Vector2F(100, 25);
	container.addChild(child);

	auto content = new RectNode();
	content.position = Vector2F(0, 0);
	content.size = Vector2F(100, 200);
	container.addChild(content);

	container.clearDamage();
	container.addFullDamage();
	assert(container.dirty);

	// Damage should cover the full visual bounds including the negative-offset child
	foreach (rect; container.damage)
	{
		assert(rect.position.y == -25);
		assert(rect.size.y == 225); // 25 + 200
	}
}

@("SceneNode: removeChild damages parent")
unittest
{
	DamageArena arena;
	arena.initialize();
	scope (exit)
		arena.release();

	auto parent = new SceneNode();
	parent.setDamageArena(&arena);
	auto child = new RectNode();
	child.position = Vector2F(10, 20);
	child.size = Vector2F(50, 30);
	parent.addChild(child);

	parent.clearDamage(); // Clear any prior damage
	parent.removeChild(child);

	// Parent should have damage where the child was
	assert(parent.dirty);
}

// The scene graph manages the rendering hierarchy.
//
// It exists in compositor space, a single global coordinate system.
// Outputs (monitors) are viewports into this space, managed by OutputManager.
class SceneGraph
{
	// One root node per layer (indexed by Layer enum)
	SceneNode[Layer.max + 1] layerRoots;

	// Shared arena for all scene node damage rects.
	// Reset per frame after propagation.
	DamageArena damageArena;

	// Reference to output manager (set by compositor)
	private OutputManager _outputManager;

	// Callback invoked when a repaint is needed.
	private void delegate() _repaintCallback;

	this()
	{
		damageArena.initialize();
		foreach (i; 0 .. Layer.max + 1)
		{
			layerRoots[i] = new SceneNode();
			layerRoots[i].visible = true;
			layerRoots[i].setDamageArena(&damageArena);
		}
	}

	~this()
	{
		damageArena.release();
	}

	void setOutputManager(OutputManager outputManager)
	{
		_outputManager = outputManager;
	}

	@property OutputManager outputManager()
	{
		return _outputManager;
	}

	// Set the callback to invoke when a repaint is needed.
	// The compositor sets this during initialization.
	void setRepaintCallback(void delegate() callback)
	{
		_repaintCallback = callback;
	}

	// Schedule a repaint. Call this after damaging scene nodes.
	// Invokes the compositor's callback to wake up the event loop.
	void scheduleRepaint()
	{
		if (_repaintCallback !is null)
			_repaintCallback();
	}

	// Propagate damage from scene nodes to outputs.
	// Call this before rendering to determine which outputs need updates.
	void propagateDamage()
	{
		if (_outputManager is null)
			return;

		foreach (layerRoot; layerRoots)
		{
			propagateNodeDamage(layerRoot, Vector2F(0, 0));
		}
	}

	private void propagateNodeDamage(SceneNode node, Vector2F parentPos)
	{
		auto worldPos = Vector2F(parentPos.x + node.position.x, parentPos.y + node.position.y);

		if (node.dirty)
		{
			// Convert each damaged region to compositor space
			foreach (region; node.damage)
			{
				auto compositorRect = Rect(cast(int)(region.position.x + worldPos.x),
						cast(int)(region.position.y + worldPos.y), region.size.x, region.size.y);

				// Add to all affected outputs via OutputManager
				_outputManager.addDamage(compositorRect);
			}
			node.clearDamage();
		}

		foreach (child; node.children)
		{
			propagateNodeDamage(child, worldPos);
		}
	}

	// Clear all scene node damage and reset the arena.
	// Called after propagateDamage() which already clears dirty nodes inline.
	void clearAllNodeDamage()
	{
		damageArena.reset();
	}
}
