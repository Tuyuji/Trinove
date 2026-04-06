// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.virtual_output;

import trinove.math;

// Describes the properties of a virtual output for creation.
// Virtual outputs are compositor outputs not tied to physical hardware.
struct VirtualOutputSpec
{
	string name;
	Vector2U size = Vector2U(1920, 1080);
	uint refreshMilliHz = 60_000;
}
