// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.log;

import std.stdio;
import std.datetime;
import std.format;
import std.functional : forward;

enum LogLevel
{
	Debug,
	Info,
	Warn,
	Error,
}

struct LogEntry
{
	SysTime timestamp;
	LogLevel level;
	string message;
}

interface ILogHandler
{
	void log(const LogEntry entry);
}

class ConsoleLogHandler : ILogHandler
{
	override void log(const LogEntry entry)
	{
		writefln("[%s] %s", entry.level, entry.message);
	}
}

private __gshared ILogHandler[] g_logHandlers;

shared static this()
{
	g_logHandlers ~= new ConsoleLogHandler();
}

void addLogHandler(ILogHandler handler)
{
	g_logHandlers ~= handler;
}

void dispatch(LogLevel level, string message)
{
	auto entry = LogEntry(Clock.currTime(), level, message);
	foreach (handler; g_logHandlers)
	{
		handler.log(entry);
	}
}

void logInfo(A...)(string fmt, A args)
{
	dispatch(LogLevel.Info, format(fmt, forward!args));
}

void logWarn(A...)(string fmt, A args)
{
	dispatch(LogLevel.Warn, format(fmt, forward!args));
}

void logDebug(A...)(string fmt, A args)
{
	dispatch(LogLevel.Debug, format(fmt, forward!args));
}

void logError(A...)(string fmt, A args)
{
	dispatch(LogLevel.Error, format(fmt, forward!args));
}
