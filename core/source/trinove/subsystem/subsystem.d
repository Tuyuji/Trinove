// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.subsystem.subsystem;

import trinove.name;

alias ServiceName = Name;

struct Services
{
static immutable:

	// Core services
	enum VideoBackend = name!"VideoBackend";
	enum InputBackend = name!"InputBackend";
	enum OutputManager = name!"OutputManager";
	enum SeatManager = name!"SeatManager";
	enum Compositor = name!"Compositor";

	enum RenderSubsystem = name!"RenderSubsystem";
	enum CursorThemeManager = name!"CursorThemeManager";

	enum Conductor = name!"Conductor";
	enum WindowManager = name!"WindowManager";

	enum SDL = name!"SDL";
	enum DRM = name!"DRM";
	enum Libinput = name!"Libinput";
}

/**
 * Base interface for all subsystems.
 * Copy and paste helper:
    override string name() { return "MySubsystem"; }
    override void getProvidedServices(ref ServiceName[] provided) { }
    override void getRequiredServices(ref ServiceName[] required) { }
    override void getIncompatibleServices(ref ServiceName[] incompatible) { }
    override void initialize() { }
    override void shutdown() { }
 */
interface ISubsystem
{
	// Unique name for this subsystem (used for logging and debugging)
	string name();

	// Get list of services this subsystem provides.
	// Other subsystems can depend on these services.
	void getProvidedServices(ref ServiceName[] provided);

	// Get list of services this subsystem requires.
	// These must be provided by other subsystems.
	// This subsystem will be initialized AFTER its required services.
	void getRequiredServices(ref ServiceName[] required);

	// Get list of services that are incompatible with this subsystem.
	// If any of these services are already provided, initialization will fail.
	void getIncompatibleServices(ref ServiceName[] incompatible);

	// Called after all required services are initialized.
	void initialize();

	void shutdown();
}
