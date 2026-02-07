// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.backend.video;

import trinove.output;
import trinove.subsystem;

interface VideoBackend
{
	// Get all detected outputs
	Output[] outputs();
}

abstract class VideoBackendSubsystem : ISubsystem, VideoBackend
{
	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.VideoBackend;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}
}
