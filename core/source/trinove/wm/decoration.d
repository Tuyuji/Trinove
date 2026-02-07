// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.wm.decoration;

import trinove.math;
import trinove.renderer.scene;
import trinove.wm.window;

enum DecorationHit
{
	None,
	Content,
	Titlebar,
	CloseButton,
	MaximizeButton,
	MinimizeButton,
	ResizeTop,
	ResizeBottom,
	ResizeLeft,
	ResizeRight,
	ResizeTopLeft,
	ResizeTopRight,
	ResizeBottomLeft,
	ResizeBottomRight,
}

// Manages a window's decorations.
class WindowDecoration
{
	// Container node, parent of all decoration + content
	SceneNode container;

	// The window this decoration wraps
	Window window;

	// Decoration scene nodes
	ShadowNode shadow;
	RectNode titlebar;
	RectNode closeButton;
	RectNode maximizeButton;
	RectNode minimizeButton;

	// Decoration metrics
	enum titlebarHeight = 24;
	enum buttonSize = 16;
	enum buttonPadding = 4;
	enum borderWidth = 0;

	static immutable float[4] titlebarColorFocused = [0.3f, 0.3f, 0.35f, 1.0f];
	static immutable float[4] titlebarColorUnfocused = [0.2f, 0.2f, 0.22f, 1.0f];
	static immutable float[4] shadowColor = [0.0f, 0.0f, 0.0f, 0.3f];
	static immutable float[4] closeButtonColor = [0.8f, 0.3f, 0.3f, 1.0f];
	static immutable float[4] buttonColor = [0.4f, 0.4f, 0.45f, 1.0f];

	this(Window window)
	{
		this.window = window;

		container = new SceneNode();
		container.visible = true;

		shadow = new ShadowNode();
		shadow.color = shadowColor;
		shadow.extentTop = 10;
		shadow.extentBottom = 15;
		shadow.extentLeft = 15;
		shadow.extentRight = 15;
		shadow.blurRadius = 5;
		shadow.cornerRadius = 7;
		container.addChild(shadow);

		titlebar = new RectNode();
		titlebar.color = titlebarColorUnfocused;
		container.addChild(titlebar);

		closeButton = new RectNode();
		closeButton.color = closeButtonColor;
		container.addChild(closeButton);

		maximizeButton = new RectNode();
		maximizeButton.color = buttonColor;
		container.addChild(maximizeButton);

		minimizeButton = new RectNode();
		minimizeButton.color = buttonColor;
		container.addChild(minimizeButton);

		container.addChild(window.containerNode);
	}

	// Frame origin in compositor space (top-left of the decoration container).
	@property Vector2I position()
	{
		return Vector2I(cast(int) container.position.x, cast(int) container.position.y);
	}

	@property void position(Vector2I pos)
	{
		container.position = Vector2F(pos.x, pos.y);
		container.addFullDamage();
	}

	// Set decoration position from the client content origin.
	// Computes the frame origin by subtracting decoration insets.
	@property void clientPosition(Vector2I clientPos)
	{
		position = Vector2I(clientPos.x - borderWidth, clientPos.y - titlebarHeight);
	}

	// Total size including decorations
	@property Vector2U totalSize()
	{
		return Vector2U(window.surfaceSize.x + borderWidth * 2, window.surfaceSize.y + titlebarHeight + borderWidth);
	}

	// Update decoration geometry when window size changes
	void updateGeometry()
	{
		auto contentW = window.surfaceSize.x;
		auto contentH = window.surfaceSize.y;

		auto decorW = contentW + borderWidth * 2;
		auto decorH = contentH + titlebarHeight + borderWidth;

		shadow.position = Vector2F(-cast(int) shadow.extentLeft, -cast(int) shadow.extentTop);
		shadow.contentSize = Vector2U(decorW, decorH);

		titlebar.position = Vector2F(0, 0);
		titlebar.size = Vector2F(contentW + borderWidth * 2, titlebarHeight);

		auto buttonPos = Vector2F(contentW + borderWidth * 2 - buttonPadding - buttonSize, (titlebarHeight - buttonSize) / 2.0f);

		closeButton.position = buttonPos;
		closeButton.size = Vector2F(buttonSize, buttonSize);
		buttonPos.x -= buttonSize + buttonPadding;

		maximizeButton.position = buttonPos;
		maximizeButton.size = Vector2F(buttonSize, buttonSize);
		buttonPos.x -= buttonSize + buttonPadding;

		minimizeButton.position = buttonPos;
		minimizeButton.size = Vector2F(buttonSize, buttonSize);

		window.containerNode.position = Vector2F(borderWidth, titlebarHeight);
		window.contentNode.size = Vector2F(contentW, contentH);
	}

	void updateFocus(bool focused)
	{
		titlebar.color = focused ? titlebarColorFocused : titlebarColorUnfocused;
		titlebar.addFullDamage();
	}

	// Hit-test a point in compositor space
	DecorationHit hitTest(Vector2I pos)
	{
		enum resizeGrip = 5;

		auto local = Vector2I(pos.x - cast(int) container.position.x, pos.y - cast(int) container.position.y);

		auto w = cast(int) totalSize.x;
		auto h = cast(int) totalSize.y;

		bool inResizeZone = local.x >= -resizeGrip && local.x < w + resizeGrip && local.y >= -resizeGrip && local.y < h + resizeGrip;

		if (inResizeZone)
		{
			bool left = local.x < resizeGrip;
			bool right = local.x >= w - resizeGrip;
			bool top = local.y < resizeGrip;
			bool bottom = local.y >= h - resizeGrip;

			if (top && left)
				return DecorationHit.ResizeTopLeft;
			if (top && right)
				return DecorationHit.ResizeTopRight;
			if (bottom && left)
				return DecorationHit.ResizeBottomLeft;
			if (bottom && right)
				return DecorationHit.ResizeBottomRight;
			if (top)
				return DecorationHit.ResizeTop;
			if (bottom)
				return DecorationHit.ResizeBottom;
			if (left)
				return DecorationHit.ResizeLeft;
			if (right)
				return DecorationHit.ResizeRight;
		}

		if (local.x < 0 || local.y < 0 || local.x >= w || local.y >= h)
			return DecorationHit.None;

		if (isInRect(local, closeButton))
			return DecorationHit.CloseButton;
		if (isInRect(local, maximizeButton))
			return DecorationHit.MaximizeButton;
		if (isInRect(local, minimizeButton))
			return DecorationHit.MinimizeButton;

		if (local.y < titlebarHeight)
			return DecorationHit.Titlebar;

		return DecorationHit.Content;
	}

	private bool isInRect(Vector2I pos, RectNode node)
	{
		int nx = cast(int) node.position.x;
		int ny = cast(int) node.position.y;
		int nw = cast(int) node.size.x;
		int nh = cast(int) node.size.y;
		return pos.x >= nx && pos.x < nx + nw && pos.y >= ny && pos.y < ny + nh;
	}

}
