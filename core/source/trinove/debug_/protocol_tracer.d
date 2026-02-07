// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.debug_.protocol_tracer;

import std.array : appender;
import std.format : format;
import std.typecons : Nullable;
import core.time : MonoTime;

enum Actor
{
	WM,
	Toplevel,
	Surface,
	Client,
	Popup
}

enum EventType
{
	Configure,
	Ack,
	Commit,
	StateChange,
	Note
}

struct TraceEvent
{
	long timestamp;
	Actor from;
	Actor to;
	EventType type;
	string message;
}

// RAII scope guard for stack-based tracing
struct TraceScope
{
	private ProtocolTracer _tracer;

	@disable this(this); // Disable copy to prevent double-leave

	~this()
	{
		if (_tracer !is null)
			_tracer.leave();
	}
}

// Helper to enter a trace scope without checking tracingEnabled
// Usage: auto _t = traceEnter(window, Actor.WM, "fullscreen");
// Usage with explicit caller: auto _t = traceEnter(window, Actor.Toplevel, "setMaximized", Actor.Client);
TraceScope traceEnter(T)(T window, Actor actor, string funcName, Nullable!Actor from = Nullable!Actor.init)
		if (is(typeof(window.tracingEnabled) : bool) && is(typeof(window.tracer) : ProtocolTracer))
{
	if (window !is null && window.tracingEnabled)
		return window.tracer.enter(actor, funcName, from);
	return TraceScope(_tracer : null);
}

// Convenience wrapper to pass Actor directly instead of Nullable
TraceScope traceEnter(T)(T window, Actor actor, string funcName, Actor from)
		if (is(typeof(window.tracingEnabled) : bool) && is(typeof(window.tracer) : ProtocolTracer))
{
	return traceEnter(window, actor, funcName, Nullable!Actor(from));
}

// Records protocol events for a window and exports as Mermaid sequence diagram
class ProtocolTracer
{
	private TraceEvent[] _events;
	private MonoTime _startTime;
	private size_t _maxEvents = 1000;
	private Actor[] _callStack;

	// Called whenever an event is recorded (for SSE push updates)
	void delegate() onEvent;

	this()
	{
		_startTime = MonoTime.currTime;
	}

	// Enter a function scope - automatically records arrow from caller
	// Returns a scope guard that calls leave() on destruction
	// Optional `from` parameter explicitly sets the caller (useful for entry points like protocol handlers)
	TraceScope enter(Actor actor, string funcName, Nullable!Actor from = Nullable!Actor.init)
	{
		Actor caller;
		bool hasCaller = false;

		if (!from.isNull)
		{
			// Explicit caller provided
			caller = from.get;
			hasCaller = true;
		}
		else if (_callStack.length > 0)
		{
			// Use stack
			caller = _callStack[$ - 1];
			hasCaller = true;
		}

		if (hasCaller && caller != actor)
			record(caller, actor, EventType.StateChange, funcName);
		else
			record(actor, actor, EventType.Note, funcName);

		_callStack ~= actor;
		return TraceScope(_tracer : this);
	}

	// Leave current scope (called automatically by TraceScope destructor)
	private void leave()
	{
		if (_callStack.length > 0)
			_callStack.length--;
	}

	void record(Actor from, Actor to, EventType type, string message)
	{
		_events ~= TraceEvent((MonoTime.currTime - _startTime).total!"msecs", from, to, type, message);

		// Keep bounded size
		if (_events.length > _maxEvents)
			_events = _events[$ - _maxEvents .. $];

		// Notify listener
		if (onEvent !is null)
			onEvent();
	}

	// Convenience methods
	void configure(uint serial, uint width, uint height)
	{
		record(Actor.Toplevel, Actor.Client, EventType.Configure, format("configure(serial=%d, %dx%d)", serial, width, height));
	}

	void configureState(uint serial, uint width, uint height, string[] states)
	{
		import std.array : join;

		string stateStr = states.length > 0 ? " [" ~ states.join(", ") ~ "]" : "";
		record(Actor.Toplevel, Actor.Client, EventType.Configure, format("configure(serial=%d, %dx%d)%s", serial,
				width, height, stateStr));
	}

	void ack(uint serial)
	{
		record(Actor.Client, Actor.Surface, EventType.Ack, format("ack_configure(%d)", serial));
	}

	void commit(uint width, uint height)
	{
		record(Actor.Client, Actor.Surface, EventType.Commit, format("commit(%dx%d)", width, height));
	}

	void commitToToplevel(uint width, uint height, bool applied)
	{
		string result = applied ? " ✓ applied" : "";
		record(Actor.Surface, Actor.Toplevel, EventType.Commit, format("handleCommit(%dx%d)%s", width, height, result));
	}

	void note(string message)
	{
		record(Actor.Toplevel, Actor.Toplevel, EventType.Note, message);
	}

	void clear()
	{
		_events = [];
		_startTime = MonoTime.currTime;
	}

	@property size_t eventCount() const
	{
		return _events.length;
	}

	@property bool empty() const
	{
		return _events.length == 0;
	}

	string exportMermaid()
	{
		import std.algorithm : canFind;

		// Collect which actors actually appear in the recorded events
		Actor[] usedActors;
		foreach (e; _events)
		{
			if (!usedActors.canFind(e.from))
				usedActors ~= e.from;
			if (!usedActors.canFind(e.to))
				usedActors ~= e.to;
		}

		// Emit participants in a stable order, only if they appear
		static immutable Actor[] actorOrder = [Actor.WM, Actor.Toplevel, Actor.Popup, Actor.Surface, Actor.Client];

		auto output = appender!string;
		output ~= "sequenceDiagram\n";
		foreach (a; actorOrder)
		{
			if (usedActors.canFind(a))
				output ~= "    participant " ~ actorName(a) ~ "\n";
		}

		size_t i = 0;
		while (i < _events.length)
		{
			auto e = _events[i];
			string fromStr = actorName(e.from);
			string toStr = actorName(e.to);

			// Count consecutive duplicates
			size_t duplicateCount = 1;
			while (i + duplicateCount < _events.length && _events[i + duplicateCount].from == e.from
					&& _events[i + duplicateCount].to == e.to && _events[i + duplicateCount].type == e.type
					&& _events[i + duplicateCount].message == e.message)
			{
				duplicateCount++;
			}

			if (e.type == EventType.Note)
			{
				output ~= format("    Note over %s: %s\n", fromStr, escapeMermaid(e.message));
			}
			else
			{
				string arrow = "->>"; // solid arrow
				if (e.type == EventType.Ack || e.type == EventType.Commit)
					arrow = "-->>"; // dashed for responses

				if (duplicateCount == 1)
				{
					output ~= format("    %s%s%s: %s\n", fromStr, arrow, toStr, escapeMermaid(e.message));
				}
				else if (duplicateCount == 2)
				{
					// Show both if just 2
					output ~= format("    %s%s%s: %s\n", fromStr, arrow, toStr, escapeMermaid(e.message));
					output ~= format("    %s%s%s: %s\n", fromStr, arrow, toStr, escapeMermaid(e.message));
				}
				else
				{
					// Show first, ellipsis note, last
					output ~= format("    %s%s%s: %s\n", fromStr, arrow, toStr, escapeMermaid(e.message));
					output ~= format("    Note over %s,%s: ... %d more ...\n", fromStr, toStr, duplicateCount - 2);
					output ~= format("    %s%s%s: %s\n", fromStr, arrow, toStr, escapeMermaid(e.message));
				}
			}

			i += duplicateCount;
		}

		return output[];
	}

	private static string actorName(Actor a)
	{
		final switch (a)
		{
		case Actor.WM:
			return "WM";
		case Actor.Toplevel:
			return "Toplevel";
		case Actor.Popup:
			return "Popup";
		case Actor.Surface:
			return "Surface";
		case Actor.Client:
			return "Client";
		}
	}

	private static string escapeMermaid(string s)
	{
		// Mermaid has issues with certain characters in messages
		import std.array : replace;

		return s.replace("\"", "'").replace("<", "‹").replace(">", "›");
	}
}
