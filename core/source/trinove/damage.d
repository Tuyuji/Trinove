// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan
module trinove.damage;

import trinove.math.rect;

struct DamageList
{
	debug
	{
		// Global stats across all DamageList instances.
		__gshared size_t globalActiveCount;
		__gshared size_t globalTotalCapacity; // in rects
		__gshared size_t globalPeakCapacity;
	}

	private Rect* _ptr = null;
	private size_t _len = 0;
	private size_t _cap = 0;

	// Read-only slice of current damage rects.
	@property Rect[] rects()
	{
		return _len > 0 ? _ptr[0 .. _len] : null;
	}

	@property bool empty() const
	{
		return _len == 0;
	}

	@property size_t length() const
	{
		return _len;
	}

	// Add a rect, merging with nearby or overlapping existing rects.
	// When mergeThreshold is 0, only intersecting rects are merged.
	void add(Rect region, int mergeThreshold = 0)
	{
		auto buf = _len > 0 ? _ptr[0 .. _len] : [];
		_len = mergeRect(buf, _len, region, mergeThreshold);
		append(region);
	}

	// Add without merging.
	void append(Rect region)
	{
		ensureCap(_len + 1);
		_ptr[_len++] = region;
	}

	void clear()
	{
		_len = 0;
	}

	// Clear and set to a single rect covering the given bounds.
	void setFull(Rect bounds)
	{
		ensureCap(1);
		_ptr[0] = bounds;
		_len = 1;
	}

	// Swap contents with another DamageList. Clears `other` after swap.
	void swapWith(ref DamageList other)
	{
		auto tp = _ptr, tl = _len, tc = _cap;
		_ptr = other._ptr;
		_len = other._len;
		_cap = other._cap;
		other._ptr = tp;
		other._len = tl;
		other._cap = tc;
		other._len = 0;
	}

	// Returns a range of rects intersected with bounds, skipping empty results.
	auto clampedTo(Rect bounds)
	{
		struct ClampedRange
		{
			Rect* ptr;
			size_t len;
			Rect bounds;
			size_t i;
			Rect current;

			@property bool empty()
			{
				advance();
				return i >= len;
			}

			@property Rect front()
			{
				advance();
				return current;
			}

			void popFront()
			{
				i++;
				_advanced = false;
			}

			private bool _advanced;
			private void advance()
			{
				if (_advanced)
					return;
				_advanced = true;
				while (i < len)
				{
					current = ptr[i].intersection(bounds);
					if (!current.isEmpty)
						return;
					i++;
				}
			}
		}

		return ClampedRange(_ptr, _len, bounds, 0, Rect.init, false);
	}

	int opApply(scope int delegate(Rect) dg)
	{
		foreach (i; 0 .. _len)
		{
			if (auto result = dg(_ptr[i]))
				return result;
		}
		return 0;
	}

	int opApply(scope int delegate(size_t, Rect) dg)
	{
		foreach (i; 0 .. _len)
		{
			if (auto result = dg(i, _ptr[i]))
				return result;
		}
		return 0;
	}

	void release()
	{
		import core.stdc.stdlib : free;

		if (_ptr !is null)
		{
			debug
			{
				globalActiveCount--;
				globalTotalCapacity -= _cap;
			}
			free(_ptr);
			_ptr = null;
		}
		_len = 0;
		_cap = 0;
	}

	private void ensureCap(size_t needed)
	{
		if (needed <= _cap)
			return;

		import core.stdc.stdlib : realloc;

		auto oldCap = _cap;
		auto newCap = _cap < 8 ? 8 : _cap;
		while (newCap < needed)
			newCap *= 2;
		_ptr = cast(Rect*) realloc(_ptr, Rect.sizeof * newCap);
		_cap = newCap;

		debug
		{
			if (oldCap == 0)
				globalActiveCount++;
			globalTotalCapacity += newCap - oldCap;
			if (globalTotalCapacity > globalPeakCapacity)
				globalPeakCapacity = globalTotalCapacity;
		}
	}
}

// Arena allocator for damage rects. Reset per frame to bulk-free all allocations.
// Uses malloc/realloc, zero GC pressure. Caller must clear all NodeDamageLists
// before calling reset() (propagateDamage walks the tree anyway).
struct DamageArena
{
	private Rect* _buffer = null;
	private size_t _used = 0;
	private size_t _cap = 0;

	debug
	{
		size_t peakUsed;
		size_t reallocCount;
	}

	void initialize(size_t initialCap = 4096)
	{
		import core.stdc.stdlib : malloc;

		_cap = initialCap;
		_buffer = cast(Rect*) malloc(Rect.sizeof * initialCap);
		_used = 0;
	}

	void release()
	{
		import core.stdc.stdlib : free;

		if (_buffer !is null)
		{
			free(_buffer);
			_buffer = null;
		}
		_used = 0;
		_cap = 0;
	}

	// Bump-allocate n contiguous rects. Returns starting index.
	size_t alloc(size_t n)
	{
		if (_used + n > _cap)
			grow(_used + n);
		auto idx = _used;
		_used += n;
		debug
		{
			if (_used > peakUsed)
				peakUsed = _used;
		}
		return idx;
	}

	void set(size_t idx, Rect r)
	{
		_buffer[idx] = r;
	}

	// Get a mutable slice of arena-allocated rects.
	Rect[] slice(size_t offset, size_t count)
	{
		return _buffer[offset .. offset + count];
	}

	@property size_t used() const
	{
		return _used;
	}

	@property size_t capacity() const
	{
		return _cap;
	}

	// Reset the bump pointer. All prior slices become invalid.
	// Caller must have cleared all NodeDamageLists first.
	void reset()
	{
		_used = 0;
	}

	private void grow(size_t needed)
	{
		import core.stdc.stdlib : realloc;

		auto newCap = _cap < 4096 ? 4096 : _cap;
		while (newCap < needed)
			newCap *= 2;
		_buffer = cast(Rect*) realloc(_buffer, Rect.sizeof * newCap);
		_cap = newCap;
		debug reallocCount++;
	}
}

// Non-GC damage list backed by a shared DamageArena.
// Used by scene nodes. The owning scene graph clears all node damage
// during propagation, then resets the arena.
struct NodeDamageList
{
	DamageArena* arena;
	private size_t _offset;
	private size_t _count;

	@property bool empty() const
	{
		return _count == 0;
	}

	@property size_t length() const
	{
		return _count;
	}

	// Add a rect, merging with nearby or overlapping existing rects.
	void add(Rect region, int mergeThreshold = 0)
	{
		if (arena is null)
			return;

		enum maxBuf = 32;
		Rect[maxBuf] buf = void;
		size_t count = _count;

		if (count >= maxBuf)
		{
			// Overflow: union everything into a single rect
			auto existing = arena.slice(_offset, count);
			auto all = existing[0];
			foreach (i; 1 .. count)
				all = all.unionWith(existing[i]);
			region = region.unionWith(all);
			count = 0;
		}
		else if (count > 0)
		{
			buf[0 .. count] = arena.slice(_offset, count);
		}

		count = mergeRect(buf, count, region, mergeThreshold);
		buf[count++] = region;

		_offset = arena.alloc(count);
		arena.slice(_offset, count)[] = buf[0 .. count];
		_count = count;
	}

	// Clear and set to a single rect covering the given bounds.
	void setFull(Rect bounds)
	{
		if (arena is null)
			return;
		_offset = arena.alloc(1);
		arena.set(_offset, bounds);
		_count = 1;
	}

	void clear()
	{
		_count = 0;
	}

	int opApply(scope int delegate(Rect) dg)
	{
		if (_count == 0)
			return 0;
		foreach (r; arena.slice(_offset, _count))
		{
			if (auto result = dg(r))
				return result;
		}
		return 0;
	}

	int opApply(scope int delegate(size_t, Rect) dg)
	{
		if (_count == 0)
			return 0;
		foreach (i, r; arena.slice(_offset, _count))
		{
			if (auto result = dg(i, r))
				return result;
		}
		return 0;
	}
}

@("DamageList: add merges intersecting rects")
unittest
{
	DamageList dl;
	dl.add(Rect(0, 0, 100, 100));
	dl.add(Rect(50, 50, 100, 100));
	assert(dl.length == 1, "Intersecting rects should merge");
	assert(dl.rects[0] == Rect(0, 0, 150, 150));
}

@("DamageList: add merges nearby rects with threshold")
unittest
{
	DamageList dl;
	dl.add(Rect(0, 0, 100, 100), 32);
	// 20px gap, within threshold of 32
	dl.add(Rect(120, 0, 100, 100), 32);
	assert(dl.length == 1, "Nearby rects within threshold should merge");
	assert(dl.rects[0] == Rect(0, 0, 220, 100));
}

@("DamageList: add keeps distant rects separate")
unittest
{
	DamageList dl;
	dl.add(Rect(0, 0, 100, 100));
	dl.add(Rect(200, 200, 100, 100));
	assert(dl.length == 2, "Distant rects should not merge");
}

@("DamageList: clear and setFull")
unittest
{
	DamageList dl;
	dl.add(Rect(0, 0, 50, 50));
	dl.add(Rect(200, 200, 50, 50));
	assert(dl.length == 2);

	dl.setFull(Rect(0, 0, 1920, 1080));
	assert(dl.length == 1);
	assert(dl.rects[0] == Rect(0, 0, 1920, 1080));

	dl.clear();
	assert(dl.empty);
}

@("DamageList: swapWith")
unittest
{
	DamageList a, b;
	a.append(Rect(1, 2, 3, 4));
	a.append(Rect(5, 6, 7, 8));
	b.append(Rect(10, 20, 30, 40));

	a.swapWith(b);
	assert(a.length == 1);
	assert(a.rects[0] == Rect(10, 20, 30, 40));
	assert(b.empty, "swapWith should clear other");
}

@("DamageList: clampedTo filters and clips")
unittest
{
	DamageList dl;
	dl.append(Rect(0, 0, 100, 100));
	dl.append(Rect(50, 50, 100, 100));
	dl.append(Rect(500, 500, 100, 100)); // outside bounds

	auto bounds = Rect(0, 0, 120, 120);
	Rect[] results;
	foreach (r; dl.clampedTo(bounds))
		results ~= r;

	assert(results.length == 2, "Rect outside bounds should be filtered");
	assert(results[0] == Rect(0, 0, 100, 100));
	assert(results[1] == Rect(50, 50, 70, 70));
}

@("DamageList: opApply foreach")
unittest
{
	DamageList dl;
	dl.append(Rect(0, 0, 10, 10));
	dl.append(Rect(20, 20, 30, 30));

	int count;
	foreach (r; dl)
		count++;
	assert(count == 2);

	size_t lastIdx;
	foreach (i, r; dl)
		lastIdx = i;
	assert(lastIdx == 1);
}

@("DamageArena: alloc and reset")
unittest
{
	DamageArena arena;
	arena.initialize(4);
	scope (exit)
		arena.release();

	auto idx = arena.alloc(2);
	assert(idx == 0);
	assert(arena.used == 2);

	arena.set(0, Rect(1, 2, 3, 4));
	arena.set(1, Rect(5, 6, 7, 8));
	assert(arena.slice(0, 2)[0] == Rect(1, 2, 3, 4));
	assert(arena.slice(0, 2)[1] == Rect(5, 6, 7, 8));

	arena.reset();
	assert(arena.used == 0);
}

@("DamageArena: grows on demand")
unittest
{
	DamageArena arena;
	arena.initialize(2);
	scope (exit)
		arena.release();

	arena.alloc(10);
	assert(arena.used == 10);
}

@("NodeDamageList: empty without arena")
unittest
{
	NodeDamageList dl;
	assert(dl.empty);
	assert(dl.length == 0);
}

@("NodeDamageList: add and iterate")
unittest
{
	DamageArena arena;
	arena.initialize();
	scope (exit)
		arena.release();

	NodeDamageList dl;
	dl.arena = &arena;

	dl.add(Rect(0, 0, 100, 100));
	assert(!dl.empty);
	assert(dl.length == 1);

	int count;
	foreach (r; dl)
		count++;
	assert(count == 1);
}

@("NodeDamageList: add merges intersecting rects")
unittest
{
	DamageArena arena;
	arena.initialize();
	scope (exit)
		arena.release();

	NodeDamageList dl;
	dl.arena = &arena;

	dl.add(Rect(0, 0, 100, 100));
	dl.add(Rect(50, 50, 100, 100));
	assert(dl.length == 1);
}

@("NodeDamageList: clear and setFull")
unittest
{
	DamageArena arena;
	arena.initialize();
	scope (exit)
		arena.release();

	NodeDamageList dl;
	dl.arena = &arena;

	dl.add(Rect(0, 0, 50, 50));
	dl.add(Rect(200, 200, 50, 50));
	assert(dl.length == 2);

	dl.setFull(Rect(0, 0, 1920, 1080));
	assert(dl.length == 1);
	foreach (r; dl)
		assert(r == Rect(0, 0, 1920, 1080));

	dl.clear();
	assert(dl.empty);
}

@("NodeDamageList: no-op without arena")
unittest
{
	NodeDamageList dl;
	dl.add(Rect(0, 0, 10, 10));
	assert(dl.empty);

	dl.setFull(Rect(0, 0, 100, 100));
	assert(dl.empty);
}
