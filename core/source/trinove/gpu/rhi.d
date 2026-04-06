// SPDX-License-Identifier: MPL-2.0
// Copyright (C) 2026 Reece Hagan

module trinove.gpu.rhi;

import dawned;
import trinove.log;
import trinove.events : OnQueueWorkDone;
import std.string : fromStringz;

// DRM device identification for linux-dmabuf
struct DrmDeviceInfo
{
	bool hasRender; // Has a render-only node (/dev/dri/renderDN)
	bool hasPrimary; // Has a primary node (/dev/dri/cardN)
	ulong renderMajor;
	ulong renderMinor;
	ulong primaryMajor;
	ulong primaryMinor;
}

// GPU Device wrapper, holds WebGPU device, queue, and adapter info
class GpuDevice
{
	private WGPUDevice _device;
	private WGPUQueue _queue;
	private WGPUAdapter _adapter;
	private string _name;
	private WGPUBackendType _backendType;
	private WGPUAdapterType _adapterType;
	private string _vendor;
	private string _architecture;
	private string _description;
	private uint _vendorID;
	private uint _deviceID;
	private DrmDeviceInfo _drmInfo;

	package this(WGPUAdapter adapter, WGPUDevice device, string name, WGPUAdapterInfo info, WGPUAdapterPropertiesDrm drmProps)
	{
		_adapter = adapter;
		_device = device;
		_name = name;
		_queue = wgpuDeviceGetQueue(device);

		_backendType = info.backendType;
		_adapterType = info.adapterType;
		_vendorID = info.vendorId;
		_deviceID = info.deviceId;

		if (info.vendor.data !is null)
			_vendor = cast(string) info.vendor.data[0 .. info.vendor.length].idup;
		if (info.architecture.data !is null)
			_architecture = cast(string) info.architecture.data[0 .. info.architecture.length].idup;
		if (info.description.data !is null)
			_description = cast(string) info.description.data[0 .. info.description.length].idup;

		_drmInfo = DrmDeviceInfo(drmProps.hasRender != 0, drmProps.hasPrimary != 0, drmProps.renderMajor,
				drmProps.renderMinor, drmProps.primaryMajor, drmProps.primaryMinor);
	}

	@property string name() => _name;
	@property WGPUDevice handle() => _device;
	@property WGPUQueue queue() => _queue;
	@property WGPUAdapter adapter() => _adapter;
	@property WGPUBackendType backendType() => _backendType;
	@property WGPUAdapterType adapterType() => _adapterType;
	@property string vendor() => _vendor;
	@property string architecture() => _architecture;
	@property string description() => _description;
	@property uint vendorID() => _vendorID;
	@property uint deviceID() => _deviceID;
	@property ref const(DrmDeviceInfo) drmInfo() => _drmInfo;

	@property string backendName()
	{
		switch (_backendType)
		{
		case WGPUBackendType.undefined:
			return "Undefined";
		case WGPUBackendType.null_:
			return "Null";
		case WGPUBackendType.webgpu:
			return "WebGPU";
		case WGPUBackendType.d3d11:
			return "D3D11";
		case WGPUBackendType.d3d12:
			return "D3D12";
		case WGPUBackendType.metal:
			return "Metal";
		case WGPUBackendType.vulkan:
			return "Vulkan";
		case WGPUBackendType.opengl:
			return "OpenGL";
		case WGPUBackendType.opengles:
			return "OpenGL ES";
		default:
			return "Unknown";
		}
	}

	@property string adapterTypeName()
	{
		switch (_adapterType)
		{
		case WGPUAdapterType.discreteGpu:
			return "Discrete GPU";
		case WGPUAdapterType.integratedGpu:
			return "Integrated GPU";
		case WGPUAdapterType.cpu:
			return "CPU";
		case WGPUAdapterType.unknown:
			return "Unknown";
		default:
			return "Unknown";
		}
	}

	// Request notification when all currently submitted GPU work is complete.
	// Fires OnQueueWorkDone event with this device.
	void notifyOnWorkDone()
	{
		WGPUQueueWorkDoneCallbackInfo callbackInfo;
		callbackInfo.mode = WGPUCallbackMode.allowSpontaneous;
		callbackInfo.callback = &queueWorkDoneCallback;
		callbackInfo.userdata1 = cast(void*) this;

		wgpuQueueOnSubmittedWorkDone(_queue, callbackInfo);
	}

	private static extern (C) void queueWorkDoneCallback(WGPUQueueWorkDoneStatus status, WGPUStringView message,
			void* userdata1, void* userdata2)
	{
		auto device = cast(GpuDevice) userdata1;

		if (status != WGPUQueueWorkDoneStatus.success)
		{
			string msg = message.data !is null ? cast(string) message.data[0 .. message.length] : "unknown error";
			logError("[GpuDevice] Queue work done failed: %s", msg);
			return;
		}

		OnQueueWorkDone.fire(device);
	}

	// Wait for all submitted GPU work to complete
	void waitForIdle()
	{
		if (_device is null || _queue is null)
			return;

		wgpuQueueSubmit(_queue, 0, null);

		bool done = false;

		WGPUQueueWorkDoneCallbackInfo callbackInfo;
		callbackInfo.mode = WGPUCallbackMode.allowSpontaneous;
		callbackInfo.callback = &idleCallback;
		callbackInfo.userdata1 = cast(void*)&done;

		wgpuQueueOnSubmittedWorkDone(_queue, callbackInfo);

		while (!done)
			wgpuDeviceTick(_device);
	}

	private static extern (C) void idleCallback(WGPUQueueWorkDoneStatus, WGPUStringView, void* userdata1, void*) nothrow @nogc
	{
		if (userdata1 !is null)
			*cast(bool*) userdata1 = true;
	}

	package void destroy()
	{
		if (_queue)
		{
			wgpuQueueRelease(_queue);
			_queue = null;
		}
		if (_device)
		{
			wgpuDeviceRelease(_device);
			_device = null;
		}
		if (_adapter)
		{
			wgpuAdapterRelease(_adapter);
			_adapter = null;
		}
	}
}

// Static global for WebGPU management
// We don't plan on supporting other backends as WebGPU/Dawn will prob be
// our only graphics API. If you are trying to change it, I pray for you.
struct RHI
{
	private __gshared WGPUInstance _instance;
	private __gshared GpuDevice[] _devices;
	private __gshared GpuDevice _primaryDevice;
	private __gshared WGPUBackendType _backendType;
	private __gshared bool _initialized;

	static bool initialize()
	{
		if (_initialized)
		{
			logWarn("RHI already initialized");
			return true;
		}

		logInfo("Initializing RHI...");

		WGPUInstanceDescriptor instanceDesc;
		_instance = wgpuCreateInstance(&instanceDesc);

		if (_instance is null)
		{
			logError("Failed to create WebGPU instance");
			return false;
		}

		if (!enumerateDevices())
		{
			logError("Failed to enumerate GPU devices");
			wgpuInstanceRelease(_instance);
			_instance = null;
			return false;
		}

		_initialized = true;
		logInfo("RHI initialized with %d device(s), primary: %s", _devices.length, _primaryDevice.name);
		return true;
	}

	static void shutdown()
	{
		if (!_initialized)
			return;

		logInfo("Shutting down RHI...");

		foreach (device; _devices)
		{
			device.destroy();
		}
		_devices = null;
		_primaryDevice = null;

		if (_instance)
		{
			wgpuInstanceRelease(_instance);
			_instance = null;
		}

		_initialized = false;
		logInfo("RHI shutdown complete");
	}

	private static bool enumerateDevices()
	{
		// Primary: prefer discrete GPU with a fall back to any adapter.
		// TODO: Set primary to what ever CRTC we can get our hands on, should be good for laptops?
		auto primaryAdapter = requestAdapter(WGPUPowerPreference.highPerformance);
		if (primaryAdapter is null)
		{
			logWarn("No high-performance adapter, trying default...");
			primaryAdapter = requestAdapter(WGPUPowerPreference.undefined);
		}
		if (primaryAdapter is null)
		{
			logError("No WebGPU adapter available");
			return false;
		}

		auto primary = tryCreateDevice(primaryAdapter);
		if (primary is null)
			return false;

		_devices ~= primary;
		_primaryDevice = primary;
		_backendType = primary.backendType;

		auto lowPowerAdapter = requestAdapter(WGPUPowerPreference.lowPower);
		if (lowPowerAdapter !is null)
		{
			auto secondaryDrm = queryAdapterDrmInfo(lowPowerAdapter);
			if (!isSamePhysicalDevice(primary.drmInfo, secondaryDrm))
			{
				auto secondary = tryCreateDevice(lowPowerAdapter);
				if (secondary !is null)
				{
					_devices ~= secondary;
					logInfo("Secondary GPU: %s", secondary.name);
				}
			}
			else
			{
				wgpuAdapterRelease(lowPowerAdapter);
			}
		}

		logInfo("RHI: %d device(s) enumerated, primary: %s", _devices.length, _primaryDevice.name);
		return true;
	}

	private static DrmDeviceInfo queryAdapterDrmInfo(WGPUAdapter adapter)
	{
		WGPUAdapterPropertiesDrm drmProps;
		drmProps.chain.sType = WGPUSType.adapterPropertiesDrm;
		WGPUAdapterInfo info;
		info.nextInChain = &drmProps.chain;
		wgpuAdapterGetInfo(adapter, &info);
		wgpuAdapterInfoFreeMembers(info);
		return DrmDeviceInfo(drmProps.hasRender != 0, drmProps.hasPrimary != 0, drmProps.renderMajor,
				drmProps.renderMinor, drmProps.primaryMajor, drmProps.primaryMinor);
	}

	// Try to create a GpuDevice from a WGPUAdapter.
	// Takes ownership of the adapter and releases it on failure, GpuDevice owns it on success.
	private static GpuDevice tryCreateDevice(WGPUAdapter adapter)
	{
		WGPUAdapterPropertiesDrm drmProps;
		drmProps.chain.sType = WGPUSType.adapterPropertiesDrm;

		WGPUAdapterInfo info;
		info.nextInChain = &drmProps.chain;
		wgpuAdapterGetInfo(adapter, &info);
		scope (exit)
			wgpuAdapterInfoFreeMembers(info);

		string adapterName = "Unknown";
		if (info.device.data !is null)
			adapterName = cast(string) info.device.data[0 .. info.device.length].idup;

		logInfo("Adapter: %s (backend: %s, type: %s)", adapterName, backendTypeToString(info.backendType),
				adapterTypeToString(info.adapterType));
		if (drmProps.hasRender)
			logInfo("  DRM render: %d:%d", drmProps.renderMajor, drmProps.renderMinor);
		if (drmProps.hasPrimary)
			logInfo("  DRM primary: %d:%d", drmProps.primaryMajor, drmProps.primaryMinor);

		WGPUFeatureName[8] requiredFeatures;
		size_t featureCount = 0;

		if (wgpuAdapterHasFeature(adapter, WGPUFeatureName.sharedTextureMemoryDmaBuf))
		{
			requiredFeatures[featureCount++] = WGPUFeatureName.sharedTextureMemoryDmaBuf;
			logInfo("  Feature: SharedTextureMemoryDmaBuf");
		}
		if (wgpuAdapterHasFeature(adapter, WGPUFeatureName.sharedFenceVkSemaphoreOpaqueFd))
		{
			requiredFeatures[featureCount++] = WGPUFeatureName.sharedFenceVkSemaphoreOpaqueFd;
			logInfo("  Feature: SharedFenceVkSemaphoreOpaqueFD");
		}

		WGPUDeviceDescriptor deviceDesc;
		deviceDesc.uncapturedErrorCallbackInfo.callback = &deviceErrorCallback;
		deviceDesc.requiredFeatureCount = featureCount;
		deviceDesc.requiredFeatures = featureCount > 0 ? requiredFeatures.ptr : null;

		auto wgpuDevice = wgpuAdapterCreateDevice(adapter, &deviceDesc);
		if (wgpuDevice is null)
		{
			logError("Failed to create WebGPU device for adapter '%s'", adapterName);
			wgpuAdapterRelease(adapter);
			return null;
		}

		return new GpuDevice(adapter, wgpuDevice, adapterName, info, drmProps);
	}

	// Returns true if a and b refer to the same underlying physical GPU.
	private static bool isSamePhysicalDevice(ref const DrmDeviceInfo a, ref const DrmDeviceInfo b)
	{
		if (a.hasRender && b.hasRender)
			return a.renderMajor == b.renderMajor && a.renderMinor == b.renderMinor;
		if (a.hasPrimary && b.hasPrimary)
			return a.primaryMajor == b.primaryMajor && a.primaryMinor == b.primaryMinor;
		return false;
	}

	private static WGPUAdapter requestAdapter(WGPUPowerPreference powerPref)
	{
		WGPURequestAdapterOptions options;
		options.powerPreference = powerPref;

		__gshared WGPUAdapter resultAdapter;
		__gshared bool callbackDone;
		resultAdapter = null;
		callbackDone = false;

		WGPURequestAdapterCallbackInfo callbackInfo;
		callbackInfo.mode = WGPUCallbackMode.waitAnyOnly;
		callbackInfo.callback = &adapterRequestCallback;
		callbackInfo.userdata1 = &resultAdapter;
		callbackInfo.userdata2 = &callbackDone;

		auto future = wgpuInstanceRequestAdapter(_instance, &options, callbackInfo);

		WGPUFutureWaitInfo waitInfo;
		waitInfo.future = future;

		auto waitStatus = wgpuInstanceWaitAny(_instance, 1, &waitInfo, 0);

		if (waitStatus != WGPUWaitStatus.success)
		{
			logError("Failed to wait for adapter request: %d", waitStatus);
			return null;
		}

		return resultAdapter;
	}

	extern (C) private static void adapterRequestCallback(WGPURequestAdapterStatus status, WGPUAdapter adapter,
			WGPUStringView message, void* userdata1, void* userdata2)
	{
		auto resultPtr = cast(WGPUAdapter*) userdata1;
		auto donePtr = cast(bool*) userdata2;

		if (status == WGPURequestAdapterStatus.success)
		{
			*resultPtr = adapter;
		}
		else
		{
			string msg = message.data !is null ? cast(string) message.data[0 .. message.length] : "unknown error";
			logError("Adapter request failed: %s", msg);
			*resultPtr = null;
		}
		*donePtr = true;
	}

	extern (C) private static void deviceErrorCallback(const(WGPUDevice)* device, WGPUErrorType type,
			WGPUStringView message, void* userdata1, void* userdata2)
	{
		string msg = message.data !is null ? cast(string) message.data[0 .. message.length] : "no message";

		final switch (type)
		{
		case WGPUErrorType.validation:
			logError("[WebGPU Validation] %s", msg);
			break;
		case WGPUErrorType.outOfMemory:
			logError("[WebGPU OOM] %s", msg);
			break;
		case WGPUErrorType.internal:
			logError("[WebGPU Internal] %s", msg);
			break;
		case WGPUErrorType.unknown:
			logError("[WebGPU Unknown] %s", msg);
			break;
		case WGPUErrorType.noError:
			break;
		}
	}

	// --- Device Access ---

	static @property bool initialized() => _initialized;
	static @property GpuDevice primaryDevice() => _primaryDevice;
	static @property GpuDevice[] allDevices() => _devices;
	static @property WGPUInstance instance() => _instance;
	static @property WGPUBackendType backendType() => _backendType;
	static @property bool isVulkan() => _backendType == WGPUBackendType.vulkan;

	// --- Helpers ---

	private static string backendTypeToString(WGPUBackendType t)
	{
		final switch (t)
		{
		case WGPUBackendType.undefined:
			return "undefined";
		case WGPUBackendType.null_:
			return "null";
		case WGPUBackendType.webgpu:
			return "WebGPU";
		case WGPUBackendType.d3d11:
			return "D3D11";
		case WGPUBackendType.d3d12:
			return "D3D12";
		case WGPUBackendType.metal:
			return "Metal";
		case WGPUBackendType.vulkan:
			return "Vulkan";
		case WGPUBackendType.opengl:
			return "OpenGL";
		case WGPUBackendType.opengles:
			return "OpenGLES";
		}
	}

	private static string adapterTypeToString(WGPUAdapterType t)
	{
		final switch (t)
		{
		case WGPUAdapterType.discreteGpu:
			return "discrete";
		case WGPUAdapterType.integratedGpu:
			return "integrated";
		case WGPUAdapterType.cpu:
			return "CPU";
		case WGPUAdapterType.unknown:
			return "unknown";
		}
	}
}
