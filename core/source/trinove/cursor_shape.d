// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.cursor_shape;

import trinove.protocols.cursor_shape_v1;
import trinove.seat : Seat, WaiPointer;
import trinove.log;
import wayland.server;

private string shapeToThemeKey(WpCursorShapeDeviceV1.Shape shape)
{
	final switch (shape)
	{
	case WpCursorShapeDeviceV1.Shape.default_:
		return "default";
	case WpCursorShapeDeviceV1.Shape.contextMenu:
		return "context-menu";
	case WpCursorShapeDeviceV1.Shape.help:
		return "help";
	case WpCursorShapeDeviceV1.Shape.pointer:
		return "pointer";
	case WpCursorShapeDeviceV1.Shape.progress:
		return "progress";
	case WpCursorShapeDeviceV1.Shape.wait:
		return "wait";
	case WpCursorShapeDeviceV1.Shape.cell:
		return "cell";
	case WpCursorShapeDeviceV1.Shape.crosshair:
		return "crosshair";
	case WpCursorShapeDeviceV1.Shape.text:
		return "text";
	case WpCursorShapeDeviceV1.Shape.verticalText:
		return "vertical-text";
	case WpCursorShapeDeviceV1.Shape.alias_:
		return "alias";
	case WpCursorShapeDeviceV1.Shape.copy:
		return "copy";
	case WpCursorShapeDeviceV1.Shape.move:
		return "move";
	case WpCursorShapeDeviceV1.Shape.noDrop:
		return "no-drop";
	case WpCursorShapeDeviceV1.Shape.notAllowed:
		return "not-allowed";
	case WpCursorShapeDeviceV1.Shape.grab:
		return "grab";
	case WpCursorShapeDeviceV1.Shape.grabbing:
		return "grabbing";
	case WpCursorShapeDeviceV1.Shape.eResize:
		return "e-resize";
	case WpCursorShapeDeviceV1.Shape.nResize:
		return "n-resize";
	case WpCursorShapeDeviceV1.Shape.neResize:
		return "ne-resize";
	case WpCursorShapeDeviceV1.Shape.nwResize:
		return "nw-resize";
	case WpCursorShapeDeviceV1.Shape.sResize:
		return "s-resize";
	case WpCursorShapeDeviceV1.Shape.seResize:
		return "se-resize";
	case WpCursorShapeDeviceV1.Shape.swResize:
		return "sw-resize";
	case WpCursorShapeDeviceV1.Shape.wResize:
		return "w-resize";
	case WpCursorShapeDeviceV1.Shape.ewResize:
		return "ew-resize";
	case WpCursorShapeDeviceV1.Shape.nsResize:
		return "ns-resize";
	case WpCursorShapeDeviceV1.Shape.neswResize:
		return "nesw-resize";
	case WpCursorShapeDeviceV1.Shape.nwseResize:
		return "nwse-resize";
	case WpCursorShapeDeviceV1.Shape.colResize:
		return "col-resize";
	case WpCursorShapeDeviceV1.Shape.rowResize:
		return "row-resize";
	case WpCursorShapeDeviceV1.Shape.allScroll:
		return "all-scroll";
	case WpCursorShapeDeviceV1.Shape.zoomIn:
		return "zoom-in";
	case WpCursorShapeDeviceV1.Shape.zoomOut:
		return "zoom-out";
	case WpCursorShapeDeviceV1.Shape.dndAsk:
		return "dnd-ask";
	case WpCursorShapeDeviceV1.Shape.allResize:
		return "all-resize";
	}
}

class WaiCursorShapeDevice : WpCursorShapeDeviceV1
{
	private Seat _seat;

	this(Seat seat, WlClient cl, uint id)
	{
		_seat = seat;
		super(cl, ver, id);
		addDestroyListener((WlResource) { _seat = null; });
	}

	override protected void destroy(WlClient cl)
	{
	}

	override protected void setShape(WlClient cl, uint serial, WpCursorShapeDeviceV1.Shape shape)
	{
		if (_seat is null)
			return;
		if (!_seat.isValidCursorSerial(cl, serial))
			return;
		_seat.setClientCursorShape(shapeToThemeKey(shape));
	}
}

class WaiCursorShapeManager : WpCursorShapeManagerV1
{
	this(WlDisplay display)
	{
		super(display, ver);
	}

	override protected void destroy(WlClient cl, Resource res)
	{
	}

	override protected WpCursorShapeDeviceV1 getPointer(WlClient cl, Resource res, uint id, WlResource pointer)
	{
		auto waiPointer = cast(WaiPointer) pointer;
		if (waiPointer is null)
		{
			res.postError(0, "Invalid pointer resource");
			return null;
		}

		return new WaiCursorShapeDevice(waiPointer.seat, cl, id);
	}

	override protected WpCursorShapeDeviceV1 getTabletToolV2(WlClient cl, Resource res, uint id, WlResource tabletTool)
	{
		// Tablet tools not yet supported
		return new WaiCursorShapeDevice(null, cl, id);
	}
}
