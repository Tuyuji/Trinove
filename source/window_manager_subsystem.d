// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module window_manager_subsystem;

import trinove.subsystem;
import trinove.wm.conductor : WindowConductor;
import trinove.wm.imanager : IWindowManager;
import trinove.wm.default_manager : DefaultWindowManager;
import trinove.log;

class WindowManagerSubsystem : ISubsystem
{
	private
	{
		WindowConductor _conductor;
		IWindowManager _wm;
	}

	override string name()
	{
		return "WindowManagerSubsystem";
	}

	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.WindowManager;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		required ~= Services.Conductor;
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	override void initialize()
	{
		_conductor = SubsystemManager.getByService!WindowConductor(Services.Conductor);
		_wm = new DefaultWindowManager();
		_conductor.setWindowManager(_wm);
		logInfo("WindowManagerSubsystem initialized");
	}

	override void shutdown()
	{
		if (_wm !is null)
		{
			_conductor.setWindowManager(null);
			_wm.shutdown();
			_wm = null;
		}
		logInfo("WindowManagerSubsystem shutdown");
	}

	@property IWindowManager windowManager()
	{
		return _wm;
	}
}
