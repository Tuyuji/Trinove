// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.util;

import wayland.server : WlResource;
import wayland.native.server : wl_resource_get_client;
import wayland.native.util : wl_array, wl_array_add;
import wayland.util : ObjectCache;

// Check if a WlResource's client is still valid.
// Calling client() when its not in the ObjectCache will trigger an assert, so this is a way around it.
bool isClientValid(WlResource res)
{
	if (res is null)
		return false;
	auto natCl = wl_resource_get_client(res.native);
	if (natCl is null)
		return false;
	return ObjectCache.get(natCl) !is null;
}

int getResVersion(WlResource res)
{
	import wayland.native.server : wl_resource_get_version;

	return wl_resource_get_version(res.native);
}

// Returns true if all bits in `flag` are set in `state`.
pragma(inline, true) bool isFlagSet(E)(E state, E flag) @nogc nothrow pure if (is(E == enum))
{
	return (state & flag) != 0;
}

enum onDestroyCallDestroy = `addDestroyListener((WlResource r) { (cast(typeof(this))r).destroy(null); });`;

enum onDestroyCallRelease = `addDestroyListener((WlResource r) { (cast(typeof(this))r).release(null); });`;

// Append a value to a wl_array.
pragma(inline, true) void wlArrayAdd(T)(wl_array* array, T value)
{
	auto ptr = cast(T*) wl_array_add(array, T.sizeof);
	if (ptr)
		*ptr = value;
}
