// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.wm.seat_state;

import trinove.math;
import trinove.wm.view;
import trinove.wm.window;
import trinove.wm.decoration : DecorationHit;
import std.algorithm.comparison : max, min;

version (unittest)
{
	private class MockWindow : Window
	{
		override void close() {}
		override protected void deliverConfigure(ref WindowConfigureData) {}
		override protected void deliverResizeHint(ref WindowConfigureData) {}
	}
}

// Interaction type for window move/resize
enum InteractionType
{
	None,
	Move,
	Resize,
}

// Per-seat window interaction state owned by a WM.
// Tracks the in-progress move/resize interaction for a single seat.
class SeatInteraction
{
	InteractionType interaction;
	View interactionView;
	Vector2I interactionStartPointer;
	Vector2I interactionStartPosition;
	Vector2U interactionStartSize;
	DecorationHit resizeEdge;

	void beginMove(View view, Vector2I startPos, Vector2I viewPos)
	{
		interaction = InteractionType.Move;
		interactionView = view;
		interactionStartPointer = startPos;
		interactionStartPosition = viewPos;
	}

	void beginResize(Window window, Vector2I startPos, Vector2I windowPos, Vector2U windowSize, DecorationHit edge)
	{
		interaction = InteractionType.Resize;
		interactionView = window;
		interactionStartPointer = startPos;
		interactionStartPosition = windowPos;
		interactionStartSize = windowSize;
		resizeEdge = edge;
		window.state.resizing = true;
	}

	// Update ongoing interaction, returns new position for move or new size for resize.
	bool updateInteraction(Vector2I currentPos, out Vector2I newPos, out Vector2U newSize)
	{
		if (interaction == InteractionType.None)
			return false;

		auto delta = Vector2I(currentPos.x - interactionStartPointer.x, currentPos.y - interactionStartPointer.y);

		if (interaction == InteractionType.Move)
		{
			newPos = Vector2I(interactionStartPosition.x + delta.x, interactionStartPosition.y + delta.y);
			return true;
		}
		else if (interaction == InteractionType.Resize)
		{
			auto window = cast(Window) interactionView;
			newSize = calculateResize(window, delta);
			newPos = interactionStartPosition;

			if (resizeEdge == DecorationHit.ResizeLeft || resizeEdge == DecorationHit.ResizeTopLeft
					|| resizeEdge == DecorationHit.ResizeBottomLeft)
				newPos.x = interactionStartPosition.x + delta.x;
			if (resizeEdge == DecorationHit.ResizeTop || resizeEdge == DecorationHit.ResizeTopLeft
					|| resizeEdge == DecorationHit.ResizeTopRight)
				newPos.y = interactionStartPosition.y + delta.y;

			return true;
		}

		return false;
	}

	void endInteraction()
	{
		if (auto window = cast(Window) interactionView)
			window.state.resizing = false;

		interaction = InteractionType.None;
		interactionView = null;
	}

	// Calculate position adjustment when client commits a new size during resize.
	// Returns the delta to apply to the window position to keep the anchored edge stable.
	Vector2I getResizePositionAdjustment(Vector2U oldSize, Vector2U newSize)
	{
		if (interaction != InteractionType.Resize)
			return Vector2I(0, 0);

		auto delta = Vector2I(cast(int) oldSize.x - cast(int) newSize.x, cast(int) oldSize.y - cast(int) newSize.y);

		Vector2I adjustment;

		if (resizeEdge == DecorationHit.ResizeLeft || resizeEdge == DecorationHit.ResizeTopLeft
				|| resizeEdge == DecorationHit.ResizeBottomLeft)
			adjustment.x = delta.x;
		if (resizeEdge == DecorationHit.ResizeTop || resizeEdge == DecorationHit.ResizeTopLeft || resizeEdge == DecorationHit
				.ResizeTopRight)
			adjustment.y = delta.y;

		return adjustment;
	}

	private Vector2U calculateResize(Window window, Vector2I delta)
	{
		int newW = cast(int) interactionStartSize.x;
		int newH = cast(int) interactionStartSize.y;

		final switch (resizeEdge)
		{
		case DecorationHit.ResizeRight:
			newW += delta.x;
			break;
		case DecorationHit.ResizeLeft:
			newW -= delta.x;
			break;
		case DecorationHit.ResizeBottom:
			newH += delta.y;
			break;
		case DecorationHit.ResizeTop:
			newH -= delta.y;
			break;
		case DecorationHit.ResizeTopLeft:
			newW -= delta.x;
			newH -= delta.y;
			break;
		case DecorationHit.ResizeTopRight:
			newW += delta.x;
			newH -= delta.y;
			break;
		case DecorationHit.ResizeBottomLeft:
			newW -= delta.x;
			newH += delta.y;
			break;
		case DecorationHit.ResizeBottomRight:
			newW += delta.x;
			newH += delta.y;
			break;
		case DecorationHit.None:
		case DecorationHit.Titlebar:
		case DecorationHit.Content:
		case DecorationHit.CloseButton:
		case DecorationHit.MaximizeButton:
		case DecorationHit.MinimizeButton:
			break;
		}

		if (window !is null)
		{
			auto minW = window.minSize.x > 0 ? window.minSize.x : 100;
			auto minH = window.minSize.y > 0 ? window.minSize.y : 50;
			newW = max(newW, cast(int) minW);
			newH = max(newH, cast(int) minH);

			if (window.maxSize.x > 0)
				newW = min(newW, cast(int) window.maxSize.x);
			if (window.maxSize.y > 0)
				newH = min(newH, cast(int) window.maxSize.y);
		}

		return Vector2U(cast(uint) max(1, newW), cast(uint) max(1, newH));
	}
}

@("SeatInteraction: move interaction applies delta to position")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginMove(window, Vector2I(100, 200), Vector2I(50, 60));

	Vector2I newPos;
	Vector2U newSize;
	auto ok = state.updateInteraction(Vector2I(130, 210), newPos, newSize);

	assert(ok);
	assert(newPos.x == 80 && newPos.y == 70);
}

@("SeatInteraction: resize right increases width")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginResize(window, Vector2I(100, 200), Vector2I(50, 60), Vector2U(400, 300), DecorationHit.ResizeRight);

	Vector2I newPos;
	Vector2U newSize;
	state.updateInteraction(Vector2I(150, 200), newPos, newSize);

	assert(newSize.x == 450);
	assert(newSize.y == 300);
	assert(newPos.x == 50);
}

@("SeatInteraction: resize left decreases width and adjusts position")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginResize(window, Vector2I(100, 200), Vector2I(50, 60), Vector2U(400, 300), DecorationHit.ResizeLeft);

	Vector2I newPos;
	Vector2U newSize;
	state.updateInteraction(Vector2I(80, 200), newPos, newSize);

	assert(newSize.x == 420);
	assert(newSize.y == 300);
	assert(newPos.x == 30);
}

@("SeatInteraction: resize bottom increases height")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginResize(window, Vector2I(100, 200), Vector2I(50, 60), Vector2U(400, 300), DecorationHit.ResizeBottom);

	Vector2I newPos;
	Vector2U newSize;
	state.updateInteraction(Vector2I(100, 260), newPos, newSize);

	assert(newSize.x == 400);
	assert(newSize.y == 360);
	assert(newPos.y == 60);
}

@("SeatInteraction: resize top decreases height and adjusts position")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginResize(window, Vector2I(100, 200), Vector2I(50, 60), Vector2U(400, 300), DecorationHit.ResizeTop);

	Vector2I newPos;
	Vector2U newSize;
	state.updateInteraction(Vector2I(100, 170), newPos, newSize);

	assert(newSize.y == 330);
	assert(newPos.y == 30);
}

@("SeatInteraction: resize topLeft adjusts both axes")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginResize(window, Vector2I(100, 200), Vector2I(50, 60), Vector2U(400, 300), DecorationHit.ResizeTopLeft);

	Vector2I newPos;
	Vector2U newSize;
	state.updateInteraction(Vector2I(80, 180), newPos, newSize);

	assert(newSize.x == 420 && newSize.y == 320);
	assert(newPos.x == 30 && newPos.y == 40);
}

@("SeatInteraction: resize bottomRight adjusts neither position axis")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginResize(window, Vector2I(100, 200), Vector2I(50, 60), Vector2U(400, 300), DecorationHit.ResizeBottomRight);

	Vector2I newPos;
	Vector2U newSize;
	state.updateInteraction(Vector2I(140, 250), newPos, newSize);

	assert(newSize.x == 440 && newSize.y == 350);
	assert(newPos.x == 50 && newPos.y == 60);
}

@("SeatInteraction: resize clamps to default min size")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginResize(window, Vector2I(100, 200), Vector2I(50, 60), Vector2U(200, 100), DecorationHit.ResizeLeft);

	Vector2I newPos;
	Vector2U newSize;
	state.updateInteraction(Vector2I(600, 200), newPos, newSize);

	assert(newSize.x == 100);
	assert(newSize.y == 100);
}

@("SeatInteraction: resize respects custom min size")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();
	window.minSize = Vector2U(200, 150);

	state.beginResize(window, Vector2I(100, 200), Vector2I(50, 60), Vector2U(400, 300), DecorationHit.ResizeBottomRight);

	Vector2I newPos;
	Vector2U newSize;
	state.updateInteraction(Vector2I(-200, -50), newPos, newSize);

	assert(newSize.x == 200 && newSize.y == 150);
}

@("SeatInteraction: resize respects max size")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();
	window.maxSize = Vector2U(500, 400);

	state.beginResize(window, Vector2I(100, 200), Vector2I(50, 60), Vector2U(400, 300), DecorationHit.ResizeBottomRight);

	Vector2I newPos;
	Vector2U newSize;
	state.updateInteraction(Vector2I(300, 400), newPos, newSize);

	assert(newSize.x == 500 && newSize.y == 400);
}

@("SeatInteraction: getResizePositionAdjustment for left edge")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginResize(window, Vector2I(0, 0), Vector2I(0, 0), Vector2U(400, 300), DecorationHit.ResizeLeft);

	auto adj = state.getResizePositionAdjustment(Vector2U(400, 300), Vector2U(350, 300));

	assert(adj.x == 50);
	assert(adj.y == 0);
}

@("SeatInteraction: getResizePositionAdjustment for top edge")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginResize(window, Vector2I(0, 0), Vector2I(0, 0), Vector2U(400, 300), DecorationHit.ResizeTop);

	auto adj = state.getResizePositionAdjustment(Vector2U(400, 300), Vector2U(400, 250));

	assert(adj.x == 0);
	assert(adj.y == 50);
}

@("SeatInteraction: getResizePositionAdjustment returns zero when not resizing")
unittest
{
	auto state = new SeatInteraction();
	auto adj = state.getResizePositionAdjustment(Vector2U(400, 300), Vector2U(350, 250));
	assert(adj.x == 0 && adj.y == 0);
}

@("SeatInteraction: endInteraction clears state")
unittest
{
	auto state = new SeatInteraction();
	auto window = new MockWindow();

	state.beginResize(window, Vector2I(0, 0), Vector2I(0, 0), Vector2U(400, 300), DecorationHit.ResizeRight);
	assert(state.interaction == InteractionType.Resize);
	assert(window.state.resizing);

	state.endInteraction();
	assert(state.interaction == InteractionType.None);
	assert(state.interactionView is null);
	assert(!window.state.resizing);
}

@("SeatInteraction: updateInteraction returns false when no interaction")
unittest
{
	auto state = new SeatInteraction();

	Vector2I newPos;
	Vector2U newSize;
	assert(!state.updateInteraction(Vector2I(0, 0), newPos, newSize));
}
