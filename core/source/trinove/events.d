// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.events;

import trinove.bus;
import trinove.output : Output;
import trinove.output_manager : OutputManager;
import trinove.gpu.rhi : GpuDevice;
import trinove.wm.window : Window;

// Fired by video backends when a new output is detected (e.g. monitor hotplug)
mixin DefineEvent!("OnBackendOutputAdded", Output);

// Fired by video backends when an output is removed (e.g. monitor unplug)
mixin DefineEvent!("OnBackendOutputRemoved", Output);

// Fired when an output is activated and ready for use
mixin DefineEvent!("OnOutputAdded", OutputManager.ManagedOutput);

// Fired when an output is being deactivated
mixin DefineEvent!("OnOutputRemoved", OutputManager.ManagedOutput);

// Fired when GPU queue work is complete
mixin DefineEvent!("OnQueueWorkDone", GpuDevice);

// Fired when a window is added to the compositor (after it is mapped)
mixin DefineEvent!("OnWindowAdded", Window);

// Fired when a window is removed from the compositor.
mixin DefineEvent!("OnWindowRemoved", Window);
