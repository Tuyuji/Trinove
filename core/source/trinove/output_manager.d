// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.output_manager;

import trinove.output;
import trinove.math;
import trinove.log;
import trinove.events;
import trinove.util : getResVersion;
import trinove.subsystem;
import trinove.display_manager;
import trinove.backend.video;
import trinove.gpu.rhi : GpuDevice, RHI;
import wayland.server;
import wayland.server.protocol : WlOutput;
import std.algorithm : remove;
import core.time : MonoTime;
import webgpu;

final class OutputManager : ISubsystem
{
	private bool _shuttingDown = false;

	override string name()
	{
		return "OutputManager";
	}

	override void getProvidedServices(ref ServiceName[] provided)
	{
		provided ~= Services.OutputManager;
	}

	override void getRequiredServices(ref ServiceName[] required)
	{
		required ~= Services.VideoBackend;
	}

	override void getIncompatibleServices(ref ServiceName[] incompatible)
	{
	}

	override void initialize()
	{
		_display = getDisplay();

		auto videoBackend = SubsystemManager.getByService!VideoBackend(Services.VideoBackend);
		if (videoBackend !is null)
		{
			activateAllOutputs(videoBackend);
		}

		OnBackendOutputAdded.subscribe(&onBackendOutputAdded);
		OnBackendOutputRemoved.subscribe(&onBackendOutputRemoved);

		logInfo("OutputManager initialized with %d outputs", _outputs.length);
	}

	override void shutdown()
	{
		OnBackendOutputAdded.unsubscribe(&onBackendOutputAdded);
		OnBackendOutputRemoved.unsubscribe(&onBackendOutputRemoved);

		_shuttingDown = true;
		while (_outputs.length > 0)
		{
			deactivateOutput(_outputs[0].output);
		}
		logInfo("OutputManager shutdown");
	}

	alias RenderCallback = void delegate(ManagedOutput);

	class ManagedOutput : WlOutput
	{
		Output output;
		Vector2I position;
		DamageList damage;

		WGPUSurface surface;
		WGPUTextureFormat surfaceFormat;

		// GPU device responsible for rendering this output
		GpuDevice gpuDevice;

		private
		{
			bool _damagesPending;
			bool _frameLoopRunning;
			WlTimerEventSource _repaintTimer;
			WlTimerEventSource _finishFrameTimer;
			WlIdleEventSource _pendingIdleSource;
			MonoTime _frameStartTime;
			long _refreshNsecs = 1_000_000_000 / 60; // Default 60fps
			enum _idleRefreshMs = 1000; // 1fps when idle
			RenderCallback _renderCallback;
			Resource[] _boundResources;
		}

		this(Output output, Vector2I position)
		{
			import trinove.display_manager;

			this.output = output;
			this.position = position;
			damage = DamageList.init;
			super(getDisplay(), WlOutput.ver);

			auto eventLoop = getDisplay().eventLoop;
			_repaintTimer = eventLoop.addTimer(&onRepaintTimer);
			_finishFrameTimer = eventLoop.addTimer(&onFinishFrameTimer);

			auto modes = output.modes();
			if (modes.length > 0 && modes[0].refreshMilliHz > 0)
			{
				setRefreshRate(modes[0].refreshMilliHz);
			}
		}

		void setRenderCallback(RenderCallback cb)
		{
			_renderCallback = cb;
		}

		void setRefreshRate(int milliHz)
		{
			if (milliHz > 0)
				_refreshNsecs = 1_000_000_000_000L / milliHz;
		}

		@property int refreshRateMilliHz()
		{
			return _refreshNsecs > 0 ? cast(int)(1_000_000_000_000L / _refreshNsecs) : 0;
		}

		// Get the viewport rect in compositor space
		Rect viewport()
		{
			auto sz = output.size();
			return Rect(position.x, position.y, sz.x, sz.y);
		}

		// Add damage in compositor space coordinates.
		// The region will be intersected with this output's viewport and converted
		// to output-local coordinates.
		void addDamage(Rect compositorSpaceRect)
		{
			auto vp = viewport();
			auto intersection = compositorSpaceRect.intersection(vp);
			if (!intersection.isEmpty)
			{
				// Convert to output-local coordinates
				addLocalDamage(intersection.offset(-vp.position.x, -vp.position.y));
			}
		}

		void addLocalDamage(Rect localRect)
		{
			damage.add(localRect);
		}

		void clearDamage()
		{
			damage.clear();
		}

		bool hasDamage() const
		{
			return !damage.empty;
		}

		void scheduleRepaint()
		{
			_damagesPending = true;
			if (_frameLoopRunning)
				return;

			import trinove.display_manager;

			if (_pendingIdleSource is null)
				_pendingIdleSource = getDisplay().eventLoop.addIdle(&onIdleRepaint);
			else
				_pendingIdleSource.reschedule();
			_frameLoopRunning = true;
		}

		private void onIdleRepaint()
		{
			finishFrame(MonoTime.currTime);
		}

		private void finishFrame(MonoTime frameStart)
		{
			auto now = MonoTime.currTime;
			auto elapsed = now - frameStart;
			auto remaining = (_refreshNsecs - elapsed.total!"nsecs") / 1_000_000; // to ms

			if (remaining < 1)
			{
				// Render immediately, at or past deadline
				doRepaint();
			}
			else
			{
				// Schedule render for later
				_repaintTimer.update(cast(uint) remaining);
			}
		}

		private int onRepaintTimer()
		{
			doRepaint();
			return 0;
		}

		private void doRepaint()
		{
			_frameStartTime = MonoTime.currTime;
			_damagesPending = false;

			if (_renderCallback !is null)
				_renderCallback(this);

			_finishFrameTimer.update(2);
		}

		private int onFinishFrameTimer()
		{
			if (_damagesPending)
			{
				finishFrame(_frameStartTime);
			}
			else
			{
				_frameLoopRunning = false;
				_finishFrameTimer.update(_idleRefreshMs);
			}
			return 0;
		}

		override Resource bind(WlClient cl, uint ver, uint id)
		{
			auto res = super.bind(cl, ver, id);
			sendCurrentConfig(res);
			_boundResources ~= res;
			res.addDestroyListener((WlResource r) {
				import std.algorithm : remove;

				_boundResources = _boundResources.remove!(r2 => r2 is r);
			});
			return res;
		}

		private void sendCurrentConfig(Resource res)
		{
			res.sendGeometry(position.x, position.y, 0, 0, Subpixel.unknown, "IDK", output.name, Transform.normal);
			foreach (mode; output.modes())
				res.sendMode(mode.flags, mode.size.x, mode.size.y, mode.refreshMilliHz);
			if (getResVersion(res) >= WlOutput.doneSinceVersion)
				res.sendDone();
		}

		override void release(WlClient cl, Resource res)
		{
		}
	}

	private
	{
		WlDisplay _display;
		ManagedOutput[] _outputs;
	}

	@property ManagedOutput[] outputs()
	{
		return _outputs;
	}

	ManagedOutput* findByOutput(Output output)
	{
		foreach (ref mo; _outputs)
		{
			if (mo.output is output)
				return &mo;
		}
		return null;
	}

	bool activateOutput(Output output, Vector2I position = Vector2I(0, 0))
	{
		if (findByOutput(output) !is null)
		{
			logWarn("Output %s already activated", output.name);
			return true;
		}

		// Get GPU device for this output
		auto gpuDevice = output.findGpu();
		if (gpuDevice is null)
		{
			logError("No GPU device for output %s", output.name);
			return false;
		}

		// Activate output and create WebGPU surface
		auto surface = output.activate(RHI.instance);
		if (surface is null)
		{
			logError("Failed to activate output %s", output.name);
			return false;
		}

		ManagedOutput mo = new ManagedOutput(output, position);
		mo.gpuDevice = gpuDevice;
		mo.surface = surface;

		auto sz = output.size();
		mo.surfaceFormat = WGPUTextureFormat.bgra8Unorm;

		WGPUSurfaceConfiguration surfaceConfig;
		surfaceConfig.device = mo.gpuDevice.handle;
		surfaceConfig.format = mo.surfaceFormat;
		surfaceConfig.usage = WGPUTextureUsage.renderAttachment;
		surfaceConfig.width = sz.x;
		surfaceConfig.height = sz.y;
		surfaceConfig.alphaMode = WGPUCompositeAlphaMode.opaque;

		wgpuSurfaceConfigure(mo.surface, &surfaceConfig);
		logInfo("Configured surface: %dx%d format=%d", sz.x, sz.y, mo.surfaceFormat);

		_outputs ~= mo;
		logInfo("Activated output: %s at (%d, %d) on GPU %s", output.name, position.x, position.y, mo.gpuDevice.name);

		OnOutputAdded.fire(mo);

		return true;
	}

	void deactivateOutput(Output output)
	{
		foreach (i, ref mo; _outputs)
		{
			if (mo.output is output)
			{
				OnOutputRemoved.fire(mo);

				if (mo.gpuDevice !is null)
					mo.gpuDevice.waitForIdle();

				if (mo.surface !is null)
				{
					wgpuSurfaceUnconfigure(mo.surface);
					wgpuSurfaceRelease(mo.surface);
					mo.surface = null;

					if (mo.gpuDevice !is null)
						mo.gpuDevice.waitForIdle();
				}

				mo.damage.release();

				mo.output.deactivate();
				_outputs = _outputs.remove(i);
				if (!_shuttingDown)
				{
					//Dont remove wayland global if we're shutting down, seems to cause
					//a crash in wl_global_destroy, maybe look into why as we dont destroy the display yet
					//maybe terminating the display is destroying it?
					mo.destroy();
				}
				logInfo("Deactivated output: %s", output.name);
				return;
			}
		}
	}

	void setPosition(Output output, Vector2I position)
	{
		if (auto mo = findByOutput(output))
		{
			mo.position = position;
			foreach (res; mo._boundResources)
				mo.sendCurrentConfig(res);
		}
	}

	void activateAllOutputs(VideoBackend backend)
	{
		int xOffset = 0;
		foreach (output; backend.outputs())
		{
			// Arrange horizontally by default
			if (activateOutput(output, Vector2I(xOffset, 0)))
			{
				xOffset += output.size().x;
			}
		}
	}

	private void onBackendOutputAdded(Output output)
	{
		int xOffset = 0;
		foreach (ref mo; _outputs)
		{
			auto vp = mo.viewport();
			int right = vp.position.x + cast(int) vp.size.x;
			if (right > xOffset)
				xOffset = right;
		}

		activateOutput(output, Vector2I(xOffset, 0));
	}

	private void onBackendOutputRemoved(Output output)
	{
		deactivateOutput(output);
	}

	void addDamage(Rect compositorSpaceRect)
	{
		foreach (ref mo; _outputs)
		{
			mo.addDamage(compositorSpaceRect);
		}
	}

	void damageAll()
	{
		foreach (ref mo; _outputs)
		{
			auto sz = mo.output.size();
			mo.damage.setFull(Rect(0, 0, sz.x, sz.y));
		}
	}

	void clearAllDamage()
	{
		foreach (ref mo; _outputs)
		{
			mo.clearDamage();
		}
	}

	// Find the primary output for the given bounds.
	// 1. Returns output containing the center point
	// 2. If center not in any output, returns output with most overlap
	// 3. If no overlap at all, returns null
	ManagedOutput findPrimaryOutput(Rect bounds)
	{
		if (_outputs.length == 0)
			return null;

		int cx = bounds.position.x + cast(int)(bounds.size.x / 2);
		int cy = bounds.position.y + cast(int)(bounds.size.y / 2);

		// Check if center is in any output
		foreach (ref mo; _outputs)
		{
			auto vp = mo.viewport();
			if (cx >= vp.position.x && cx < vp.position.x + cast(int) vp.size.x && cy >= vp.position.y
					&& cy < vp.position.y + cast(int) vp.size.y)
				return mo;
		}

		// Find output with most overlap
		ManagedOutput bestOutput = null;
		long bestArea = 0;

		foreach (ref mo; _outputs)
		{
			auto intersection = bounds.intersection(mo.viewport());
			if (!intersection.isEmpty)
			{
				long area = cast(long) intersection.size.x * cast(long) intersection.size.y;
				if (area > bestArea)
				{
					bestArea = area;
					bestOutput = mo;
				}
			}
		}

		return bestOutput;
	}

	void scheduleRepaintAll()
	{
		foreach (ref mo; _outputs)
		{
			mo.scheduleRepaint();
		}
	}

	void setRenderCallback(RenderCallback cb)
	{
		foreach (ref mo; _outputs)
		{
			mo.setRenderCallback(cb);
		}
	}

	// Returns the output containing the given compositor-space point, or null if none.
	ManagedOutput outputAt(Vector2I point)
	{
		foreach (ref mo; _outputs)
		{
			auto vp = mo.viewport();
			if (point.x >= vp.position.x && point.x < vp.position.x + cast(int) vp.size.x
				&& point.y >= vp.position.y && point.y < vp.position.y + cast(int) vp.size.y)
				return mo;
		}
		return null;
	}

	// Constrain a pointer position to the union of output regions.
	// If pos is inside any output, returns it unchanged (preserving double precision).
	// Otherwise returns the closest in-bounds point on the nearest output edge.
	Vector2 constrainToOutputs(Vector2 pos)
	{
		if (_outputs.length == 0)
			return pos;

		// Already inside an output
		foreach (ref mo; _outputs)
		{
			auto vp = mo.viewport();
			if (pos.x >= vp.position.x && pos.x < vp.position.x + cast(int) vp.size.x && pos.y >= vp.position.y
					&& pos.y < vp.position.y + cast(int) vp.size.y)
				return pos;
		}

		// Outside all outputs. Find closest point on nearest output
		double bestDist = double.max;
		Vector2 bestPoint = pos;

		foreach (ref mo; _outputs)
		{
			auto vp = mo.viewport();
			int right = vp.position.x + cast(int) vp.size.x - 1;
			int bottom = vp.position.y + cast(int) vp.size.y - 1;

			double cx = pos.x < vp.position.x ? vp.position.x : (pos.x > right ? right : pos.x);
			double cy = pos.y < vp.position.y ? vp.position.y : (pos.y > bottom ? bottom : pos.y);

			double dx = pos.x - cx;
			double dy = pos.y - cy;
			double dist = dx * dx + dy * dy;

			if (dist < bestDist)
			{
				bestDist = dist;
				bestPoint = Vector2(cx, cy);
			}
		}

		return bestPoint;
	}
}
