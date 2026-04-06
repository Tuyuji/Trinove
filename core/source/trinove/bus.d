// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan
module trinove.bus;

// Convenience mixin to define an event struct in one line.
// Usage: mixin DefineEvent!("OnOutputAdded", ManagedOutput);
mixin template DefineEvent(string name, Args...)
{
	mixin("struct " ~ name ~ " { mixin EventBus!Args; }");
}

// Convenience mixin to define an event struct with return values.
// Usage: mixin DefineEventResult!("OnInputEvent", bool, Seat, InputEvent);
mixin template DefineEventResult(string name, Result, Args...)
{
	mixin("struct " ~ name ~ " { mixin EventBusResult!(Result, Args); }");
}

// Mixin for fire-and-forget events.
// Usage:
//   struct OnOutputAdded { mixin EventBus!ManagedOutput; }
mixin template EventBus(Args...)
{
	import core.sync.mutex : Mutex;

	alias Handler = void delegate(Args);

	private __gshared Handler[] _handlers;
	private __gshared Mutex _mutex;

	private static Mutex ensureMutex()
	{
		if (_mutex is null)
			_mutex = new Mutex();
		return _mutex;
	}

	static void subscribe(Handler handler)
	{
		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();
		_handlers ~= handler;
	}

	static void unsubscribe(Handler handler)
	{
		import std.algorithm : remove;

		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();
		_handlers = _handlers.remove!(h => h is handler);
	}

	static void fire(Args args)
	{
		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();
		foreach (handler; _handlers)
			handler(args);
	}

	static void clear()
	{
		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();
		_handlers = [];
	}

	static size_t handlerCount()
	{
		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();
		return _handlers.length;
	}
}

// Mixin for events with return values.
// Usage:
//   struct OnInputEvent { mixin EventBusResult!(bool, Seat, InputEvent); }
mixin template EventBusResult(Result, Args...)
{
	import core.sync.mutex : Mutex;

	alias Handler = Result delegate(Args);

	private __gshared Handler[] _handlers;
	private __gshared Mutex _mutex;

	private static Mutex ensureMutex()
	{
		if (_mutex is null)
			_mutex = new Mutex();
		return _mutex;
	}

	static void subscribe(Handler handler)
	{
		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();
		_handlers ~= handler;
	}

	static void unsubscribe(Handler handler)
	{
		import std.algorithm : remove;

		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();
		_handlers = _handlers.remove!(h => h is handler);
	}

	static Result[] fire(Args args)
	{
		import std.array : uninitializedArray;

		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();
		auto results = uninitializedArray!(Result[])(_handlers.length);
		foreach (i, handler; _handlers)
			results[i] = handler(args);
		return results;
	}

	// Fire until a handler returns a non-default result, then stop.
	static Result fireUntil(Args args)
	{
		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();

		foreach (handler; _handlers)
		{
			Result r = handler(args);
			if (r != Result.init)
				return r;
		}
		return Result.init;
	}

	static void clear()
	{
		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();
		_handlers = [];
	}

	static size_t handlerCount()
	{
		ensureMutex();
		_mutex.lock();
		scope (exit)
			_mutex.unlock();
		return _handlers.length;
	}
}

struct TestEvent
{
	mixin EventBus!();
}

@("EventBus: subscribe and fire")
unittest
{
	TestEvent.clear();
	int callCount = 0;

	TestEvent.subscribe(() { callCount++; });
	scope (exit)
		TestEvent.clear();

	TestEvent.fire();
	assert(callCount == 1);

	TestEvent.fire();
	assert(callCount == 2);
}

@("EventBus: multiple subscribers")
unittest
{
	TestEvent.clear();
	int count1 = 0;
	int count2 = 0;

	TestEvent.subscribe(() { count1++; });
	TestEvent.subscribe(() { count2++; });
	scope (exit)
		TestEvent.clear();

	TestEvent.fire();
	assert(count1 == 1);
	assert(count2 == 1);
}

@("EventBus: unsubscribe")
unittest
{
	TestEvent.clear();
	int callCount = 0;
	void handler()
	{
		callCount++;
	}

	TestEvent.subscribe(&handler);
	scope (exit)
		TestEvent.clear();

	TestEvent.fire();
	assert(callCount == 1);

	TestEvent.unsubscribe(&handler);
	TestEvent.fire();
	assert(callCount == 1);
}

struct TestEventWithArgs
{
	mixin EventBus!(int, string);
}

@("EventBus: fire with arguments")
unittest
{
	TestEventWithArgs.clear();
	int receivedInt;
	string receivedString;

	TestEventWithArgs.subscribe((i, s) { receivedInt = i; receivedString = s; });
	scope (exit)
		TestEventWithArgs.clear();

	TestEventWithArgs.fire(42, "hello");
	assert(receivedInt == 42);
	assert(receivedString == "hello");
}

@("EventBus: clear removes all handlers")
unittest
{
	TestEvent.clear();
	int callCount = 0;

	TestEvent.subscribe(() { callCount++; });
	TestEvent.subscribe(() { callCount++; });

	TestEvent.clear();
	TestEvent.fire();
	assert(callCount == 0);
}

struct TestEventResult
{
	mixin EventBusResult!(int, int);
}

@("EventBusResult: returns results from all handlers")
unittest
{
	TestEventResult.clear();
	TestEventResult.subscribe((x) => x * 2);
	TestEventResult.subscribe((x) => x * 3);
	scope (exit)
		TestEventResult.clear();

	auto results = TestEventResult.fire(5);
	assert(results.length == 2);
	assert(results[0] == 10);
	assert(results[1] == 15);
}

@("EventBusResult: empty when no handlers")
unittest
{
	TestEventResult.clear();
	auto results = TestEventResult.fire(5);
	assert(results.length == 0);
}

struct TestInputEvent
{
	mixin EventBusResult!(bool, string);
}

@("EventBusResult: bool handlers for input consumption pattern")
unittest
{
	TestInputEvent.clear();
	TestInputEvent.subscribe((input) => false);
	TestInputEvent.subscribe((input) => input == "click");
	scope (exit)
		TestInputEvent.clear();

	auto results = TestInputEvent.fire("click");
	assert(results.length == 2);
	assert(results[0] == false);
	assert(results[1] == true);

	import std.algorithm : any;

	assert(results.any!(r => r == true));
}

@("EventBusResult: fireUntil stops on first non-default result")
unittest
{
	TestInputEvent.clear();
	int callCount = 0;

	TestInputEvent.subscribe((input) { callCount++; return false; });
	TestInputEvent.subscribe((input) { callCount++; return true; });
	TestInputEvent.subscribe((input) { callCount++; return true; });
	scope (exit)
		TestInputEvent.clear();

	bool consumed = TestInputEvent.fireUntil("click");
	assert(consumed == true);
	assert(callCount == 2);
}

@("EventBusResult: fireUntil returns default when no handler matches")
unittest
{
	TestInputEvent.clear();
	TestInputEvent.subscribe((input) => false);
	TestInputEvent.subscribe((input) => false);
	scope (exit)
		TestInputEvent.clear();

	bool consumed = TestInputEvent.fireUntil("click");
	assert(consumed == false);
}

@("EventBusResult: fireUntil with no handlers returns default")
unittest
{
	TestInputEvent.clear();
	bool consumed = TestInputEvent.fireUntil("click");
	assert(consumed == false);
}

// Test that different structs have separate handlers
struct EventA
{
	mixin EventBus!int;
}

struct EventB
{
	mixin EventBus!int;
}

@("EventBus: different structs have separate handlers")
unittest
{
	EventA.clear();
	EventB.clear();
	int countA = 0;
	int countB = 0;

	EventA.subscribe((x) { countA += x; });
	EventB.subscribe((x) { countB += x; });
	scope (exit)
		EventA.clear();
	scope (exit)
		EventB.clear();

	EventA.fire(1);
	assert(countA == 1);
	assert(countB == 0);

	EventB.fire(10);
	assert(countA == 1);
	assert(countB == 10);
}
