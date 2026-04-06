// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module app;

import std.stdio;
import trinove.subsystem;
import trinove.backend;
import trinove.log;
import trinove.math;
import trinove.virtual_output;
import trinove.backends.sdl;
import trinove.display_manager;
import trinove.output_manager;
import trinove.renderer : RenderSubsystem;
import trinove.seat_manager;
import trinove.compositor;
import trinove.cursor.manager : CursorThemeManager;
import default_compositor : DefaultCompositor;
import trinove.gpu.rhi : RHI;
import std.functional : toDelegate;
import std.getopt;
import std.format : format;
import std.conv : to;
import core.sys.posix.signal;

extern (C) nothrow @nogc
{
	int backtrace(void** buffer, int size);
	void backtrace_symbols_fd(void** buffer, int size, int fd);
}

extern (C) void crashHandler(int sig) nothrow @nogc
{
	import core.stdc.stdio : fprintf, stderr;
	import core.sys.posix.unistd : _exit;

	const(char)* name = "Unknown";
	if (sig == SIGSEGV)
		name = "SIGSEGV";
	else if (sig == SIGBUS)
		name = "SIGBUS";
	else if (sig == SIGABRT)
		name = "SIGABRT";
	else if (sig == SIGFPE)
		name = "SIGFPE";
	else if (sig == SIGILL)
		name = "SIGILL";

	fprintf(stderr, "\n=== CRASH: %s (signal %d) ===\n", name, sig);
	fprintf(stderr, "Backtrace:\n");

	void*[128] buf;
	int size = backtrace(buf.ptr, 128);
	backtrace_symbols_fd(buf.ptr, size, 2);

	fprintf(stderr, "===\n");

	_exit(128 + sig);
}

void installCrashHandler() nothrow @nogc
{
	sigaction_t sa;
	sa.sa_handler = &crashHandler;
	sa.sa_flags = SA_RESETHAND;

	sigaction(SIGSEGV, &sa, null);
	sigaction(SIGBUS, &sa, null);
	sigaction(SIGABRT, &sa, null);
	sigaction(SIGFPE, &sa, null);
	sigaction(SIGILL, &sa, null);
}

private VirtualOutputSpec parseOutputSpec(string arg, size_t index)
{
	import std.string : indexOf;

	string sizePart = arg;
	uint refreshMilliHz = 60_000;

	auto atIdx = arg.indexOf('@');
	if (atIdx >= 0)
	{
		refreshMilliHz = arg[atIdx + 1 .. $].to!uint * 1_000;
		sizePart = arg[0 .. atIdx];
	}

	auto xIdx = sizePart.indexOf('x');
	if (xIdx < 0)
		throw new Exception("expected WxH or WxH@Hz, got '" ~ arg ~ "'");

	uint w = sizePart[0 .. xIdx].to!uint;
	uint h = sizePart[xIdx + 1 .. $].to!uint;

	return VirtualOutputSpec(format("Virtual-%d", index + 1), Vector2U(w, h), refreshMilliHz);
}

int handleSignal(int sigNum)
{
	writeln("\nSignal received, terminating display...");
	getDisplay().terminate();
	return 0;
}

int main(string[] args)
{
	installCrashHandler();
	scope (exit)
		stdout.flush();
	logInfo("Trinove compositor starting...");

	initDisplay();
	auto display = getDisplay();
	scope (exit)
		display.destroy();

	string socketName;
	string[] outputArgs;

	try
	{
		auto help = getopt(args, "socket|s", "Wayland socket name (default: auto)", &socketName, "output|o",
				"Virtual output spec: WxH or WxH@Hz (repeatable)", &outputArgs,);
		if (help.helpWanted)
		{
			defaultGetoptPrinter("Usage: trinove [options]", help.options);
			return 0;
		}
	}
	catch (Exception e)
	{
		stderr.writeln("trinove: ", e.msg);
		return 1;
	}

	if (socketName.length > 0)
	{
		setDisplayName(socketName);
		display.addSocket(getDisplayName());
	}
	else
	{
		setDisplayName(display.addSocketAuto());
	}

	logInfo("Using display name: %s", getDisplayName());

	VirtualOutputSpec[] outputs;
	foreach (i, arg; outputArgs)
	{
		try
			outputs ~= parseOutputSpec(arg, i);
		catch (Exception e)
		{
			stderr.writeln("trinove: --output ", arg, ": ", e.msg);
			return 1;
		}
	}
	if (outputs.length == 0)
		outputs = [VirtualOutputSpec("Virtual-1", Vector2U(1920, 1080), 60_000)];

	SubsystemManager.register(new SdlSubsystem());
	SubsystemManager.register(new SdlVideoBackend(outputs));
	SubsystemManager.register(new SdlInputBackend());

	SubsystemManager.register(new OutputManager());
	SubsystemManager.register(new RenderSubsystem());
	SubsystemManager.register(new SeatManager());
	SubsystemManager.register(new CursorThemeManager());
	SubsystemManager.register(new DefaultCompositor());

	if (!RHI.initialize())
	{
		logError("Failed to initialize RHI");
		return 1;
	}
	scope (exit)
		RHI.shutdown();

	SubsystemManager.initializeAll();
	scope (exit)
		SubsystemManager.shutdownAll();

	auto si = display.eventLoop.addSignal(SIGINT, toDelegate(&handleSignal));
	scope (exit)
		si.destroy();
	auto st = display.eventLoop.addSignal(SIGTERM, toDelegate(&handleSignal));
	scope (exit)
		st.destroy();

	logInfo("Compositor running");
	display.run();
	return 0;
}
