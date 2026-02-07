// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.renderer.subsystem;

import trinove.subsystem;
import trinove.output_manager;
import trinove.renderer.scene;
import trinove.renderer.renderer;
import trinove.log;
import trinove.backend.video;
import webgpu : wgpuDeviceTick;

// Owns the scene graph and renderer, handles the repaint/damage/render cycle.
class RenderSubsystem : ISubsystem
{
	override string name()
	{
		return "RenderSubsystem";
	}

	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.RenderSubsystem;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		required ~= Services.OutputManager;
		required ~= Services.VideoBackend;
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	override void initialize()
	{
		_outputManager = SubsystemManager.getByService!OutputManager(Services.OutputManager);
		if (_outputManager is null)
		{
			logError("RenderSubsystem: No OutputManager available");
			return;
		}

		_scene = new SceneGraph();
		_scene.setOutputManager(_outputManager);
		_scene.setRepaintCallback(&onRepaintRequested);

		_renderer = new Renderer();
		_renderer.initialize();

		_outputManager.setRenderCallback(&renderOutput);

		_frameListeners.reserve(64);

		logInfo("RenderSubsystem initialized");
	}

	override void shutdown()
	{
		if (_renderer)
			_renderer.shutdown();

		logInfo("RenderSubsystem shutdown");
	}

	private
	{
		SceneGraph _scene;
		Renderer _renderer;
		OutputManager _outputManager;

		// For collecting frame listeners during render, cleared each frame.
		IFrameListener[] _frameListeners;
	}

	@property SceneGraph scene()
	{
		return _scene;
	}

	@property Renderer renderer()
	{
		return _renderer;
	}

	@property OutputManager outputManager()
	{
		return _outputManager;
	}

	private void onRepaintRequested()
	{
		// Propagate scene node damage to outputs
		_scene.propagateDamage();
		_scene.clearAllNodeDamage();

		foreach (ref mo; _outputManager.outputs)
		{
			if (mo.hasDamage())
				mo.scheduleRepaint();
		}
	}

	private void renderOutput(OutputManager.ManagedOutput mo)
	{
		if (mo.gpuDevice !is null)
			wgpuDeviceTick(mo.gpuDevice.handle);

		// Clear but keep capacity
		_frameListeners.length = 0;
		_frameListeners.assumeSafeAppend();

		_renderer.renderOutput(mo, _scene, _frameListeners);
		mo.clearDamage();

		// Notify all listeners that were rendered on this output
		foreach (listener; _frameListeners)
			listener.onFrame(mo);
	}
}
