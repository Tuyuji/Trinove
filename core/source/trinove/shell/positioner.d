// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.shell.positioner;

import trinove.protocols.xdg_shell;
import trinove.math;
import wayland.server;

alias Anchor = XdgPositioner.Anchor;
alias Gravity = XdgPositioner.Gravity;
alias ConstraintAdjustment = XdgPositioner.ConstraintAdjustment;

// Calculate popup position relative to parent surface origin.
// Returns the top-left corner of the popup.
pragma(inline) Vector2I calculatePopupPosition(Rect anchorRect, Vector2U size, Anchor anchor, Gravity gravity, Vector2I offset)
{
	// Step 1: Find anchor point on the anchor rect
	int anchorX = anchorRect.left;
	int anchorY = anchorRect.top;

	final switch (anchor)
	{
	case Anchor.none:
		anchorX += anchorRect.width / 2;
		anchorY += anchorRect.height / 2;
		break;
	case Anchor.top:
		anchorX += anchorRect.width / 2;
		break;
	case Anchor.bottom:
		anchorX += anchorRect.width / 2;
		anchorY += anchorRect.height;
		break;
	case Anchor.left:
		anchorY += anchorRect.height / 2;
		break;
	case Anchor.right:
		anchorX += anchorRect.width;
		anchorY += anchorRect.height / 2;
		break;
	case Anchor.topLeft:
		break;
	case Anchor.topRight:
		anchorX += anchorRect.width;
		break;
	case Anchor.bottomLeft:
		anchorY += anchorRect.height;
		break;
	case Anchor.bottomRight:
		anchorX += anchorRect.width;
		anchorY += anchorRect.height;
		break;
	}

	// Step 2: Apply gravity to position popup relative to anchor point
	int popupX = anchorX;
	int popupY = anchorY;

	final switch (gravity)
	{
	case Gravity.none:
		popupX -= cast(int) size.x / 2;
		popupY -= cast(int) size.y / 2;
		break;
	case Gravity.top:
		popupX -= cast(int) size.x / 2;
		popupY -= cast(int) size.y;
		break;
	case Gravity.bottom:
		popupX -= cast(int) size.x / 2;
		break;
	case Gravity.left:
		popupX -= cast(int) size.x;
		popupY -= cast(int) size.y / 2;
		break;
	case Gravity.right:
		popupY -= cast(int) size.y / 2;
		break;
	case Gravity.topLeft:
		popupX -= cast(int) size.x;
		popupY -= cast(int) size.y;
		break;
	case Gravity.topRight:
		popupY -= cast(int) size.y;
		break;
	case Gravity.bottomLeft:
		popupX -= cast(int) size.x;
		break;
	case Gravity.bottomRight:
		break;
	}

	popupX += offset.x;
	popupY += offset.y;

	return Vector2I(popupX, popupY);
}

class WaiXdgPositioner : XdgPositioner
{
	Anchor anchor = Anchor.none;
	Gravity gravity = Gravity.none;
	ConstraintAdjustment constraintAdjustment = ConstraintAdjustment.none;
	Rect anchorRect;

	Vector2U size;
	Vector2I offset;
	Vector2U parentSize;
	bool reactive = false;
	uint parentConfigureSerial;

	this(WlClient cl, uint id)
	{
		super(cl, XdgPositioner.ver, id);
	}

	// Calculate popup position relative to parent surface origin.
	// Returns the top-left corner of the popup.
	Vector2I calculatePosition()
	{
		return calculatePopupPosition(anchorRect, size, anchor, gravity, offset);
	}

	override void destroy(WlClient cl)
	{
	}

	override void setSize(WlClient cl, int width, int height)
	{
		if (width <= 0 || height <= 0)
		{
			postError(Error.invalidInput, "Size must be positive");
			return;
		}
		size = Vector2U(cast(uint) width, cast(uint) height);
	}

	override void setAnchorRect(WlClient cl, int x, int y, int width, int height)
	{
		if (width < 0 || height < 0)
		{
			postError(Error.invalidInput, "Anchor rect size must be non-negative");
			return;
		}
		anchorRect = Rect(x, y, width, height);
	}

	override void setAnchor(WlClient cl, Anchor a)
	{
		anchor = a;
	}

	override void setGravity(WlClient cl, Gravity g)
	{
		gravity = g;
	}

	override void setConstraintAdjustment(WlClient cl, ConstraintAdjustment ca)
	{
		constraintAdjustment = ca;
	}

	override void setOffset(WlClient cl, int x, int y)
	{
		offset = Vector2I(x, y);
	}

	override void setReactive(WlClient cl)
	{
		reactive = true;
	}

	override void setParentSize(WlClient cl, int parentWidth, int parentHeight)
	{
		parentSize = Vector2U(cast(uint) parentWidth, cast(uint) parentHeight);
	}

	override void setParentConfigure(WlClient cl, uint serial)
	{
		parentConfigureSerial = serial;
	}
}

@("positioner: center anchor + center gravity = centered on anchor rect")
unittest
{
	// Anchor rect at (100, 200) size 40x30, popup size 100x50
	auto pos = calculatePopupPosition(Rect(100, 200, 40, 30), Vector2U(100, 50), Anchor.none, Gravity.none, Vector2I(0, 0));

	// Anchor point: center of rect = (120, 215)
	// Gravity none: center popup on anchor = (120-50, 215-25) = (70, 190)
	assert(pos.x == 70 && pos.y == 190);
}

@("positioner: dropdown menu — bottom anchor + bottom gravity")
unittest
{
	// Menu bar item at (50, 0) size 80x25, dropdown popup 120x200
	auto pos = calculatePopupPosition(Rect(50, 0, 80, 25), Vector2U(120, 200), Anchor.bottom, Gravity.bottom, Vector2I(0, 0));

	// Anchor point: bottom center of rect = (90, 25)
	// Gravity bottom: popup below anchor, centered horizontally = (90-60, 25) = (30, 25)
	assert(pos.x == 30 && pos.y == 25);
}

@("positioner: right-click context menu — bottomRight anchor + bottomRight gravity")
unittest
{
	// Zero-size anchor rect at cursor position (300, 400), popup 150x180
	auto pos = calculatePopupPosition(Rect(300, 400, 0, 0), Vector2U(150, 180), Anchor.bottomRight, Gravity.bottomRight, Vector2I(
			0, 0));

	// Anchor point: bottom-right of zero-size rect = (300, 400)
	// Gravity bottomRight: popup's top-left at anchor = (300, 400)
	assert(pos.x == 300 && pos.y == 400);
}

@("positioner: submenu — right anchor + bottomRight gravity")
unittest
{
	// Parent menu item at (0, 60) size 150x25, submenu 150x100
	auto pos = calculatePopupPosition(Rect(0, 60, 150, 25), Vector2U(150, 100), Anchor.right, Gravity.bottomRight, Vector2I(
			0, 0));

	// Anchor point: right center = (150, 72)
	// Gravity bottomRight: popup's top-left at anchor = (150, 72)
	assert(pos.x == 150 && pos.y == 72);
}

@("positioner: tooltip above — top anchor + top gravity")
unittest
{
	// Widget at (200, 300) size 100x30, tooltip 80x20
	auto pos = calculatePopupPosition(Rect(200, 300, 100, 30), Vector2U(80, 20), Anchor.top, Gravity.top, Vector2I(0, 0));

	// Anchor point: top center = (250, 300)
	// Gravity top: popup above anchor = (250-40, 300-20) = (210, 280)
	assert(pos.x == 210 && pos.y == 280);
}

@("positioner: offset is applied after anchor+gravity")
unittest
{
	auto pos = calculatePopupPosition(Rect(0, 0, 100, 100), Vector2U(50, 50), Anchor.none, Gravity.none, Vector2I(10, -5));

	// Without offset: center of (0,0,100,100) = (50,50), centered popup = (25, 25)
	// With offset: (35, 20)
	assert(pos.x == 35 && pos.y == 20);
}

@("positioner: all anchors with gravity none land on expected anchor points")
unittest
{
	// Use a 100x100 rect at origin, 0x0 popup, gravity none (no shift)
	// This isolates the anchor point calculation
	auto rect = Rect(0, 0, 100, 100);
	auto size = Vector2U(0, 0);
	auto g = Gravity.none;
	auto off = Vector2I(0, 0);

	// none = center (50, 50)
	auto p = calculatePopupPosition(rect, size, Anchor.none, g, off);
	assert(p.x == 50 && p.y == 50);

	// top = top center (50, 0)
	p = calculatePopupPosition(rect, size, Anchor.top, g, off);
	assert(p.x == 50 && p.y == 0);

	// bottom = bottom center (50, 100)
	p = calculatePopupPosition(rect, size, Anchor.bottom, g, off);
	assert(p.x == 50 && p.y == 100);

	// left = left center (0, 50)
	p = calculatePopupPosition(rect, size, Anchor.left, g, off);
	assert(p.x == 0 && p.y == 50);

	// right = right center (100, 50)
	p = calculatePopupPosition(rect, size, Anchor.right, g, off);
	assert(p.x == 100 && p.y == 50);

	// topLeft = (0, 0)
	p = calculatePopupPosition(rect, size, Anchor.topLeft, g, off);
	assert(p.x == 0 && p.y == 0);

	// topRight = (100, 0)
	p = calculatePopupPosition(rect, size, Anchor.topRight, g, off);
	assert(p.x == 100 && p.y == 0);

	// bottomLeft = (0, 100)
	p = calculatePopupPosition(rect, size, Anchor.bottomLeft, g, off);
	assert(p.x == 0 && p.y == 100);

	// bottomRight = (100, 100)
	p = calculatePopupPosition(rect, size, Anchor.bottomRight, g, off);
	assert(p.x == 100 && p.y == 100);
}

@("positioner: all gravities with center anchor shift popup correctly")
unittest
{
	// Anchor point fixed at center of (0,0,100,100) = (50,50)
	// Popup size 20x10
	auto rect = Rect(0, 0, 100, 100);
	auto size = Vector2U(20, 10);
	auto a = Anchor.none;
	auto off = Vector2I(0, 0);

	// none: centered = (50-10, 50-5) = (40, 45)
	auto p = calculatePopupPosition(rect, size, a, Gravity.none, off);
	assert(p.x == 40 && p.y == 45);

	// top: above anchor = (40, 40)
	p = calculatePopupPosition(rect, size, a, Gravity.top, off);
	assert(p.x == 40 && p.y == 40);

	// bottom: below anchor = (40, 50)
	p = calculatePopupPosition(rect, size, a, Gravity.bottom, off);
	assert(p.x == 40 && p.y == 50);

	// left: to the left = (30, 45)
	p = calculatePopupPosition(rect, size, a, Gravity.left, off);
	assert(p.x == 30 && p.y == 45);

	// right: to the right = (50, 45)
	p = calculatePopupPosition(rect, size, a, Gravity.right, off);
	assert(p.x == 50 && p.y == 45);

	// topLeft: above-left = (30, 40)
	p = calculatePopupPosition(rect, size, a, Gravity.topLeft, off);
	assert(p.x == 30 && p.y == 40);

	// topRight: above-right = (50, 40)
	p = calculatePopupPosition(rect, size, a, Gravity.topRight, off);
	assert(p.x == 50 && p.y == 40);

	// bottomLeft: below-left = (30, 50)
	p = calculatePopupPosition(rect, size, a, Gravity.bottomLeft, off);
	assert(p.x == 30 && p.y == 50);

	// bottomRight: below-right = (50, 50)
	p = calculatePopupPosition(rect, size, a, Gravity.bottomRight, off);
	assert(p.x == 50 && p.y == 50);
}
