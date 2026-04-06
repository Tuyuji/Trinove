// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.surface.dmabuf;

import trinove.protocols.linux_dmabuf;
import trinove.surface.buffer : IWaylandBuffer;
import trinove.surface.surface : WaiSurface;
import trinove.math.vector : Vector2U;
import trinove.math.rect : Rect;
import trinove.gpu.itexture : ITexture;
import trinove.gpu.shared_texture : SharedTexture2D, DmaBufPlane;
import trinove.gpu.rhi : GpuDevice, RHI;
import trinove.log;
import dawned;
import trinove.util : onDestroyCallDestroy;
import wayland.server;
import wayland.server.protocol : WlBuffer;
import wayland.native.server;
import wayland.native.util : wl_array, wl_array_init;
import core.sys.posix.unistd : close, ftruncate;
import core.sys.posix.sys.stat : stat_t, fstat;
import core.sys.posix.sys.mman : mmap, munmap, PROT_READ, PROT_WRITE, MAP_SHARED;
import core.sys.posix.fcntl : fcntl;
import core.stdc.string : memcpy;
import trinove.linux.drm;
import trinove.linux.memfd;

// Local plane data (before passing to SharedTexture2D)
private struct LocalPlane
{
	int fd = -1;
	uint offset;
	uint stride;
}

// Supported format+modifier pair for feedback table
struct FormatModifierPair
{
	uint format;
	uint _padding;
	ulong modifier;
}

static assert(FormatModifierPair.sizeof == 16);

private FormatModifierPair[] queryDawnDmaBufFormats(GpuDevice device)
{
	// wgpuAdapterGetFormatCapabilities works in WebGPU format space.
	// map each candidate WGPU format to the DRM fourcc codes that share its memory layout.
	struct Candidate
	{
		WGPUTextureFormat wgpuFmt;
		const(uint)[] drmFmts;
	}

	immutable Candidate[] candidates = [
		{WGPUTextureFormat.bgra8Unorm, [DrmFormat.ARGB8888, DrmFormat.XRGB8888]},
		{WGPUTextureFormat.rgba8Unorm, [DrmFormat.ABGR8888, DrmFormat.XBGR8888]},
		{WGPUTextureFormat.rgb10A2Unorm, [DrmFormat.XBGR2101010]},
	];

	FormatModifierPair[] result;

	foreach (ref cand; candidates)
	{
		WGPUDawnDrmFormatCapabilities drmCaps;
		WGPUDawnFormatCapabilities caps;
		caps.nextInChain = &drmCaps.chain;

		auto status = wgpuAdapterGetFormatCapabilities(device.adapter, cand.wgpuFmt, &caps);
		scope (exit)
			wgpuDawnDrmFormatCapabilitiesFreeMembers(drmCaps);

		if (status != WGPUStatus.success)
		{
			logWarn("dmabuf: format capabilities query failed for wgpu format %d", cand.wgpuFmt);
			continue;
		}

		foreach (ref prop; drmCaps.properties[0 .. drmCaps.propertiesCount])
		{
			foreach (drmFmt; cand.drmFmts)
				result ~= FormatModifierPair(drmFmt, 0, prop.modifier);
		}
	}

	logInfo("dmabuf: queried %d format+modifier pairs from Dawn", result.length);
	return result;
}

class WaiLinuxDmabuf : ZwpLinuxDmabufV1
{
	private
	{
		// Union of all format+modifier pairs across all known GPU devices.
		FormatModifierPair[] _formatTable;
		// Per-device index subsets into _formatTable.
		ushort[][GpuDevice] _deviceFormatIndices;
		int _formatTableFd = -1;
		uint _formatTableSize;
	}

	this(WlDisplay display)
	{
		//Version 5 exists but we're not gonna support it yet.
		enum MAX_VERSION = 4;
		super(display, MAX_VERSION);
		logInfo("linux-dmabuf-v1 global created (version %d)", MAX_VERSION);

		buildFormatTable();
	}

	private void buildFormatTable()
	{
		size_t[FormatModifierPair] pairToIndex;

		foreach (dev; RHI.allDevices)
		{
			auto pairs = queryDawnDmaBufFormats(dev);
			ushort[] devIndices;

			foreach (ref pair; pairs)
			{
				if (auto p = pair in pairToIndex)
				{
					devIndices ~= cast(ushort)*p;
				}
				else
				{
					auto idx = _formatTable.length;
					_formatTable ~= pair;
					pairToIndex[pair] = idx;
					devIndices ~= cast(ushort) idx;
				}
			}

			_deviceFormatIndices[dev] = devIndices;
			logInfo("dmabuf: device '%s' supports %d format+modifier pairs", dev.name, devIndices.length);
		}

		if (_formatTable.length == 0)
		{
			logWarn("dmabuf: no supported formats from any device, not advertising DMA-BUF");
			return;
		}

		_formatTableSize = cast(uint)(_formatTable.length * FormatModifierPair.sizeof);

		_formatTableFd = memfd_create("trinove-dmabuf-format-table", MFD_CLOEXEC | MFD_ALLOW_SEALING);
		if (_formatTableFd < 0)
		{
			logError("Failed to create memfd for format table");
			return;
		}

		import core.sys.posix.unistd : ftruncate;

		if (ftruncate(_formatTableFd, _formatTableSize) < 0)
		{
			logError("Failed to size format table memfd");
			close(_formatTableFd);
			_formatTableFd = -1;
			return;
		}

		void* map = mmap(null, _formatTableSize, PROT_READ | PROT_WRITE, MAP_SHARED, _formatTableFd, 0);
		if (map is null || map == cast(void*)-1)
		{
			logError("Failed to mmap format table");
			close(_formatTableFd);
			_formatTableFd = -1;
			return;
		}

		memcpy(map, _formatTable.ptr, _formatTableSize);
		munmap(map, _formatTableSize);

		// Seal the memfd so clients can trust it won't change
		fcntl(_formatTableFd, F_ADD_SEALS, F_SEAL_SHRINK | F_SEAL_GROW | F_SEAL_WRITE);

		logInfo("dmabuf: format table has %d unique entries across %d device(s)", _formatTable.length, _deviceFormatIndices
				.length);
	}

	// Returns the format indices for a specific device, or null if the device is unknown.
	const(ushort)[] formatsForDevice(GpuDevice dev)
	{
		if (auto p = dev in _deviceFormatIndices)
			return *p;
		return null;
	}

	@property int formatTableFd() => _formatTableFd;
	@property uint formatTableSize() => _formatTableSize;
	@property const(FormatModifierPair)[] formatTable() => _formatTable;

	override Resource bind(WlClient cl, uint ver, uint id)
	{
		auto res = super.bind(cl, ver, id);

		// Advertise supported formats (version < 4 uses format/modifier events)
		if (ver < 4)
		{
			foreach (ref entry; _formatTable)
			{
				uint hi = cast(uint)(entry.modifier >> 32);
				uint lo = cast(uint)(entry.modifier & 0xFFFF_FFFF);
				res.sendModifier(entry.format, hi, lo);
			}
		}

		return res;
	}

	override protected void destroy(WlClient cl, Resource res)
	{
		res.destroy();
	}

	override protected ZwpLinuxBufferParamsV1 createParams(WlClient cl, Resource res, uint paramsId)
	{
		return new WaiLinuxBufferParams(cl, res.ver, paramsId);
	}

	override protected ZwpLinuxDmabufFeedbackV1 getDefaultFeedback(WlClient cl, Resource res, uint id)
	{
		if (_formatTableFd < 0)
		{
			logError("Format table not available for feedback");
			return null;
		}

		auto feedback = new WaiLinuxDmabufFeedback(cl, res.ver, id, this, null);
		feedback.sendInitialFeedback();
		return feedback;
	}

	override protected ZwpLinuxDmabufFeedbackV1 getSurfaceFeedback(WlClient cl, Resource res, uint id, WlResource surface)
	{
		if (_formatTableFd < 0)
		{
			logError("Format table not available for feedback");
			return null;
		}

		auto feedback = new WaiLinuxDmabufFeedback(cl, res.ver, id, this, surface);
		feedback.sendInitialFeedback();
		return feedback;
	}
}

// Feedback object for linux-dmabuf v4+
class WaiLinuxDmabufFeedback : ZwpLinuxDmabufFeedbackV1
{
	private
	{
		WaiLinuxDmabuf _dmabuf;
		WlResource _surface; // May be null for default feedback
	}

	this(WlClient cl, uint ver, uint id, WaiLinuxDmabuf dmabuf, WlResource surface)
	{
		super(cl, ver, id);
		_dmabuf = dmabuf;
		_surface = surface;
		mixin(onDestroyCallDestroy);
	}

	override protected void destroy(WlClient cl)
	{
	}

	private GpuDevice resolveDevice()
	{
		if (_surface !is null)
		{
			//TODO: Ask IWindowManager about the correct gpu to use for the given surface.
			import trinove.output_manager : OutputManager;
			import trinove.subsystem : SubsystemManager, Services;

			auto waiSurface = cast(WaiSurface) _surface;
			if (waiSurface !is null)
			{
				import trinove.xdg_shell.surface : WaiXdgSurface;
				auto xdg = cast(WaiXdgSurface) waiSurface.role;
				if (xdg !is null)
				{
					import trinove.wm.view : View;

					View view;
					if (xdg.toplevel !is null && xdg.toplevel.window !is null)
						view = xdg.toplevel.window;
					else if (xdg.popup !is null && xdg.popup.popup !is null)
						view = xdg.popup.popup;

					if (view !is null && view.mapped)
					{
						auto om = SubsystemManager.getByService!OutputManager(Services.OutputManager);
						if (om !is null)
						{
							auto mo = om.findPrimaryOutput(view.clientGeometry());
							if (mo !is null && mo.gpuDevice !is null)
								return mo.gpuDevice;
						}
					}
				}
			}
		}

		return RHI.primaryDevice;
	}

	void sendInitialFeedback()
	{
		auto mainDevice = resolveDevice();
		if (mainDevice is null)
		{
			logError("No GPU device for dmabuf feedback");
			postError(0, "No GPU device available for dmabuf feedback");
			return;
		}

		if (!mainDevice.drmInfo.hasRender)
		{
			logError("No DRM render device available");
			postError(0, "No DRM render device available");
			return;
		}

		sendFormatTable(_dmabuf.formatTableFd, _dmabuf.formatTableSize);

		ulong mainDevT = makedev(cast(uint) mainDevice.drmInfo.renderMajor, cast(uint) mainDevice.drmInfo.renderMinor);
		wl_array mainDevArray;
		wl_array_init(&mainDevArray);
		mainDevArray.data = &mainDevT;
		mainDevArray.size = mainDevT.sizeof;
		mainDevArray.alloc = 0;
		sendMainDevice(&mainDevArray);

		foreach (dev; RHI.allDevices)
		{
			auto info = dev.drmInfo;
			if (!info.hasRender)
				continue;

			auto devIndices = _dmabuf.formatsForDevice(dev);
			if (devIndices.length == 0)
				continue;

			ulong devT = makedev(cast(uint) info.renderMajor, cast(uint) info.renderMinor);
			wl_array devArray;
			wl_array_init(&devArray);
			devArray.data = &devT;
			devArray.size = devT.sizeof;
			devArray.alloc = 0;

			wl_array indicesArray;
			wl_array_init(&indicesArray);
			indicesArray.data = cast(void*) devIndices.ptr;
			indicesArray.size = devIndices.length * ushort.sizeof;
			indicesArray.alloc = 0;

			sendTrancheTargetDevice(&devArray);
			sendTrancheFlags(cast(TrancheFlags) 0);
			sendTrancheFormats(&indicesArray);
			sendTrancheDone();
		}

		sendDone();
	}
}

private void closeUniqueFds(LocalPlane[] planes)
{
	stat_t[4] seen;
	int nSeen;
	foreach (ref plane; planes)
	{
		if (plane.fd < 0)
			continue;
		stat_t st;
		bool skip = false;
		if (fstat(plane.fd, &st) == 0)
		{
			foreach (ref s; seen[0 .. nSeen])
				if (s.st_ino == st.st_ino && s.st_dev == st.st_dev)
				{
					skip = true;
					break;
				}
			if (!skip)
				seen[nSeen++] = st;
		}
		if (!skip)
			close(plane.fd);
		plane.fd = -1;
	}
}

// Buffer params collector for dmabuf creation
class WaiLinuxBufferParams : ZwpLinuxBufferParamsV1
{
	private
	{
		LocalPlane[4] _planes;
		uint _planeCount;
		ulong _modifier = DRM_FORMAT_MOD_INVALID;
		bool _used;
	}

	this(WlClient cl, uint ver, uint id)
	{
		super(cl, ver, id);
		mixin(onDestroyCallDestroy);
	}

	override protected void destroy(WlClient cl)
	{
		closeUniqueFds(_planes[0 .. _planeCount]);
	}

	override protected void add(WlClient cl, int fd, uint planeIdx, uint offset, uint stride, uint modifierHi, uint modifierLo)
	{
		if (planeIdx >= 4)
		{
			postError(Error.planeIdx, "plane index %d out of bounds", planeIdx);
			close(fd);
			return;
		}

		if (_planes[planeIdx].fd >= 0)
		{
			postError(Error.planeSet, "plane %d already set", planeIdx);
			close(fd);
			return;
		}

		ulong modifier = (cast(ulong) modifierHi << 32) | modifierLo;

		// Check modifier consistency
		if (_planeCount > 0 && _modifier != modifier)
		{
			postError(Error.invalidFormat, "all planes must use the same modifier");
			close(fd);
			return;
		}

		_modifier = modifier;
		_planes[planeIdx].fd = fd;
		_planes[planeIdx].offset = offset;
		_planes[planeIdx].stride = stride;
		_planeCount = _planeCount > planeIdx + 1 ? _planeCount : planeIdx + 1;
	}

	override protected void create(WlClient cl, int width, int height, uint format, Flags flags)
	{
		if (_used)
		{
			postError(Error.alreadyUsed, "params already used");
			return;
		}
		_used = true;

		if (width <= 0 || height <= 0)
		{
			postError(Error.invalidDimensions, "invalid dimensions %dx%d", width, height);
			return;
		}

		// Try to create the buffer
		auto buffer = tryCreateBuffer(cl, width, height, format, flags);
		if (buffer !is null)
		{
			sendCreated(buffer.id);
		}
		else
		{
			sendFailed();
		}
	}

	override protected WlBuffer createImmed(WlClient cl, uint bufferId, int width, int height, uint format, Flags flags)
	{
		if (_used)
		{
			postError(Error.alreadyUsed, "params already used");
			return null;
		}
		_used = true;

		if (width <= 0 || height <= 0)
		{
			postError(Error.invalidDimensions, "invalid dimensions %dx%d", width, height);
			return null;
		}

		auto buffer = tryCreateBuffer(cl, width, height, format, flags, bufferId);
		if (buffer is null)
		{
			postError(Error.invalidWlBuffer, "failed to import dmabuf");
			return null;
		}

		return buffer;
	}

	private DmaBufBuffer tryCreateBuffer(WlClient cl, int width, int height, uint format, Flags flags, uint bufferId = 0)
	{
		// Validate we have at least one plane
		if (_planeCount == 0 || _planes[0].fd < 0)
		{
			logError("No planes provided for dmabuf");
			return null;
		}

		// Create the buffer object
		auto buffer = new DmaBufBuffer(cl, width, height, format, _modifier, _planes[0 .. _planeCount], flags, bufferId);

		// Transfer ownership of FDs to the buffer
		foreach (ref plane; _planes[0 .. _planeCount])
			plane.fd = -1;
		_planeCount = 0;

		return buffer;
	}
}

// DMA-BUF backed buffer implementing IWaylandBuffer
class DmaBufBuffer : WlBuffer, IWaylandBuffer
{
	private
	{
		uint _width;
		uint _height;
		ZwpLinuxBufferParamsV1.Flags _flags;
		bool _destroyed    : 1; // client sent wl_buffer.destroy
		bool _accessActive : 1; // between fetch() (beginAccess) and release() (endAccess)

		SharedTexture2D _sharedTexture;
	}

	this(WlClient cl, int width, int height, uint format, ulong modifier, LocalPlane[] planes,
			ZwpLinuxBufferParamsV1.Flags flags, uint bufferId = 0)
	{
		// Create the wl_buffer resource (bufferId=0 means server-assigned for async create)
		super(cl, WlBuffer.ver, bufferId);
		mixin(onDestroyCallDestroy);

		_width = width;
		_height = height;
		_flags = flags;

		// Convert local planes to DmaBufPlane for SharedTexture2D
		DmaBufPlane[4] dmabufPlanes;
		foreach (i, ref plane; planes)
		{
			dmabufPlanes[i].fd = plane.fd;
			dmabufPlanes[i].offset = plane.offset;
			dmabufPlanes[i].stride = plane.stride;
		}

		// Import via SharedTexture2D
		auto device = RHI.primaryDevice;
		if (device !is null)
		{
			_sharedTexture = SharedTexture2D.importDmaBuf(device, width, height, format, modifier, dmabufPlanes[0 .. planes
					.length]);

			if (_sharedTexture is null)
			{
				logError("Failed to import dmabuf into WebGPU");
			}
		}
		else
		{
			logError("No GPU device available for dmabuf import");
		}

		closeUniqueFds(planes);
	}

	override void destroy(WlClient cl)
	{
		if (_destroyed)
			return;
		_destroyed = true;
		if (!_accessActive && _sharedTexture !is null)
		{
			_sharedTexture.destroy();
			_sharedTexture = null;
		}
	}

	Vector2U getImageSize()
	{
		return Vector2U(_width, _height);
	}

	// Get the texture as ITexture interface for rendering
	ITexture getITexture()
	{
		return _sharedTexture;
	}

	void fetch()
	{
		if (_sharedTexture !is null)
		{
			_sharedTexture.beginAccess(_sharedTexture.device);
			_accessActive = true;
		}
	}

	void release()
	{
		_accessActive = false;
		if (_sharedTexture !is null)
			_sharedTexture.endAccess(_sharedTexture.device);

		if (_destroyed)
		{
			if (_sharedTexture !is null)
			{
				_sharedTexture.destroy();
				_sharedTexture = null;
			}
		}
		else
		{
			sendRelease();
		}
	}

	const(ubyte)[] getPixelData()
	{
		// DMA-BUF pixel data is in GPU memory, while we could read it back to CPU,
		// this function is really just for cursor images and those should use SHM buffers anyway.
		return null;
	}
}
