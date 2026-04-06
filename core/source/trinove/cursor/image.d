// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.cursor.image;

import trinove.math;
import trinove.gpu.texture : Texture2D;

// Per-frame animation metadata.
struct CursorFrame
{
	uint durationMs;
}

// A cursor image, either a single static frame or an animated sequence.
class CursorImage
{
	// Atlas texture (all frames in a horizontal strip). Format: bgra8Unorm.
	// May be null if GPU upload has not happened yet.
	Texture2D texture;

	// Raw BGRA pixel data for every frame, concatenated in frame order.
	// Length = frameSize.x * frameSize.y * 4 * frameCount.
	const(ubyte)[] pixels;

	// Dimensions of a single cursor frame.
	Vector2U frameSize;

	// Hotspot offset from the top-left corner of a frame, same for all frames.
	Vector2I hotspot;

	CursorFrame[] frames;

	@property bool isAnimated() const => frames.length > 1;

	@property uint frameCount() const => cast(uint) frames.length;

	// For hardware cursor plane upload.
	const(ubyte)[] framePixels(uint index) const
	{
		assert(index < frames.length, "frame index out of range");
		immutable bytesPerFrame = frameSize.x * frameSize.y * 4;
		immutable offset = index * bytesPerFrame;
		return pixels[offset .. offset + bytesPerFrame];
	}

	// X pixel offset of frame index within the atlas texture.
	uint atlasX(uint index) const => index * frameSize.x;

	// UV srcRect [u0,v0,u1,v1] for a given frame index.
	float[4] frameUVRect(uint index) const
	{
		immutable float u0 = cast(float) index / frames.length;
		immutable float u1 = cast(float)(index + 1) / frames.length;
		return [u0, 0.0f, u1, 1.0f];
	}

	// Construct a static single frame cursor image.
	this(const(ubyte)[] pixels, Vector2U size, Vector2I hotspot, uint durationMs = 0)
	{
		this.pixels = pixels;
		this.frameSize = size;
		this.hotspot = hotspot;
		this.frames = [CursorFrame(durationMs)];
	}

	// Construct an animated cursor image.
	this(const(ubyte)[] pixels, Vector2U frameSize, Vector2I hotspot, CursorFrame[] frames)
	{
		this.pixels = pixels;
		this.frameSize = frameSize;
		this.hotspot = hotspot;
		this.frames = frames;
	}
}
