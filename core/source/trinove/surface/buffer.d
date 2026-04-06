// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.surface.buffer;

import trinove.math.vector;
import trinove.gpu.texture : Texture2D;
import trinove.gpu.format : PixelFormat;
import trinove.gpu.itexture : ITexture;
import wayland.server.protocol;
import wayland.server.shm;
import trinove.util : onDestroyCallDestroy;
import wayland.server;
import wayland.native.server;
import std.exception : enforce;
import core.memory;

interface IWaylandBuffer
{
	Vector2U getImageSize();
	ITexture getITexture();
	void fetch(); // Prepare buffer data for use
	void release(); // Finished using for now.

	// Copy raw pixel data for HW cursor upload. Returns null if unavailable.
	const(ubyte)[] getPixelData();
}

private __gshared Texture2D[4] _cpuTexPool;
private __gshared int _cpuTexPoolCount = 0;

private Texture2D acquireCpuTex(uint w, uint h, PixelFormat fmt)
{
	foreach (i; 0 .. _cpuTexPoolCount)
	{
		if (!_cpuTexPool[i].needsRecreate(w, h, fmt))
		{
			auto t = _cpuTexPool[i];
			_cpuTexPool[i] = _cpuTexPool[--_cpuTexPoolCount];
			_cpuTexPool[_cpuTexPoolCount] = null;
			return t;
		}
	}

	if (_cpuTexPoolCount > 0)
	{
		auto t = _cpuTexPool[--_cpuTexPoolCount];
		_cpuTexPool[_cpuTexPoolCount] = null;
		t.recreate(w, h, fmt);
		return t;
	}
	return new Texture2D(w, h, fmt);
}

private void releaseCpuTex(Texture2D t)
{
	if (_cpuTexPoolCount < cast(int) _cpuTexPool.length)
		_cpuTexPool[_cpuTexPoolCount++] = t;
	else
		t.destroy();
}

class CpuBuffer : WlBuffer, IWaylandBuffer
{
	WlShmBuffer shmBuffer;
	Vector2U size;
	size_t stride;
	WlShm.Format format;

	Texture2D _texture;
	bool _destroyed : 1; // client sent wl_buffer.destroy
	bool _released  : 1; // compositor called release()

	this(wayland.native.server.wl_resource* natRes)
	{
		_destroyed = false;
		_released = false;
		super(natRes);
		mixin(onDestroyCallDestroy);
	}

	override void destroy(WlClient cl)
	{
		_destroyed = true;
		// If the compositor already released this buffer then we can free the texture now.
		if (_released && _texture !is null)
		{
			releaseCpuTex(_texture);
			_texture = null;
		}
	}

	void fetch()
	{
		_released = false;
		import trinove.gpu.format : fromShm;
		import trinove.log : logWarn;

		shmBuffer = enforce(WlShmBuffer.get(this));
		size.x = shmBuffer.width;
		size.y = shmBuffer.height;
		stride = shmBuffer.stride;
		format = shmBuffer.format;

		auto texFormat = fromShm(format);

		shmBuffer.beginAccess();
		scope (exit)
			shmBuffer.endAccess();

		auto data = shmBuffer.data();
		if (data.ptr is null)
		{
			logWarn("CpuBuffer.fetch: shm data pointer is null for %dx%d buffer", size.x, size.y);
			return;
		}

		auto dataT = cast(const(ubyte)[]) data[0 .. stride * size.y];

		if (_texture is null)
		{
			_texture = acquireCpuTex(size.x, size.y, texFormat);
		}
		else if (_texture.needsRecreate(size.x, size.y, texFormat))
		{
			releaseCpuTex(_texture);
			_texture = acquireCpuTex(size.x, size.y, texFormat);
		}

		_texture.upload(dataT, cast(uint) stride);
	}

	void release()
	{
		_released = true;
		if (!_destroyed)
			sendRelease();

		//if we released and client wanted to destroy then actually destroy now
		if(_destroyed && _texture !is null)
		{
			destroy(null);
		}
	}

	ITexture getITexture()
	{
		return _texture;
	}

	Vector2U getImageSize()
	{
		return size;
	}

	const(ubyte)[] getPixelData()
	{
		if (shmBuffer is null)
			return null;

		shmBuffer.beginAccess();
		scope (exit)
			shmBuffer.endAccess();

		auto data = shmBuffer.data();
		if (data.ptr is null)
			return null;

		return (cast(const(ubyte)[]) data[0 .. stride * size.y]).dup;
	}
}
