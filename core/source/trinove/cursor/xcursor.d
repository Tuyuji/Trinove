// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.cursor.xcursor;

import trinove.cursor.image;
import trinove.math;
import trinove.gpu.texture : Texture2D;
import trinove.gpu.format : PixelFormat;
import trinove.log;

private:

enum XCURSOR_MAGIC = 0x72756358u; // "Xcur" LE
enum XCURSOR_IMAGE_TYPE = 0xFFFD0002u;
enum XCURSOR_CHUNK_HEADER = 36u; // bytes before pixel data in an image chunk

uint readU32LE(const(ubyte)[] data, size_t off)
{
	return data[off] | (cast(uint) data[off + 1] << 8) | (cast(uint) data[off + 2] << 16) | (cast(uint) data[off + 3] << 24);
}

uint absDiff(uint a, uint b) => a > b ? a - b : b - a;

public:

// Load a cursor from an XCursor binary file.
//
// XCursor files hold multiple nominal sizes; this picks the one closest to
// `preferredSize`. If multiple frames share the same nominal size they form
// an animated sequence stored in a horizontal-strip atlas.
//
// Pixel memory layout note: XCursor stores pixels as little-endian ARGB
// uint32 (0xAARRGGBB). In memory on LE hardware the byte order is
// [B, G, R, A], which is exactly bgra8Unorm. No channel swap is needed.
//
// Returns null on any parse failure.
CursorImage loadXCursorFile(string path, uint preferredSize = 24)
{
	import std.mmfile : MmFile;

	MmFile mf;
	try
		mf = new MmFile(path);
	catch (Exception e)
	{
		logDebug("xcursor: cannot open '%s': %s", path, e.msg);
		return null;
	}
	scope (exit)
		destroy(mf);

	auto data = cast(const(ubyte)[]) mf[];

	if (data.length < 16 || readU32LE(data, 0) != XCURSOR_MAGIC)
	{
		logDebug("xcursor: bad magic in '%s'", path);
		return null;
	}

	immutable uint ntoc = readU32LE(data, 12);
	immutable uint tocBase = 16;

	// Scan TOC to find the best nominal size.
	uint bestSize = 0;
	foreach (i; 0 .. ntoc)
	{
		immutable off = tocBase + i * 12;
		if (off + 12 > data.length)
			break;
		if (readU32LE(data, off) != XCURSOR_IMAGE_TYPE)
			continue;
		immutable sub = readU32LE(data, off + 4);
		if (bestSize == 0 || absDiff(sub, preferredSize) < absDiff(bestSize, preferredSize))
			bestSize = sub;
	}
	if (bestSize == 0)
		return null;

	// Collect all image chunks at bestSize.
	struct RawFrame
	{
		uint w, h, xhot, yhot, delay;
		size_t pixelOffset; // byte offset into `data`
	}

	RawFrame[32] rawBuf = void;
	uint nFrames;
	foreach (i; 0 .. ntoc)
	{
		if (nFrames >= rawBuf.length)
			break;
		immutable off = tocBase + i * 12;
		if (off + 12 > data.length)
			break;
		if (readU32LE(data, off) != XCURSOR_IMAGE_TYPE)
			continue;
		if (readU32LE(data, off + 4) != bestSize)
			continue;

		immutable pos = readU32LE(data, off + 8);
		if (pos + XCURSOR_CHUNK_HEADER > data.length)
			continue;

		immutable fw = readU32LE(data, pos + 16);
		immutable fh = readU32LE(data, pos + 20);
		immutable pixelBytes = fw * fh * 4;
		if (pos + XCURSOR_CHUNK_HEADER + pixelBytes > data.length)
			continue;

		rawBuf[nFrames++] = RawFrame(fw, fh, readU32LE(data, pos + 24), readU32LE(data, pos + 28), readU32LE(data,
				pos + 32), pos + XCURSOR_CHUNK_HEADER,);
	}
	if (nFrames == 0)
		return null;

	auto raw = rawBuf[0 .. nFrames];
	immutable uint w = raw[0].w, h = raw[0].h;
	immutable uint nf = nFrames;

	// Build sequential pixel buffer for framePixels() (HW cursor access).
	ubyte[] seqPixels = new ubyte[w * h * 4 * nf];
	foreach (fi, ref f; raw)
	{
		immutable bytesPerFrame = w * h * 4;
		seqPixels[fi * bytesPerFrame .. (fi + 1) * bytesPerFrame] = data[f.pixelOffset .. f.pixelOffset + bytesPerFrame];
	}

	auto tex = new Texture2D(w * nf, h, PixelFormat.bgra8Unorm);

	if (nf == 1)
	{
		tex.upload(seqPixels, w * 4);
		auto img = new CursorImage(seqPixels, Vector2U(w, h), Vector2I(raw[0].xhot, raw[0].yhot), raw[0].delay == 0 ? 50 : raw[0]
				.delay);
		img.texture = tex;
		return img;
	}

	CursorFrame[] cframes = new CursorFrame[nf];
	foreach (fi, ref f; raw)
		cframes[fi] = CursorFrame(f.delay == 0 ? 50 : f.delay);

	immutable uint atlasW = w * nf;
	ubyte[] atlasPixels = new ubyte[atlasW * h * 4];
	foreach (fi, ref f; raw)
	{
		immutable bytesPerRow = w * 4;
		foreach (row; 0 .. h)
		{
			immutable src = f.pixelOffset + row * bytesPerRow;
			immutable dst = (row * atlasW + fi * w) * 4;
			atlasPixels[dst .. dst + bytesPerRow] = data[src .. src + bytesPerRow];
		}
	}
	tex.upload(atlasPixels, atlasW * 4);

	auto img = new CursorImage(seqPixels, Vector2U(w, h), Vector2I(raw[0].xhot, raw[0].yhot), cframes);
	img.texture = tex;
	return img;
}
