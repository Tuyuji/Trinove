// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.debug_server_subsystem;

import trinove.subsystem;
import trinove.compositor : WaiCompositor;
import trinove.display_manager : getDisplay;
import trinove.debug_.server : DebugServer;
import trinove.debug_.views : registerCompositorViews;
import trinove.main_thread_queue : drainMainThreadQueue;
import trinove.log;
import wayland.server : WlTimerEventSource;

class DebugServerSubsystem : ISubsystem
{
	private
	{
		ushort _port;
		DebugServer _server;
		WlTimerEventSource _mainQueueTimer;
	}

	this(ushort port = 8080)
	{
		_port = port;
	}

	override string name()
	{
		return "DebugServer";
	}

	override void getProvidedServices(ref ServiceName[] provided)
	{
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		required ~= Services.Compositor;
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	override void initialize()
	{
		auto compositor = SubsystemManager.getByService!WaiCompositor(Services.Compositor);
		if (compositor is null)
		{
			logError("DebugServerSubsystem: no compositor available");
			return;
		}

		_server = new DebugServer(_port);
		registerCompositorViews(_server, compositor);
		_server.start();

		auto d = getDisplay();
		_mainQueueTimer = d.eventLoop.addTimer(&drainTimer);
		_mainQueueTimer.update(100);
	}

	override void shutdown()
	{
		if (_mainQueueTimer !is null)
			_mainQueueTimer.destroy();
		if (_server !is null)
			_server.stop();
	}

	private int drainTimer()
	{
		drainMainThreadQueue();
		_mainQueueTimer.update(100);
		return 0;
	}
}
