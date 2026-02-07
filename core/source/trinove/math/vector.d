// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.math.vector;

struct TVector(T)
{
	T x = 0;
	T y = 0;
	T z = 0;

	string toString() const
	{
		import std.format : format;

		return format("TVector!%s(%s, %s, %s)", T.stringof, x, y, z);
	}

	static enum forward = TVector(T(1), T(0), T(0));
	static enum right = TVector(T(0), T(1), T(0));
	static enum up = TVector(T(0), T(0), T(1));

pragma(inline):
pure nothrow @safe @nogc:
	TVector opBinary(string op)(TVector rhs) const if (op == "+")
	{
		return TVector(cast(T)(x + rhs.x), cast(T)(y + rhs.y), cast(T)(z + rhs.z));
	}

	TVector opBinary(string op)(TVector rhs) const if (op == "-")
	{
		return TVector(cast(T)(x - rhs.x), cast(T)(y - rhs.y), cast(T)(z - rhs.z));
	}

	TVector opBinary(string op)(TVector rhs) const if (op == "*")
	{
		return TVector(cast(T)(x * rhs.x), cast(T)(y * rhs.y), cast(T)(z * rhs.z));
	}

	TVector opBinary(string op)(TVector rhs) const if (op == "/")
	{
		return TVector(cast(T)(x / rhs.x), cast(T)(y / rhs.y), cast(T)(z / rhs.z));
	}

	TVector opBinary(string op)(T scalar) const if (op == "*")
	{
		return TVector(cast(T)(x * scalar), cast(T)(y * scalar), cast(T)(z * scalar));
	}

	TVector opBinary(string op)(T scalar) const if (op == "/")
	{
		return TVector(cast(T)(x / scalar), cast(T)(y / scalar), cast(T)(z / scalar));
	}
}

struct TVector2(T)
{
	T x = 0;
	T y = 0;

	string toString() const
	{
		import std.format : format;

		return format("TVector2!%s(%s, %s)", T.stringof, x, y);
	}

pragma(inline):
pure nothrow @safe @nogc:
	TVector2 opBinary(string op)(TVector2 rhs) const if (op == "+")
	{
		return TVector2(cast(T)(x + rhs.x), cast(T)(y + rhs.y));
	}

	TVector2 opBinary(string op)(TVector2 rhs) const if (op == "-")
	{
		return TVector2(cast(T)(x - rhs.x), cast(T)(y - rhs.y));
	}

	TVector2 opBinary(string op)(TVector2 rhs) const if (op == "*")
	{
		return TVector2(cast(T)(x * rhs.x), cast(T)(y * rhs.y));
	}

	TVector2 opBinary(string op)(TVector2 rhs) const if (op == "/")
	{
		return TVector2(cast(T)(x / rhs.x), cast(T)(y / rhs.y));
	}

	TVector2 opBinary(string op)(T scalar) const if (op == "*")
	{
		return TVector2(cast(T)(x * scalar), cast(T)(y * scalar));
	}

	TVector2 opBinary(string op)(T scalar) const if (op == "/")
	{
		return TVector2(cast(T)(x / scalar), cast(T)(y / scalar));
	}
}

alias Vector = TVector!(double);
alias VectorF = TVector!(float);
alias VectorI = TVector!(int);

alias Vector2 = TVector2!(double);
alias Vector2F = TVector2!(float);
alias Vector2I = TVector2!(int);
alias Vector2U = TVector2!(uint);

@("TVector2: addition")
unittest
{
	auto a = Vector2I(3, 7);
	auto b = Vector2I(1, 2);
	auto r = a + b;
	assert(r.x == 4 && r.y == 9);
}

@("TVector2: subtraction")
unittest
{
	auto a = Vector2I(10, 5);
	auto b = Vector2I(3, 8);
	auto r = a - b;
	assert(r.x == 7 && r.y == -3);
}

@("TVector2: component-wise multiplication")
unittest
{
	auto a = Vector2I(3, 4);
	auto b = Vector2I(2, 5);
	auto r = a * b;
	assert(r.x == 6 && r.y == 20);
}

@("TVector2: component-wise division")
unittest
{
	auto a = Vector2I(10, 20);
	auto b = Vector2I(2, 5);
	auto r = a / b;
	assert(r.x == 5 && r.y == 4);
}

@("TVector2: scalar multiplication")
unittest
{
	auto v = Vector2I(3, 7);
	auto r = v * 4;
	assert(r.x == 12 && r.y == 28);
}

@("TVector2: scalar division")
unittest
{
	auto v = Vector2I(20, 10);
	auto r = v / 5;
	assert(r.x == 4 && r.y == 2);
}

@("TVector2: default initialization is zero")
unittest
{
	Vector2I v;
	assert(v.x == 0 && v.y == 0);
}

@("TVector2: float operations")
unittest
{
	auto a = Vector2F(1.5f, 2.5f);
	auto b = Vector2F(0.5f, 1.0f);
	auto r = a + b;
	assert(r.x == 2.0f && r.y == 3.5f);
}

@("TVector: addition")
unittest
{
	auto a = VectorI(1, 2, 3);
	auto b = VectorI(4, 5, 6);
	auto r = a + b;
	assert(r.x == 5 && r.y == 7 && r.z == 9);
}

@("TVector: subtraction")
unittest
{
	auto a = VectorI(10, 20, 30);
	auto b = VectorI(3, 7, 15);
	auto r = a - b;
	assert(r.x == 7 && r.y == 13 && r.z == 15);
}

@("TVector: scalar multiplication")
unittest
{
	auto v = VectorI(2, 3, 4);
	auto r = v * 3;
	assert(r.x == 6 && r.y == 9 && r.z == 12);
}

@("TVector: static direction constants")
unittest
{
	assert(VectorI.forward == VectorI(1, 0, 0));
	assert(VectorI.right == VectorI(0, 1, 0));
	assert(VectorI.up == VectorI(0, 0, 1));
}

@("TVector: default initialization is zero")
unittest
{
	VectorI v;
	assert(v.x == 0 && v.y == 0 && v.z == 0);
}

@("TVector2: unsigned subtraction wraps")
unittest
{
	// Document that unsigned vectors wrap on underflow
	auto a = Vector2U(5, 3);
	auto b = Vector2U(3, 5);
	auto r = a - b;
	assert(r.x == 2);
	// r.y wraps around (uint underflow) this is expected D behavior
	assert(r.y == uint.max - 1);
}
