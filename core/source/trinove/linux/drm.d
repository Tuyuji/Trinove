// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.linux.drm;

//#define fourcc_code(a, b, c, d) \
//	((__u32)(a) | ((__u32)(b) << 8) | ((__u32)(c) << 16) | ((__u32)(d) << 24))
enum fourcc_code(char a, char b, char c, char d) = (cast(uint) a) | ((cast(uint) b) << 8) | ((cast(uint) c) << 16) | ((cast(
			uint) d) << 24);

// DRM pixel format fourcc codes (from <drm/drm_fourcc.h>).
enum DrmFormat : uint
{
	invalid = 0,
	ARGB8888 = fourcc_code!('A', 'R', '2', '4'), // [31:0] A:R:G:B 8:8:8:8 little endian
	XRGB8888 = fourcc_code!('X', 'R', '2', '4'), // [31:0] X:R:G:B 8:8:8:8 little endian
	ABGR8888 = fourcc_code!('A', 'B', '2', '4'), // [31:0] A:B:G:R 8:8:8:8 little endian
	XBGR8888 = fourcc_code!('X', 'B', '2', '4'), // [31:0] X:B:G:R 8:8:8:8 little endian
	RGBA8888 = fourcc_code!('R', 'A', '2', '4'), // [31:0] R:G:B:A 8:8:8:8 little endian
	BGRA8888 = fourcc_code!('B', 'A', '2', '4'), // [31:0] B:G:R:A 8:8:8:8 little endian
	XRGB2101010 = fourcc_code!('X', 'R', '3', '0'), // [31:0] X:R:G:B 2:10:10:10 little endian
	XBGR2101010 = fourcc_code!('X', 'B', '3', '0'), // [31:0] X:B:G:R 2:10:10:10 little endian
}

// format is big endian instead of little endian
enum DRM_FORMAT_BIG_ENDIAN = 1u << 31;

// From <drm/drm_fourcc.h> DRM_FORMAT_MOD_VENDOR_*.
enum DrmFormatModVendor : ulong
{
	none = 0x00,
	intel = 0x01,
	amd = 0x02,
	nvidia = 0x03,
	samsung = 0x04,
	qcom = 0x05,
	vivante = 0x06,
	broadcom = 0x07,
	arm = 0x08,
	allwinner = 0x09,
	amlogic = 0x0a,
	mtk = 0x0b,
	apple = 0x0c
}

enum fourcc_mod_code(DrmFormatModVendor vendor, ulong val) = (cast(ulong) vendor << 56) | (val & 0x00ffffffffffffffUL);

enum DRM_FORMAT_RESERVED = (1UL << 56) - 1;

// DRM format modifier: explicit invalid / unspecified modifier.
enum DRM_FORMAT_MOD_INVALID = fourcc_mod_code!(DrmFormatModVendor.none, DRM_FORMAT_RESERVED);

// DRM format modifier: linear (no tiling) layout.
enum DRM_FORMAT_MOD_LINEAR = fourcc_mod_code!(DrmFormatModVendor.none, 0);

ulong makedev(uint major, uint minor) @nogc nothrow pure
{
	return ((cast(ulong)(major) & 0x00000fffu) << 8) | ((cast(ulong)(major) & 0xfffff000u) << 32) | (
			(cast(ulong)(minor) & 0x000000ffu) << 0) | ((cast(ulong)(minor) & 0xffffff00u) << 12);
}
