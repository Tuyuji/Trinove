// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.debug_.views;

import std.conv : to;
import std.format : format;
import std.string : split, startsWith;
import std.array : appender, Appender;
import core.time : MonoTime, Duration, msecs;
import core.memory : GC;
import std.file : readText;

import diet.html : compileHTMLDietString;

import trinove.compositor;
import trinove.log;
import trinove.debug_.server : DebugServer;
import trinove.layer : Layer;
import trinove.backend.input : InputDeviceType;
import trinove.wm.popup : Popup;
import trinove.wm.conductor : WindowConductor;
import trinove.wm.window : Window;
import trinove.seat : PointerFocus, Seat;
import trinove.cursor;
import trinove.subsystem : SubsystemManager, Services;
import trinove.surface.surface : WaiSurface, InputRegionMode;
import trinove.surface.subsurface : WaiSubsurface;
import trinove.pointer_constraints : PointerConstraint, ConstraintType;

// Register all default compositor debug views.
// Call this after constructing DebugServer, before server.start().
void registerCompositorViews(DebugServer server, WaiCompositor compositor)
{
	server.registerView("/view/overview", (string p) => renderOverview(compositor));
	server.registerView("/view/overview/runtime", "/view/overview", (string p) => renderOverviewRuntime(compositor));
	server.registerView("/view/overview/memory", "/view/overview", (string p) => renderOverviewMemory(compositor));
	server.registerView("/view/windows", (string p) => renderWindows(compositor));
	server.registerView("/view/seats", (string p) => renderSeats(compositor));
	server.registerPrefixView("/view/cursor/set/", "/view/seats", (string p) => handleSetCursorTheme(compositor, p));
	server.registerView("/view/outputs", (string p) => renderOutputs(compositor));
	server.registerView("/view/gpu", (string p) => renderGpuDevices());
	__gshared TraceState trace;
	trace = new TraceState(server, compositor);
	server.registerView("/view/trace", (string p) => trace.render());
	server.registerView("/view/trace/auto/toggle", "/view/trace", (string p) => trace.toggleAuto());
	server.registerPrefixView("/view/trace/enable/", "/view/trace", (string p) => trace.enable(p));
	server.registerPrefixView("/view/trace/disable/", "/view/trace", (string p) => trace.disable(p));
	server.registerPrefixView("/view/trace/export/", "/view/trace", (string p) => trace.exportTrace(p), "text/plain");
	server.registerPrefixView("/view/trace/clear/", "/view/trace", (string p) => trace.clear(p));
	server.registerPrefixView("/view/trace/", "/view/trace", (string p) => trace.viewWindow(p));
}

// === Mutable trace state, captured once and shared across all trace route handlers ===

private class TraceState
{
	private
	{
		DebugServer _server;
		WindowConductor _conductor;
		bool _autoEnableTracing = false;
		Window _viewedTraceWindow;
		WaiSurface _viewedTraceSurface; // outlives the window
		MonoTime _lastTraceBroadcast;
		size_t _pendingEventCount;
	}

	this(DebugServer server, WaiCompositor compositor)
	{
		import trinove.events : OnWindowAdded, OnWindowRemoved;

		_server = server;
		_conductor = compositor.conductor;

		OnWindowRemoved.subscribe((Window w) {
			if (_viewedTraceWindow is w)
			{
				// Drop the window ref but keep the surface — trace data survives
				_viewedTraceWindow = null;
			}
		});

		OnWindowAdded.subscribe((Window w) {
			if (_autoEnableTracing)
				w.enableTracing();

			// Re-associate view if new window owns the surface we were watching
			if (_viewedTraceSurface !is null && w.getSurface() is _viewedTraceSurface)
			{
				_viewedTraceWindow = w;
				subscribeToEvents();
			}
		});
	}

	string render()
	{
		auto windows = _conductor.windows;
		size_t windowCount = windows.length;
		bool autoEnableTracing = _autoEnableTracing;
		string windowTableHtml = windowCount > 0 ? buildWindowTableHtml() : "";

		auto dst = appender!string;
		dst.compileHTMLDietString!(import("debug/views/trace.dt"), autoEnableTracing, windowCount, windowTableHtml);
		return dst.data;
	}

	string toggleAuto()
	{
		_autoEnableTracing = !_autoEnableTracing;
		return render();
	}

	string enable(string path)
	{
		auto parts = path.split("/");
		if (parts.length >= 5)
		{
			try
			{
				size_t idx = parts[4].to!size_t;
				if (idx < _conductor.windows.length)
					_conductor.windows[idx].enableTracing();
			}
			catch (Exception)
			{
			}
		}
		return render();
	}

	string disable(string path)
	{
		auto parts = path.split("/");
		if (parts.length >= 5)
		{
			try
			{
				size_t idx = parts[4].to!size_t;
				if (idx < _conductor.windows.length)
				{
					auto window = _conductor.windows[idx];
					if (_viewedTraceWindow is window)
						subscribeToTracer(null);
					window.disableTracing();
				}
			}
			catch (Exception)
			{
			}
		}
		return render();
	}

	string exportTrace(string path)
	{
		import std.file : write;

		auto parts = path.split("/");
		if (parts.length < 5)
			return "Invalid path";

		size_t windowIdx;
		try
		{
			windowIdx = parts[4].to!size_t;
		}
		catch (Exception)
		{
			return "Invalid window index";
		}

		if (windowIdx >= _conductor.windows.length)
			return "Window not found";

		auto window = _conductor.windows[windowIdx];
		auto surface = window.getSurface();
		if (surface is null || !surface.tracingEnabled || surface.tracer.empty)
			return "No trace data";

		string mermaid = surface.tracer.exportMermaid();
		string filePath = "/tmp/trinove-trace.mmd";
		try
		{
			write(filePath, mermaid);
			logInfo("Trace exported to %s (%d bytes)", filePath, mermaid.length);
			return "Exported to " ~ filePath ~ "\n\n" ~ mermaid;
		}
		catch (Exception e)
		{
			return "Failed to write file: " ~ e.msg ~ "\n\n" ~ mermaid;
		}
	}

	string clear(string path)
	{
		auto parts = path.split("/");
		if (parts.length >= 5)
		{
			try
			{
				size_t idx = parts[4].to!size_t;
				if (idx < _conductor.windows.length)
				{
					auto s = _conductor.windows[idx].getSurface();
					if (s !is null && s.tracingEnabled)
						s.tracer.clear();
				}
			}
			catch (Exception)
			{
			}
		}

		auto dst = appender!string;
		dst.compileHTMLDietString!(import("debug/views/trace_cleared.dt"));
		return dst.data;
	}

	string viewWindow(string path)
	{
		auto parts = path.split("/");
		if (parts.length < 4)
			return "";

		size_t windowIdx;
		try
		{
			windowIdx = parts[3].to!size_t;
		}
		catch (Exception)
		{
			return renderSimpleCard("Error", "Status", "Invalid window index");
		}

		if (windowIdx >= _conductor.windows.length)
			return renderSimpleCard("Error", "Status", "Window not found");

		auto window = _conductor.windows[windowIdx];

		if (!window.tracingEnabled)
		{
			subscribeToTracer(null);
			string cardTitle = window.title.length > 0 ? window.title : "(untitled)";
			return `<div class="card"><div class="card-header"><span class="card-title">` ~ htmlEsc(cardTitle)
				~ `</span></div><div class="card-body"><div class="empty">` ~ `<div class="empty-icon">&#128202;</div>`
				~ `<div>Tracing not enabled for this window</div></div></div></div>`;
		}

		subscribeToTracer(window);
		return renderTraceContent(window);
	}

	private void subscribeToTracer(Window window)
	{
		// Clear previous event listener
		if (_viewedTraceSurface !is null && _viewedTraceSurface.tracingEnabled)
			_viewedTraceSurface.tracer.onEvent = null;

		_viewedTraceWindow = window;
		_viewedTraceSurface = window !is null ? window.getSurface() : null;
		_pendingEventCount = 0;

		subscribeToEvents();
	}

	// Attach the live SSE event listener to the current surface's tracer.
	private void subscribeToEvents()
	{
		if (_viewedTraceSurface is null || !_viewedTraceSurface.tracingEnabled)
			return;

		auto surface = _viewedTraceSurface;
		surface.tracer.onEvent = () {
			_pendingEventCount++;

			auto now = MonoTime.currTime;
			auto elapsed = now - _lastTraceBroadcast;
			bool shouldBroadcast = (elapsed >= 150.msecs) || (_pendingEventCount >= 20);

			if (shouldBroadcast)
			{
				_lastTraceBroadcast = now;
				_pendingEventCount = 0;

				import std.json : JSONValue;

				JSONValue json;
				json["mermaid"] = surface.tracer.exportMermaid();
				json["eventCount"] = surface.tracer.eventCount;
				_server.broadcastEvent("trace-update", json.toString());
			}
		};
	}

	private string renderTraceContent(Window window)
	{
		// Use the surface's tracer directly — may outlive the window
		auto surface = _viewedTraceSurface !is null ? _viewedTraceSurface : (window !is null ? window.getSurface() : null);

		if (surface is null || !surface.tracingEnabled)
			return "";

		string title = window !is null && window.title.length > 0 ? window.title : "(untitled)";

		// Find live window index (may be null if window was destroyed)
		size_t windowIdx = size_t.max;
		if (window !is null)
		{
			foreach (i, w; _conductor.windows)
			{
				if (w is window)
				{
					windowIdx = i;
					break;
				}
			}
		}

		bool isLive = windowIdx != size_t.max;
		string idxStr = isLive ? windowIdx.to!string : "";
		bool isEmpty = surface.tracer.empty;
		size_t eventCount = surface.tracer.eventCount;
		string mermaidDiagram = isEmpty ? "" : surface.tracer.exportMermaid();
		string tagClass = isLive ? "tag tag-interaction" : "tag tag-unmapped";
		string tagText = isLive ? "Live" : "Session ended";

		auto dst = appender!string;
		dst.compileHTMLDietString!(import("debug/views/trace_content.dt"), title, isLive, idxStr, isEmpty, eventCount,
				mermaidDiagram, tagText, tagClass);
		return dst.data;
	}

	private string buildWindowTableHtml()
	{
		auto buf = appender!string;
		buf ~= `<table class="trace-table"><tbody>`;
		foreach (i, window; _conductor.windows)
		{
			string title = window.title.length > 0 ? htmlEsc(window.title) : "(untitled)";
			bool recording = window.tracingEnabled;

			buf ~= `<tr><td style="width: 100%;">` ~ title ~ `</td>`;
			buf ~= `<td style="white-space: nowrap;">`;

			if (recording)
			{
				buf ~= `<span class="tag tag-interaction">Recording</span> `;
				buf ~= `<span class="card-badge">` ~ window.tracer.eventCount.to!string ~ ` events</span>`;
			}
			else
			{
				buf ~= `<span class="tag tag-unmapped">Not recording</span>`;
			}

			buf ~= `</td><td style="white-space: nowrap;">`;

			if (recording)
			{
				buf ~= `<button class="nav-btn" style="margin: 2px;"` ~ ` hx-get="/view/trace/` ~ i.to!string
					~ `" hx-target="#trace-content" hx-swap="innerHTML">View</button>`;
				buf ~= `<button class="nav-btn" style="margin: 2px;"` ~ ` hx-get="/view/trace/disable/` ~ i.to!string
					~ `" hx-target="#trace-list" hx-swap="innerHTML">Stop</button>`;
			}
			else
			{
				buf ~= `<button class="nav-btn" style="margin: 2px;"` ~ ` hx-get="/view/trace/enable/` ~ i.to!string
					~ `" hx-target="#trace-list" hx-swap="innerHTML">Start Recording</button>`;
			}

			buf ~= `</td></tr>`;
		}
		buf ~= `</tbody></table>`;
		return buf.data;
	}
}

// === Free-function view renderers ===

private string renderOverview(WaiCompositor compositor)
{
	string runtimeHtml = renderOverviewRuntime(compositor);
	string memoryHtml = renderOverviewMemory(compositor);

	auto dst = appender!string;
	dst.compileHTMLDietString!(import("debug/views/overview.dt"), runtimeHtml, memoryHtml);
	return dst.data;
}

private string renderOverviewRuntime(WaiCompositor compositor)
{
	auto wm = compositor.conductor;
	auto sm = compositor.seatManager;
	auto om = compositor.outputManager;

	size_t popupCount = 0;
	foreach (window; wm.windows)
		popupCount += countPopups(window.popup);

	Duration uptime = MonoTime.currTime - compositor.startTime;
	string uptimeStr = formatDuration(uptime);
	size_t windowCount = wm.windows.length;
	size_t seatCount = sm.seats.length;
	size_t outputCount = om.outputs.length;

	auto dst = appender!string;
	dst.compileHTMLDietString!(import("debug/views/overview_runtime.dt"), uptimeStr, windowCount, popupCount, seatCount, outputCount);
	return dst.data;
}

private string renderOverviewMemory(WaiCompositor compositor)
{
	GC.Stats gcStats = GC.stats();

	size_t gcUsedBytes = gcStats.usedSize;
	size_t gcPoolBytes = gcStats.usedSize + gcStats.freeSize;
	size_t privateMem = getProcessPrivateMemory();
	size_t nonGcBytes = 0;
	bool isDebugBuild = false;

	debug
	{
		import trinove.math : Rect, DamageList;

		nonGcBytes = DamageList.globalTotalCapacity * Rect.sizeof;
		isDebugBuild = true;
	}

	size_t dTrackedBytes = gcPoolBytes + nonGcBytes;

	string privMemStr = privateMem > 0 ? formatBytes(privateMem) : "N/A";
	string gcUsedStr = formatBytes(gcUsedBytes);
	string gcPoolStr = formatBytes(gcPoolBytes);
	string nonGcStr = formatBytes(nonGcBytes);
	string dTrackedStr = formatBytes(dTrackedBytes);
	bool hasExternalMem = privateMem > 0;
	string externalStr = hasExternalMem ? formatBytes(privateMem > dTrackedBytes ? privateMem - dTrackedBytes : 0) : "";

	auto dst = appender!string;
	dst.compileHTMLDietString!(import("debug/views/overview_memory.dt"), privMemStr, gcUsedStr, gcPoolStr,
			isDebugBuild, nonGcStr, dTrackedStr, hasExternalMem, externalStr);
	return dst.data;
}

private string renderWindows(WaiCompositor compositor)
{
	import std.string : lastIndexOf;

	auto wm = compositor.conductor;
	auto windows = wm.windows;

	size_t[] popupCounts = new size_t[windows.length];
	string[] windowLayerNames = new string[windows.length];
	string[] windowTagsHtml = new string[windows.length];
	string[] windowClassNames = new string[windows.length];
	string[] constraintHtmls = new string[windows.length];
	string[] popupSectionHtmls = new string[windows.length];
	string[] subsurfaceSectionHtmls = new string[windows.length];

	foreach (i, window; windows)
	{
		popupCounts[i] = countPopups(window.popup);
		windowLayerNames[i] = layerName(window.layer);

		string fullName = typeid(window).name;
		auto dotIdx = fullName.lastIndexOf('.');
		windowClassNames[i] = dotIdx >= 0 ? fullName[dotIdx + 1 .. $] : fullName;

		auto surface = window.getSurface();
		if (surface !is null && surface.inputRegionMode == InputRegionMode.passThrough)
			windowTagsHtml[i] = `<span class="tag tag-unmapped">no-input</span>`;
		constraintHtmls[i] = buildConstraintHtml(surface, compositor.seatManager.seats);
		popupSectionHtmls[i] = buildPopupSection(window.popup);
		subsurfaceSectionHtmls[i] = buildSubsurfaceSection(surface, compositor.seatManager.seats);
	}

	auto dst = appender!string;
	dst.compileHTMLDietString!(import("debug/views/windows.dt"), windows, popupCounts, windowLayerNames,
			windowTagsHtml, windowClassNames, constraintHtmls, popupSectionHtmls, subsurfaceSectionHtmls);
	return dst.data;
}

private string renderSeats(WaiCompositor compositor)
{
	auto sm = compositor.seatManager;
	auto seats = sm.seats;

	string[] seatNames = new string[seats.length];
	string[] seatTagsHtml = new string[seats.length];
	string[] seatPosStrs = new string[seats.length];
	string[] kbFocusStrs = new string[seats.length];
	string[] ptrFocusStrs = new string[seats.length];
	string[] ptrSubsurfaceHtmls = new string[seats.length];
	string[] ptrConstraintHtmls = new string[seats.length];
	string[] deviceCountStrs = new string[seats.length];
	string[] deviceTableHtmls = new string[seats.length];

	foreach (i, seat; seats)
	{
		seatNames[i] = seat.name;

		seatPosStrs[i] = seat.pointerPosition.x.to!string ~ ", " ~ seat.pointerPosition.y.to!string;

		auto kbFocus = cast(Window) seat.keyboardFocusView;
		kbFocusStrs[i] = kbFocus ? htmlEsc(kbFocus.title) : "&lt;none&gt;";

		auto ptrFocus = cast(Window) seat.pointerFocus.view;
		ptrFocusStrs[i] = ptrFocus ? htmlEsc(ptrFocus.title) : "&lt;none&gt;";

		if (seat.pointerFocus.subsurface !is null)
			ptrSubsurfaceHtmls[i] = buildSubsurfacePathHtml(seat.pointerFocus);

		if (seat.pointerFocus.view !is null)
			ptrConstraintHtmls[i] = buildPointerConstraintHtml(seat.pointerFocus, seat);

		deviceCountStrs[i] = seat.devices.length.to!string;

		if (seat.devices.length > 0)
			deviceTableHtmls[i] = buildDeviceTableHtml(seat.devices);
	}

	auto dst = appender!string;
	dst.compileHTMLDietString!(import("debug/views/seats.dt"), seatNames, seatTagsHtml, seatPosStrs, kbFocusStrs,
			ptrFocusStrs, ptrSubsurfaceHtmls, ptrConstraintHtmls, deviceCountStrs, deviceTableHtmls);
	return dst.data;
}

private string renderOutputs(WaiCompositor compositor)
{
	auto om = compositor.outputManager;
	auto outputs = om.outputs;

	string[] outputNames = new string[outputs.length];
	string[] outputTagsHtml = new string[outputs.length];
	string[] outputResStrs = new string[outputs.length];
	string[] outputPosStrs = new string[outputs.length];
	string[] outputRefreshStrs = new string[outputs.length];
	string[] outputDamageHtmls = new string[outputs.length];

	foreach (i, ref mo; outputs)
	{
		auto output = mo.output;
		outputNames[i] = output.name;

		if (mo.hasDamage)
			outputTagsHtml[i] = `<span class="tag tag-dirty">damage pending</span>`;

		auto size = output.size;
		outputResStrs[i] = size.x.to!string ~ " x " ~ size.y.to!string;
		outputPosStrs[i] = mo.position.x.to!string ~ ", " ~ mo.position.y.to!string;
		outputRefreshStrs[i] = format("%.2f Hz", output.refreshRateMilliHz / 1000.0);

		if (!mo.damage.empty)
			outputDamageHtmls[i] = `<div class="kv"><span class="kv-key">Damage Regions</span>`
				~ `<span class="kv-value">` ~ mo.damage.length.to!string ~ `</span></div>`;
	}

	auto dst = appender!string;
	dst.compileHTMLDietString!(import("debug/views/outputs.dt"), outputNames, outputTagsHtml, outputResStrs,
			outputPosStrs, outputRefreshStrs, outputDamageHtmls);
	return dst.data;
}

private string renderGpuDevices()
{
	import trinove.gpu.rhi : RHI, GpuDevice;

	auto devices = RHI.allDevices;
	auto primary = RHI.primaryDevice;

	string[] gpuNames = new string[devices.length];
	string[] gpuTagsHtml = new string[devices.length];
	string[] gpuBodyHtmls = new string[devices.length];

	foreach (i, device; devices)
	{
		gpuNames[i] = device.name;

		string tags;
		if (device is primary)
			tags ~= `<span class="tag tag-focused">Primary</span>`;
		tags ~= `<span class="tag tag-layer">` ~ htmlEsc(device.backendName) ~ `</span>`;
		gpuTagsHtml[i] = tags;

		auto buf = appender!string;
		buf ~= buildKv("Type", htmlEsc(device.adapterTypeName));
		if (device.vendor.length > 0)
			buf ~= buildKv("Vendor", htmlEsc(device.vendor));
		if (device.architecture.length > 0)
			buf ~= buildKv("Architecture", htmlEsc(device.architecture));
		if (device.description.length > 0)
			buf ~= buildKv("Description", htmlEsc(device.description));
		buf ~= buildKvMono("Vendor ID", format("0x%04X", device.vendorID));
		buf ~= buildKvMono("Device ID", format("0x%04X", device.deviceID));
		gpuBodyHtmls[i] = buf.data;
	}

	auto dst = appender!string;
	dst.compileHTMLDietString!(import("debug/views/gpu.dt"), gpuNames, gpuTagsHtml, gpuBodyHtmls);
	return dst.data;
}

// === HTML builder helpers (used by D code, not templates) ===

private string htmlEsc(string s)
{
	import std.string : replace;

	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
}

private string treeProp(string text)
{
	return `<span class="tree-prop">` ~ htmlEsc(text) ~ `</span>`;
}

private string buildKv(string key, string valueHtml)
{
	return `<div class="kv"><span class="kv-key">` ~ htmlEsc(key) ~ `</span><span class="kv-value">` ~ valueHtml ~ `</span></div>`;
}

private string buildKvMono(string key, string value)
{
	return buildKv(key, `<span class="mono">` ~ htmlEsc(value) ~ `</span>`);
}

private string renderSimpleCard(string title, string key, string value)
{
	return `<div class="card"><div class="card-header"><span class="card-title">` ~ htmlEsc(
			title) ~ `</span></div><div class="card-body">` ~ buildKv(key, htmlEsc(value)) ~ `</div></div>`;
}

debug private string buildDamageListCard()
{
	import trinove.math : DamageList;

	auto buf = appender!string;
	buf ~= `<div class="card"><div class="card-header">`
		~ `<span class="card-title">DamageList (Surfaces &amp; Outputs)</span>` ~ `</div><div class="card-body">`;
	buf ~= buildKv("Active Lists", DamageList.globalActiveCount.to!string);
	buf ~= buildKvMono("Total Capacity", format("%d rects (%d KB)", DamageList.globalTotalCapacity,
			DamageList.globalTotalCapacity * 16 / 1024));
	buf ~= buildKvMono("Peak Capacity", format("%d rects (%d KB)", DamageList.globalPeakCapacity,
			DamageList.globalPeakCapacity * 16 / 1024));
	buf ~= `</div></div>`;
	return buf.data;
}

private string buildConstraintHtml(WaiSurface surface, Seat[] seats)
{
	if (surface is null)
		return "";

	foreach (seat; seats)
	{
		auto c = seat.constraintFor(surface);
		if (c is null || c.type == ConstraintType.none)
			continue;
		string cType = c.type == ConstraintType.lock ? "lock" : "confine";
		string variant = c.active ? "interaction" : "unmapped";
		string detail = c.active ? " (active)" : " (inactive)";
		return buildKv("Pointer Constraint", `<span class="tag tag-` ~ variant ~ `">` ~ cType ~ detail ~ `</span>`);
	}
	return "";
}

private string buildPopupSection(Popup popup)
{
	if (popup is null)
		return "";

	auto buf = appender!string;
	buf ~= buildKv("Popups", "");

	int idx = 1;
	while (popup !is null)
	{
		string props;
		if (popup.mapped)
			props ~= `<span class="tag tag-mapped">mapped</span>`;
		if (popup.grabbed)
			props ~= `<span class="tag tag-interaction">grabbed</span>`;

		auto absPos = popup.absolutePosition();
		props ~= treeProp("rel: " ~ popup.position.x.to!string ~ "," ~ popup.position.y.to!string);
		props ~= treeProp("abs: " ~ absPos.x.to!string ~ "," ~ absPos.y.to!string);
		props ~= treeProp("size: " ~ popup.surfaceSize.x.to!string ~ "x" ~ popup.surfaceSize.y.to!string);

		buf ~= `<div class="tree-node">` ~ `<span style="width:20px;display:inline-block"></span>`
			~ `<span class="tree-type">Popup #` ~ idx.to!string ~ `</span>` ~ props ~ `</div>`;

		popup = popup.childPopup;
		idx++;
	}
	return buf.data;
}

private string buildSubsurfaceSection(WaiSurface surface, Seat[] seats)
{
	if (surface is null || surface.subsurfaceChildren.length == 0)
		return "";

	auto buf = appender!string;
	buf ~= buildKv("Subsurfaces", countSubsurfaces(surface).to!string ~ " total");
	buildSubsurfaceTreeInto(buf, surface, seats, 1);
	return buf.data;
}

private void buildSubsurfaceTreeInto(ref Appender!string buf, WaiSurface surface, Seat[] seats, int depth)
{
	import trinove.surface.subsurface : WaiSubsurface;

	foreach (i, child; surface.subsurfaceChildren)
	{
		string props;
		if (child.surface !is null && child.surface.currentBuffer !is null)
			props ~= `<span class="tag tag-mapped">visible</span>`;
		else
			props ~= `<span class="tag tag-unmapped">hidden</span>`;

		if (child.isEffectivelySync())
			props ~= `<span class="tag tag-layer">sync</span>`;
		else
			props ~= `<span class="tag tag-interaction">desync</span>`;

		if (child.surface !is null)
		{
			foreach (seat; seats)
			{
				auto c = seat.constraintFor(child.surface);
				if (c !is null && c.type != ConstraintType.none)
				{
					string cType = c.type == ConstraintType.lock ? "lock" : "confine";
					string tagClass = c.active ? "tag-dirty" : "tag-unmapped";
					props ~= `<span class="tag ` ~ tagClass ~ `">` ~ cType ~ `</span>`;
					break;
				}
			}
		}

		if (child.surface !is null && child.surface.inputRegionMode == InputRegionMode.passThrough)
			props ~= `<span class="tag tag-unmapped">no-input</span>`;

		auto pos = child.position;
		props ~= treeProp(format("pos: %d,%d", pos.x, pos.y));
		if (child.surface !is null && child.surface.currentBuffer !is null)
		{
			auto ss = child.surface.computeSurfaceState();
			props ~= treeProp(format("size: %dx%d", ss.size.x, ss.size.y));
		}

		bool hasNested = child.surface !is null && child.surface.subsurfaceChildren.length > 0;
		string label = "Subsurface #" ~ (i + 1).to!string;

		if (hasNested)
		{
			buf ~= `<div class="tree-node">` ~ `<span class="tree-toggle">&#9654;</span>` ~ `<span class="tree-type">`
				~ label ~ `</span>` ~ props ~ `<div class="tree-children">`;
			buildSubsurfaceTreeInto(buf, child.surface, seats, depth + 1);
			buf ~= `</div></div>`;
		}
		else
		{
			buf ~= `<div class="tree-node">` ~ `<span style="width:20px;display:inline-block"></span>`
				~ `<span class="tree-type">` ~ label ~ `</span>` ~ props ~ `</div>`;
		}
	}
}

// Build a breadcrumb showing the full node path to the focused subsurface:
// e.g. [Normal] Window "foo" › Sub #1 › Sub #2
private string buildSubsurfacePathHtml(PointerFocus focus)
{
	assert(focus.subsurface !is null);

	// Walk the subsurface chain from focused leaf up to the root subsurface.
	WaiSubsurface[16] chain;
	int depth = 0;
	for (auto s = focus.subsurface; s !is null && depth < chain.length; s = s.parentSubsurface())
		chain[depth++] = s;

	auto buf = appender!string;

	// Window label from the view (avoids searching wm.windows).
	auto window = cast(Window) focus.view;
	if (window !is null)
	{
		string title = window.title.length > 0 ? window.title : "(untitled)";
		buf ~= `<span class="tag tag-layer">` ~ htmlEsc(
				layerName(window.layer)) ~ `</span>` ~ ` <span class="mono">` ~ htmlEsc(title) ~ `</span>`;
	}

	// Walk outermost-first (reverse of the chain we built bottom-up).
	foreach_reverse (sub; chain[0 .. depth])
	{
		// Find 1-based index in the parent surface's subsurface children list.
		int idx = 0;
		foreach (j, c; sub.parent.subsurfaceChildren)
		{
			if (c is sub)
			{
				idx = cast(int) j + 1;
				break;
			}
		}

		buf ~= ` <span class="text-muted">›</span> <span class="mono">Sub #` ~ (idx > 0 ? idx : 0).to!string ~ `</span>`;
	}

	return buildKv("Subsurface Focus", buf.data);
}

// Build a kv row showing the pointer constraint state for the focused surface.
// When the focus is a subsurface, shows both the subsurface constraint and the
// root surface constraint side-by-side so the two can be compared at a glance.
private string buildPointerConstraintHtml(PointerFocus focus, Seat seat)
{
	assert(focus.view !is null);

	auto focusedSurface = focus.surface;
	auto rootSurface = focus.view.getSurface();
	bool isSubsurface = focus.subsurface !is null;

	string constraintChip(WaiSurface surface)
	{
		if (surface is null)
			return `<span class="tag tag-unmapped">none</span>`;
		auto c = seat.constraintFor(surface);
		if (c is null || c.type == ConstraintType.none)
			return `<span class="tag tag-unmapped">none</span>`;
		string typeStr = c.type == ConstraintType.lock ? "lock" : "confine";
		// tag-dirty (red) = active, tag-interaction (blue) = inactive/pending
		string tagClass = c.active ? "tag-dirty" : "tag-interaction";
		string activeStr = c.active ? "active" : "inactive";
		return `<span class="tag ` ~ tagClass ~ `">` ~ typeStr ~ `</span>` ~ ` <span class="text-muted">` ~ activeStr ~ `</span>`;
	}

	auto buf = appender!string;

	if (isSubsurface)
	{
		// Show sub and root side-by-side with labels so the user can compare.
		buf ~= `<span class="mono text-muted">sub</span> ` ~ constraintChip(
				focusedSurface) ~ `&nbsp;&nbsp;<span class="mono text-muted">root</span> ` ~ constraintChip(rootSurface);
	}
	else
	{
		buf ~= constraintChip(focusedSurface);
	}

	return buildKv("Pointer Constraint", buf.data);
}

private string handleSetCursorTheme(WaiCompositor compositor, string path)
{
	import std.uri : decodeComponent;
	import std.string : indexOf;
	import trinove.main_thread_queue : dispatchToMainThread;

	enum prefix = "/view/cursor/set/";
	auto rest = path[prefix.length .. $];
	auto slashIdx = indexOf(rest, '/');
	if (slashIdx < 0)
		return `<span class="tag tag-unmapped">invalid path</span>`;

	size_t seatIdx;
	string themeName;
	try
	{
		seatIdx = rest[0 .. slashIdx].to!size_t;
		themeName = decodeComponent(rest[slashIdx + 1 .. $]);
	}
	catch (Exception)
	{
		return `<span class="tag tag-unmapped">invalid parameters</span>`;
	}

	if (themeName.length == 0)
		return `<span class="tag tag-unmapped">theme name is empty</span>`;

	string capturedName = themeName;
	dispatchToMainThread(() {
		auto ctm = SubsystemManager.getByService!CursorThemeManager(Services.CursorThemeManager);
		if (ctm is null)
			return;
		auto seats = compositor.seatManager.seats;
		if (seatIdx >= seats.length)
			return;
		auto seat = seats[seatIdx];
		auto oldTheme = seat.cursorTheme;
		auto newTheme = ctm.getTheme(capturedName);
		loadSystemCursorTheme(newTheme, capturedName);
		seat.setCursorTheme(newTheme);
		if (oldTheme !is null)
			ctm.releaseTheme(oldTheme);
	});

	return `<span class="tag tag-interaction">switching to '` ~ htmlEsc(themeName) ~ `'</span>`;
}

private string buildDeviceTableHtml(DeviceRange)(DeviceRange devices)
{
	auto buf = appender!string;
	buf ~= `<table class="mb-0"><thead><tr><th>Name</th><th>Type</th></tr></thead><tbody>`;
	foreach (device; devices)
	{
		buf ~= `<tr><td>` ~ htmlEsc(device.name) ~ `</td>` ~ `<td class="mono">` ~ htmlEsc(deviceTypeName(device.type)) ~ `</td></tr>`;
	}
	buf ~= `</tbody></table>`;
	return buf.data;
}

// === Helper functions ===

private size_t countPopups(Popup popup)
{
	size_t count = 0;
	while (popup !is null)
	{
		count++;
		popup = popup.childPopup;
	}
	return count;
}

private size_t countSubsurfaces(WaiSurface surface)
{
	size_t count = surface.subsurfaceChildren.length;
	foreach (child; surface.subsurfaceChildren)
	{
		if (child.surface !is null)
			count += countSubsurfaces(child.surface);
	}
	return count;
}

private string layerName(Layer layer)
{
	final switch (layer)
	{
	case Layer.Desktop:
		return "Desktop";
	case Layer.Below:
		return "Below";
	case Layer.Normal:
		return "Normal";
	case Layer.Dock:
		return "Dock";
	case Layer.Above:
		return "Above";
	case Layer.Notification:
		return "Notification";
	case Layer.Fullscreen:
		return "Fullscreen";
	case Layer.Overlay:
		return "Overlay";
	case Layer.Cursor:
		return "Cursor";
	}
}

private string deviceTypeName(InputDeviceType type)
{
	final switch (type)
	{
	case InputDeviceType.keyboard:
		return "keyboard";
	case InputDeviceType.pointer:
		return "pointer";
	case InputDeviceType.touch:
		return "touch";
	}
}

private string formatDuration(Duration d)
{
	auto secs = d.total!"seconds";
	auto mins = secs / 60;
	auto hours = mins / 60;

	if (hours > 0)
		return format("%dh %dm", hours, mins % 60);
	else if (mins > 0)
		return format("%dm %ds", mins, secs % 60);
	else
		return format("%ds", secs);
}

private string formatBytes(size_t bytes)
{
	if (bytes >= 1024 * 1024 * 1024)
		return format("%.1f GB", bytes / (1024.0 * 1024.0 * 1024.0));
	else if (bytes >= 1024 * 1024)
		return format("%.1f MB", bytes / (1024.0 * 1024.0));
	else if (bytes >= 1024)
		return format("%.1f KB", bytes / 1024.0);
	else
		return format("%d B", bytes);
}

// Reads private memory usage from /proc/self/statm. Returns 0 if unavailable.
private size_t getProcessPrivateMemory()
{
	try
	{
		import std.string : strip;

		string statm = readText("/proc/self/statm").strip();
		auto parts = statm.split(" ");
		if (parts.length >= 3)
		{
			size_t rssPages = parts[1].to!size_t;
			size_t sharedPages = parts[2].to!size_t;
			enum pageSize = 4096;
			return (rssPages > sharedPages ? rssPages - sharedPages : 0) * pageSize;
		}
	}
	catch (Exception)
	{
	}
	return 0;
}
