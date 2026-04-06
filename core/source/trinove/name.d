// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.name;

struct Name
{
	ulong hash;
	debug string debugName;

	static ulong hashString(string str) pure nothrow @safe @nogc
	{
		// FNV-1a hash
		ulong hash = 0xcbf29ce484222325UL;
		foreach (char c; str)
		{
			hash ^= c;
			hash *= 0x100000001b3UL;
		}
		return hash;
	}

	private this(ulong hash)
	{
		this.hash = hash;
	}

	debug private this(ulong hash, string debugName)
	{
		this.hash = hash;
		this.debugName = debugName;
	}

	bool opEquals(const Name other) const pure nothrow @safe @nogc
	{
		return hash == other.hash;
	}

	int opCmp(const Name other) const pure nothrow @safe @nogc
	{
		if (hash < other.hash)
			return -1;
		if (hash > other.hash)
			return 1;
		return 0;
	}

	size_t toHash() const pure nothrow @safe @nogc
	{
		return cast(size_t) hash;
	}

	string toString() const
	{
		debug
		{
			return debugName;
		}
		else
		{
			import std.conv;

			return "Name(0x" ~ hash.to!string(16) ~ ")";
		}
	}

	bool isValid() const pure nothrow @safe @nogc
	{
		return hash != 0;
	}
}

template name(string str)
{
	private enum hash = Name.hashString(str);

	debug
	{
		enum Name name = Name(hash, str);
	}
	else
	{
		enum Name name = Name(hash);
	}
}

@("Name: hashString is consistent")
unittest
{
	auto h1 = Name.hashString("hello");
	auto h2 = Name.hashString("hello");
	assert(h1 == h2);
}

@("Name: different strings produce different hashes")
unittest
{
	auto h1 = Name.hashString("hello");
	auto h2 = Name.hashString("world");
	auto h3 = Name.hashString("Hello"); // case sensitive
	assert(h1 != h2);
	assert(h1 != h3);
}

@("Name: empty string has a defined hash")
unittest
{
	auto h = Name.hashString("");
	// FNV-1a offset basis, no bytes mixed in
	assert(h == 0xcbf29ce484222325UL);
}

@("Name: equality via opEquals")
unittest
{
	auto a = name!"test";
	auto b = name!"test";
	auto c = name!"other";
	assert(a == b);
	assert(a != c);
}

@("Name: comparison via opCmp")
unittest
{
	auto a = name!"aaa";
	auto b = name!"zzz";
	// They have different hashes, one must sort before the other
	assert((a < b) != (a > b)); // strictly ordered
	assert(a == a); // equal to self
}

@("Name: usable as associative array key")
unittest
{
	int[Name] map;
	auto key1 = name!"first";
	auto key2 = name!"second";

	map[key1] = 10;
	map[key2] = 20;

	assert(map[key1] == 10);
	assert(map[key2] == 20);
	assert(map.length == 2);
}

@("Name: compile-time template matches runtime hash")
unittest
{
	enum ct = name!"runtime_test";
	Name rt = Name(Name.hashString("runtime_test"));
	assert(ct == rt);
	assert(ct.hash == rt.hash);
}

@("Name: isValid distinguishes zero from non-zero")
unittest
{
	Name empty;
	assert(!empty.isValid); // default hash is 0

	auto valid = name!"something";
	assert(valid.isValid);
}
