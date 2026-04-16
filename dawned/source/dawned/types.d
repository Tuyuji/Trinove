// Auto-generated from dawn.json - DO NOT EDIT

// Copyright 2017 The Dawn & Tint Authors
// 
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
// 
//   1. Redistributions of source code must retain the above copyright notice, this
//      list of conditions and the following disclaimer.
// 
//   2. Redistributions in binary form must reproduce the above copyright notice,
//      this list of conditions and the following disclaimer in the documentation
//      and/or other materials provided with the distribution.
// 
//   3. Neither the name of the copyright holder nor the names of its
//      contributors may be used to endorse or promote products derived from
//      this software without specific prior written permission.
//   
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
module dawned.types;

import core.stdc.stdint;

// Constants

enum uint64_t WGPUWholeSize = uint64_t.max;
enum size_t WGPUWholeMapSize = size_t.max;
enum uint32_t WGPUCopyStrideUndefined = uint32_t.max;
enum uint32_t WGPULimitU32Undefined = uint32_t.max;
enum uint64_t WGPULimitU64Undefined = uint64_t.max;
enum uint32_t WGPUArrayLayerCountUndefined = uint32_t.max;
enum uint32_t WGPUMipLevelCountUndefined = uint32_t.max;
enum float WGPUDepthClearValueUndefined = float.nan;
enum uint32_t WGPUDepthSliceUndefined = uint32_t.max;
enum uint32_t WGPUQuerySetIndexUndefined = uint32_t.max;
enum size_t WGPUStrlen = size_t.max;
enum uint32_t WGPUInvalidBinding = uint32_t.max;

// Built-in Types

alias WGPUBool = uint;

struct WGPUChainedStruct
{
    const(WGPUChainedStruct)* next = null;
    WGPUSType sType;
}

struct WGPUChainedStructOut
{
    WGPUChainedStructOut* next = null;
    WGPUSType sType;
}

// Opaque Handles

struct WGPUAdapterImpl;
alias WGPUAdapter = WGPUAdapterImpl*;
struct WGPUBindGroupImpl;
alias WGPUBindGroup = WGPUBindGroupImpl*;
struct WGPUBindGroupLayoutImpl;
alias WGPUBindGroupLayout = WGPUBindGroupLayoutImpl*;
struct WGPUBufferImpl;
alias WGPUBuffer = WGPUBufferImpl*;
struct WGPUCommandBufferImpl;
alias WGPUCommandBuffer = WGPUCommandBufferImpl*;
struct WGPUCommandEncoderImpl;
alias WGPUCommandEncoder = WGPUCommandEncoderImpl*;
struct WGPUComputePassEncoderImpl;
alias WGPUComputePassEncoder = WGPUComputePassEncoderImpl*;
struct WGPUComputePipelineImpl;
alias WGPUComputePipeline = WGPUComputePipelineImpl*;
struct WGPUDeviceImpl;
alias WGPUDevice = WGPUDeviceImpl*;
struct WGPUExternalTextureImpl;
alias WGPUExternalTexture = WGPUExternalTextureImpl*;
struct WGPUSharedBufferMemoryImpl;
alias WGPUSharedBufferMemory = WGPUSharedBufferMemoryImpl*;
struct WGPUSharedTextureMemoryImpl;
alias WGPUSharedTextureMemory = WGPUSharedTextureMemoryImpl*;
struct WGPUSharedFenceImpl;
alias WGPUSharedFence = WGPUSharedFenceImpl*;
struct WGPUInstanceImpl;
alias WGPUInstance = WGPUInstanceImpl*;
struct WGPUPipelineLayoutImpl;
alias WGPUPipelineLayout = WGPUPipelineLayoutImpl*;
struct WGPUQuerySetImpl;
alias WGPUQuerySet = WGPUQuerySetImpl*;
struct WGPUQueueImpl;
alias WGPUQueue = WGPUQueueImpl*;
struct WGPURenderBundleImpl;
alias WGPURenderBundle = WGPURenderBundleImpl*;
struct WGPURenderBundleEncoderImpl;
alias WGPURenderBundleEncoder = WGPURenderBundleEncoderImpl*;
struct WGPURenderPassEncoderImpl;
alias WGPURenderPassEncoder = WGPURenderPassEncoderImpl*;
struct WGPURenderPipelineImpl;
alias WGPURenderPipeline = WGPURenderPipelineImpl*;
struct WGPUResourceTableImpl;
alias WGPUResourceTable = WGPUResourceTableImpl*;
struct WGPUSamplerImpl;
alias WGPUSampler = WGPUSamplerImpl*;
struct WGPUShaderModuleImpl;
alias WGPUShaderModule = WGPUShaderModuleImpl*;
struct WGPUSurfaceImpl;
alias WGPUSurface = WGPUSurfaceImpl*;
struct WGPUTextureImpl;
alias WGPUTexture = WGPUTextureImpl*;
struct WGPUTextureViewImpl;
alias WGPUTextureView = WGPUTextureViewImpl*;
struct WGPUTexelBufferViewImpl;
alias WGPUTexelBufferView = WGPUTexelBufferViewImpl*;

// Enums

enum WGPURequestAdapterStatus : uint
{
    success = 0x00000001,
    callbackCancelled = 0x00000002,
    unavailable = 0x00000003,
    error = 0x00000004,
}

enum WGPUAdapterType : uint
{
    discreteGpu = 0x00000001,
    integratedGpu = 0x00000002,
    cpu = 0x00000003,
    unknown = 0x00000004,
}

enum WGPUAddressMode : uint
{
    undefined = 0x00000000,
    clampToEdge = 0x00000001,
    repeat = 0x00000002,
    mirrorRepeat = 0x00000003,
}

enum WGPUBackendType : uint
{
    undefined = 0x00000000,
    null_ = 0x00000001,
    webgpu = 0x00000002,
    d3d11 = 0x00000003,
    d3d12 = 0x00000004,
    metal = 0x00000005,
    vulkan = 0x00000006,
    opengl = 0x00000007,
    opengles = 0x00000008,
}

enum WGPUBufferBindingType : uint
{
    bindingNotUsed = 0x00000000,
    undefined = 0x00000001,
    uniform = 0x00000002,
    storage = 0x00000003,
    readOnlyStorage = 0x00000004,
}

enum WGPUSamplerBindingType : uint
{
    bindingNotUsed = 0x00000000,
    undefined = 0x00000001,
    filtering = 0x00000002,
    nonFiltering = 0x00000003,
    comparison = 0x00000004,
}

enum WGPUTextureSampleType : uint
{
    bindingNotUsed = 0x00000000,
    undefined = 0x00000001,
    float_ = 0x00000002,
    unfilterableFloat = 0x00000003,
    depth = 0x00000004,
    sint = 0x00000005,
    uint_ = 0x00000006,
}

enum WGPUStorageTextureAccess : uint
{
    bindingNotUsed = 0x00000000,
    undefined = 0x00000001,
    writeOnly = 0x00000002,
    readOnly = 0x00000003,
    readWrite = 0x00000004,
}

enum WGPUTexelBufferAccess : uint
{
    undefined = 0x00000000,
    readOnly = 0x00000001,
    readWrite = 0x00000002,
}

enum WGPUBlendFactor : uint
{
    undefined = 0x00000000,
    zero = 0x00000001,
    one = 0x00000002,
    src = 0x00000003,
    oneMinusSrc = 0x00000004,
    srcAlpha = 0x00000005,
    oneMinusSrcAlpha = 0x00000006,
    dst = 0x00000007,
    oneMinusDst = 0x00000008,
    dstAlpha = 0x00000009,
    oneMinusDstAlpha = 0x0000000A,
    srcAlphaSaturated = 0x0000000B,
    constant = 0x0000000C,
    oneMinusConstant = 0x0000000D,
    src1 = 0x0000000E,
    oneMinusSrc1 = 0x0000000F,
    src1Alpha = 0x00000010,
    oneMinusSrc1Alpha = 0x00000011,
}

enum WGPUBlendOperation : uint
{
    undefined = 0x00000000,
    add = 0x00000001,
    subtract = 0x00000002,
    reverseSubtract = 0x00000003,
    min = 0x00000004,
    max = 0x00000005,
}

enum WGPUOptionalBool : uint
{
    false_ = 0x00000000,
    true_ = 0x00000001,
    undefined = 0x00000002,
}

enum WGPUMapAsyncStatus : uint
{
    success = 0x00000001,
    callbackCancelled = 0x00000002,
    error = 0x00000003,
    aborted = 0x00000004,
}

enum WGPUBufferMapState : uint
{
    unmapped = 0x00000001,
    pending = 0x00000002,
    mapped = 0x00000003,
}

enum WGPUCompareFunction : uint
{
    undefined = 0x00000000,
    never = 0x00000001,
    less = 0x00000002,
    equal = 0x00000003,
    lessEqual = 0x00000004,
    greater = 0x00000005,
    notEqual = 0x00000006,
    greaterEqual = 0x00000007,
    always = 0x00000008,
}

enum WGPUCompilationInfoRequestStatus : uint
{
    success = 0x00000001,
    callbackCancelled = 0x00000002,
}

enum WGPUCompilationMessageType : uint
{
    error = 0x00000001,
    warning = 0x00000002,
    info = 0x00000003,
}

enum WGPUCompositeAlphaMode : uint
{
    auto_ = 0x00000000,
    opaque = 0x00000001,
    premultiplied = 0x00000002,
    unpremultiplied = 0x00000003,
    inherit = 0x00000004,
}

enum WGPUAlphaMode : uint
{
    opaque = 0x00000001,
    premultiplied = 0x00000002,
    unpremultiplied = 0x00000003,
}

enum WGPUCreatePipelineAsyncStatus : uint
{
    success = 0x00000001,
    callbackCancelled = 0x00000002,
    validationError = 0x00000003,
    internalError = 0x00000004,
}

enum WGPUCullMode : uint
{
    undefined = 0x00000000,
    none = 0x00000001,
    front = 0x00000002,
    back = 0x00000003,
}

enum WGPUDeviceLostReason : uint
{
    unknown = 0x00000001,
    destroyed = 0x00000002,
    callbackCancelled = 0x00000003,
    failedCreation = 0x00000004,
}

enum WGPUPopErrorScopeStatus : uint
{
    success = 0x00000001,
    callbackCancelled = 0x00000002,
    error = 0x00000003,
}

enum WGPUErrorFilter : uint
{
    validation = 0x00000001,
    outOfMemory = 0x00000002,
    internal = 0x00000003,
}

enum WGPUErrorType : uint
{
    noError = 0x00000001,
    validation = 0x00000002,
    outOfMemory = 0x00000003,
    internal = 0x00000004,
    unknown = 0x00000005,
}

enum WGPULoggingType : uint
{
    verbose = 0x00000001,
    info = 0x00000002,
    warning = 0x00000003,
    error = 0x00000004,
}

enum WGPUExternalTextureRotation : uint
{
    rotate0Degrees = 0x00000001,
    rotate90Degrees = 0x00000002,
    rotate180Degrees = 0x00000003,
    rotate270Degrees = 0x00000004,
}

enum WGPUColorSpacePrimariesDawn : uint
{
    srgb = 0x00000001,
    rec709 = 0x00000001,
    rec601 = 0x00000002,
    rec2020 = 0x00000003,
    displayP3 = 0x00000004,
}

enum WGPUColorSpaceTransferDawn : uint
{
    identity = 0x00000001,
    srgb = 0x00000002,
    displayP3 = 0x00000003,
    smpte_170m = 0x00000004,
    hlg = 0x00000005,
    pq = 0x00000006,
}

enum WGPUColorSpaceYCbCrRangeDawn : uint
{
    identity = 0x00000001,
    narrow = 0x00000002,
    full = 0x00000003,
}

enum WGPUColorSpaceYCbCrMatrixDawn : uint
{
    identity = 0x00000001,
    rec601 = 0x00000002,
    rec709 = 0x00000003,
    rec2020 = 0x00000004,
}

enum WGPUStatus : uint
{
    success = 0x00000001,
    error = 0x00000002,
}

enum WGPUSharedFenceType : uint
{
    vkSemaphoreOpaqueFd = 0x00000001,
    syncFd = 0x00000002,
    vkSemaphoreZirconHandle = 0x00000003,
    dxgiSharedHandle = 0x00000004,
    mtlSharedEvent = 0x00000005,
    eglSync = 0x00000006,
}

enum WGPUFeatureLevel : uint
{
    undefined = 0x00000000,
    compatibility = 0x00000001,
    core = 0x00000002,
}

enum WGPUFeatureName : uint
{
    coreFeaturesAndLimits = 0x00000001,
    depthClipControl = 0x00000002,
    depth32FloatStencil8 = 0x00000003,
    textureCompressionBc = 0x00000004,
    textureCompressionBcSliced3d = 0x00000005,
    textureCompressionEtc2 = 0x00000006,
    textureCompressionAstc = 0x00000007,
    textureCompressionAstcSliced3d = 0x00000008,
    timestampQuery = 0x00000009,
    indirectFirstInstance = 0x0000000A,
    shaderF16 = 0x0000000B,
    rg11b10UfloatRenderable = 0x0000000C,
    bgra8UnormStorage = 0x0000000D,
    float32Filterable = 0x0000000E,
    float32Blendable = 0x0000000F,
    clipDistances = 0x00000010,
    dualSourceBlending = 0x00000011,
    subgroups = 0x00000012,
    textureFormatsTier1 = 0x00000013,
    textureFormatsTier2 = 0x00000014,
    primitiveIndex = 0x00000015,
    textureComponentSwizzle = 0x00000016,
    dawnInternalUsages = 0x00050000,
    dawnMultiPlanarFormats = 0x00050001,
    dawnNative = 0x00050002,
    chromiumExperimentalTimestampQueryInsidePasses = 0x00050003,
    implicitDeviceSynchronization = 0x00050004,
    transientAttachments = 0x00050006,
    msaaRenderToSingleSampled = 0x00050007,
    d3d11MultithreadProtected = 0x00050008,
    angleTextureSharing = 0x00050009,
    pixelLocalStorageCoherent = 0x0005000A,
    pixelLocalStorageNonCoherent = 0x0005000B,
    unorm16TextureFormats = 0x0005000C,
    multiPlanarFormatExtendedUsages = 0x0005000D,
    multiPlanarFormatP010 = 0x0005000E,
    hostMappedPointer = 0x0005000F,
    multiPlanarRenderTargets = 0x00050010,
    multiPlanarFormatNv12a = 0x00050011,
    framebufferFetch = 0x00050012,
    bufferMapExtendedUsages = 0x00050013,
    adapterPropertiesMemoryHeaps = 0x00050014,
    adapterPropertiesD3d = 0x00050015,
    adapterPropertiesVk = 0x00050016,
    dawnFormatCapabilities = 0x00050017,
    dawnDrmFormatCapabilities = 0x00050018,
    multiPlanarFormatNv16 = 0x00050019,
    multiPlanarFormatNv24 = 0x0005001A,
    multiPlanarFormatP210 = 0x0005001B,
    multiPlanarFormatP410 = 0x0005001C,
    sharedTextureMemoryVkDedicatedAllocation = 0x0005001D,
    sharedTextureMemoryAHardwareBuffer = 0x0005001E,
    sharedTextureMemoryDmaBuf = 0x0005001F,
    sharedTextureMemoryOpaqueFd = 0x00050020,
    sharedTextureMemoryZirconHandle = 0x00050021,
    sharedTextureMemoryDxgiSharedHandle = 0x00050022,
    sharedTextureMemoryD3d11Texture2d = 0x00050023,
    sharedTextureMemoryIoSurface = 0x00050024,
    sharedTextureMemoryEglImage = 0x00050025,
    sharedFenceVkSemaphoreOpaqueFd = 0x00050026,
    sharedFenceSyncFd = 0x00050027,
    sharedFenceVkSemaphoreZirconHandle = 0x00050028,
    sharedFenceDxgiSharedHandle = 0x00050029,
    sharedFenceMtlSharedEvent = 0x0005002A,
    sharedBufferMemoryD3d12Resource = 0x0005002B,
    staticSamplers = 0x0005002C,
    yCbCrVulkanSamplers = 0x0005002D,
    shaderModuleCompilationOptions = 0x0005002E,
    dawnLoadResolveTexture = 0x0005002F,
    dawnPartialLoadResolveTexture = 0x00050030,
    multiDrawIndirect = 0x00050031,
    dawnTexelCopyBufferRowAlignment = 0x00050032,
    flexibleTextureViews = 0x00050033,
    chromiumExperimentalSubgroupMatrix = 0x00050034,
    sharedFenceEglSync = 0x00050035,
    dawnDeviceAllocatorControl = 0x00050036,
    adapterPropertiesWgpu = 0x00050037,
    sharedBufferMemoryD3d12SharedMemoryFileMappingHandle = 0x00050038,
    sharedTextureMemoryD3d12Resource = 0x00050039,
    chromiumExperimentalSamplingResourceTable = 0x0005003A,
    chromiumExperimentalSubgroupSizeControl = 0x0005003B,
    atomicVec2uMinMax = 0x0005003C,
    unorm16FormatsForExternalTexture = 0x0005003D,
    opaqueYCbCrAndroidForExternalTexture = 0x0005003E,
    unorm16Filterable = 0x0005003F,
    renderPassRenderArea = 0x00050040,
    dawnNativeSpontaneousQueueEvents = 0x00050041,
    adapterPropertiesDrm = 0x00050042,
}

enum WGPUFilterMode : uint
{
    undefined = 0x00000000,
    nearest = 0x00000001,
    linear = 0x00000002,
}

enum WGPUFrontFace : uint
{
    undefined = 0x00000000,
    ccw = 0x00000001,
    cw = 0x00000002,
}

enum WGPUIndexFormat : uint
{
    undefined = 0x00000000,
    uint16 = 0x00000001,
    uint32 = 0x00000002,
}

enum WGPUCallbackMode : uint
{
    waitAnyOnly = 0x00000001,
    allowProcessEvents = 0x00000002,
    allowSpontaneous = 0x00000003,
}

enum WGPUWaitStatus : uint
{
    success = 0x00000001,
    timedOut = 0x00000002,
    error = 0x00000003,
}

enum WGPUInstanceFeatureName : uint
{
    timedWaitAny = 0x00000001,
    shaderSourceSpirv = 0x00000002,
    multipleDevicesPerAdapter = 0x00000003,
}

enum WGPUVertexStepMode : uint
{
    undefined = 0x00000000,
    vertex = 0x00000001,
    instance = 0x00000002,
}

enum WGPULoadOp : uint
{
    undefined = 0x00000000,
    load = 0x00000001,
    clear = 0x00000002,
    expandResolveTexture = 0x00050003,
}

enum WGPUMipmapFilterMode : uint
{
    undefined = 0x00000000,
    nearest = 0x00000001,
    linear = 0x00000002,
}

enum WGPUStoreOp : uint
{
    undefined = 0x00000000,
    store = 0x00000001,
    discard = 0x00000002,
}

enum WGPUPowerPreference : uint
{
    undefined = 0x00000000,
    lowPower = 0x00000001,
    highPerformance = 0x00000002,
}

enum WGPUPresentMode : uint
{
    undefined = 0x00000000,
    fifo = 0x00000001,
    fifoRelaxed = 0x00000002,
    immediate = 0x00000003,
    mailbox = 0x00000004,
}

enum WGPUPrimitiveTopology : uint
{
    undefined = 0x00000000,
    pointList = 0x00000001,
    lineList = 0x00000002,
    lineStrip = 0x00000003,
    triangleList = 0x00000004,
    triangleStrip = 0x00000005,
}

enum WGPUQueryType : uint
{
    occlusion = 0x00000001,
    timestamp = 0x00000002,
}

enum WGPUQueueWorkDoneStatus : uint
{
    success = 0x00000001,
    callbackCancelled = 0x00000002,
    error = 0x00000003,
}

enum WGPURequestDeviceStatus : uint
{
    success = 0x00000001,
    callbackCancelled = 0x00000002,
    error = 0x00000003,
}

enum WGPUStencilOperation : uint
{
    undefined = 0x00000000,
    keep = 0x00000001,
    zero = 0x00000002,
    replace = 0x00000003,
    invert = 0x00000004,
    incrementClamp = 0x00000005,
    decrementClamp = 0x00000006,
    incrementWrap = 0x00000007,
    decrementWrap = 0x00000008,
}

enum WGPUPredefinedColorSpace : uint
{
    srgb = 0x00000001,
    displayP3 = 0x00000002,
    srgbLinear = 0x00050003,
    displayP3Linear = 0x00050004,
}

enum WGPUToneMappingMode : uint
{
    standard = 0x00000001,
    extended = 0x00000002,
}

enum WGPUSType : uint
{
    shaderSourceSpirv = 0x00000001,
    shaderSourceWgsl = 0x00000002,
    renderPassMaxDrawCount = 0x00000003,
    surfaceSourceMetalLayer = 0x00000004,
    surfaceSourceWindowsHwnd = 0x00000005,
    surfaceSourceXlibWindow = 0x00000006,
    surfaceSourceWaylandSurface = 0x00000007,
    surfaceSourceAndroidNativeWindow = 0x00000008,
    surfaceSourceXcbWindow = 0x00000009,
    surfaceColorManagement = 0x0000000A,
    requestAdapterWebxrOptions = 0x0000000B,
    textureComponentSwizzleDescriptor = 0x0000000C,
    externalTextureBindingLayout = 0x0000000D,
    externalTextureBindingEntry = 0x0000000E,
    compatibilityModeLimits = 0x0000000F,
    textureBindingViewDimension = 0x00000010,
    surfaceDescriptorFromWindowsCoreWindow = 0x00050000,
    surfaceDescriptorFromWindowsUwpSwapChainPanel = 0x00050003,
    dawnTextureInternalUsageDescriptor = 0x00050004,
    dawnEncoderInternalUsageDescriptor = 0x00050005,
    dawnInstanceDescriptor = 0x00050006,
    dawnCacheDeviceDescriptor = 0x00050007,
    dawnAdapterPropertiesPowerPreference = 0x00050008,
    dawnBufferDescriptorErrorInfoFromWireClient = 0x00050009,
    dawnTogglesDescriptor = 0x0005000A,
    dawnShaderModuleSpirvOptionsDescriptor = 0x0005000B,
    requestAdapterOptionsLuid = 0x0005000C,
    requestAdapterOptionsGetGlProc = 0x0005000D,
    requestAdapterOptionsD3d11Device = 0x0005000E,
    dawnRenderPassSampleCount = 0x0005000F,
    renderPassPixelLocalStorage = 0x00050010,
    pipelineLayoutPixelLocalStorage = 0x00050011,
    bufferHostMappedPointer = 0x00050012,
    adapterPropertiesMemoryHeaps = 0x00050013,
    adapterPropertiesD3d = 0x00050014,
    adapterPropertiesVk = 0x00050015,
    dawnWireWgslControl = 0x00050016,
    dawnWgslBlocklist = 0x00050017,
    dawnDrmFormatCapabilities = 0x00050018,
    shaderModuleCompilationOptions = 0x00050019,
    colorTargetStateExpandResolveTextureDawn = 0x0005001A,
    renderPassRenderAreaRect = 0x0005001B,
    sharedTextureMemoryVkDedicatedAllocationDescriptor = 0x0005001C,
    sharedTextureMemoryAHardwareBufferDescriptor = 0x0005001D,
    sharedTextureMemoryDmaBufDescriptor = 0x0005001E,
    sharedTextureMemoryOpaqueFdDescriptor = 0x0005001F,
    sharedTextureMemoryZirconHandleDescriptor = 0x00050020,
    sharedTextureMemoryDxgiSharedHandleDescriptor = 0x00050021,
    sharedTextureMemoryD3d11Texture2dDescriptor = 0x00050022,
    sharedTextureMemoryIoSurfaceDescriptor = 0x00050023,
    sharedTextureMemoryEglImageDescriptor = 0x00050024,
    sharedTextureMemoryInitializedBeginState = 0x00050025,
    sharedTextureMemoryInitializedEndState = 0x00050026,
    sharedTextureMemoryVkImageLayoutBeginState = 0x00050027,
    sharedTextureMemoryVkImageLayoutEndState = 0x00050028,
    sharedTextureMemoryD3dSwapchainBeginState = 0x00050029,
    sharedFenceVkSemaphoreOpaqueFdDescriptor = 0x0005002A,
    sharedFenceVkSemaphoreOpaqueFdExportInfo = 0x0005002B,
    sharedFenceSyncFdDescriptor = 0x0005002C,
    sharedFenceSyncFdExportInfo = 0x0005002D,
    sharedFenceVkSemaphoreZirconHandleDescriptor = 0x0005002E,
    sharedFenceVkSemaphoreZirconHandleExportInfo = 0x0005002F,
    sharedFenceDxgiSharedHandleDescriptor = 0x00050030,
    sharedFenceDxgiSharedHandleExportInfo = 0x00050031,
    sharedFenceMtlSharedEventDescriptor = 0x00050032,
    sharedFenceMtlSharedEventExportInfo = 0x00050033,
    sharedBufferMemoryD3d12ResourceDescriptor = 0x00050034,
    staticSamplerBindingLayout = 0x00050035,
    yCbCrVkDescriptor = 0x00050036,
    sharedTextureMemoryAHardwareBufferProperties = 0x00050037,
    aHardwareBufferProperties = 0x00050038,
    dawnTexelCopyBufferRowAlignmentLimits = 0x0005003A,
    adapterPropertiesSubgroupMatrixConfigs = 0x0005003B,
    sharedFenceEglSyncDescriptor = 0x0005003C,
    sharedFenceEglSyncExportInfo = 0x0005003D,
    dawnInjectedInvalidSType = 0x0005003E,
    dawnCompilationMessageUtf16 = 0x0005003F,
    dawnFakeBufferOomForTesting = 0x00050040,
    surfaceDescriptorFromWindowsWinuiSwapChainPanel = 0x00050041,
    dawnDeviceAllocatorControl = 0x00050042,
    dawnHostMappedPointerLimits = 0x00050043,
    renderPassDescriptorResolveRect = 0x00050044,
    requestAdapterWebgpuBackendOptions = 0x00050045,
    dawnFakeDeviceInitializeErrorForTesting = 0x00050046,
    sharedTextureMemoryD3d11BeginState = 0x00050047,
    dawnConsumeAdapterDescriptor = 0x00050048,
    texelBufferBindingEntry = 0x00050049,
    texelBufferBindingLayout = 0x0005004A,
    sharedTextureMemoryMetalEndAccessState = 0x0005004B,
    adapterPropertiesWgpu = 0x0005004C,
    sharedBufferMemoryD3d12SharedMemoryFileMappingHandleDescriptor = 0x0005004D,
    sharedTextureMemoryD3d12ResourceDescriptor = 0x0005004E,
    requestAdapterOptionsAngleVirtualizationGroup = 0x0005004F,
    pipelineLayoutResourceTable = 0x00050050,
    adapterPropertiesExplicitComputeSubgroupSizeConfigs = 0x00050051,
    adapterPropertiesDrm = 0x00050052,
}

enum WGPUSurfaceGetCurrentTextureStatus : uint
{
    successOptimal = 0x00000001,
    successSuboptimal = 0x00000002,
    timeout = 0x00000003,
    outdated = 0x00000004,
    lost = 0x00000005,
    error = 0x00000006,
}

enum WGPUTextureAspect : uint
{
    undefined = 0x00000000,
    all = 0x00000001,
    stencilOnly = 0x00000002,
    depthOnly = 0x00000003,
    plane0Only = 0x00050000,
    plane1Only = 0x00050001,
    plane2Only = 0x00050002,
}

enum WGPUTextureDimension : uint
{
    undefined = 0x00000000,
    _1d = 0x00000001,
    _2d = 0x00000002,
    _3d = 0x00000003,
}

enum WGPUTextureFormat : uint
{
    undefined = 0x00000000,
    r8Unorm = 0x00000001,
    r8Snorm = 0x00000002,
    r8Uint = 0x00000003,
    r8Sint = 0x00000004,
    r16Unorm = 0x00000005,
    r16Snorm = 0x00000006,
    r16Uint = 0x00000007,
    r16Sint = 0x00000008,
    r16Float = 0x00000009,
    rg8Unorm = 0x0000000A,
    rg8Snorm = 0x0000000B,
    rg8Uint = 0x0000000C,
    rg8Sint = 0x0000000D,
    r32Float = 0x0000000E,
    r32Uint = 0x0000000F,
    r32Sint = 0x00000010,
    rg16Unorm = 0x00000011,
    rg16Snorm = 0x00000012,
    rg16Uint = 0x00000013,
    rg16Sint = 0x00000014,
    rg16Float = 0x00000015,
    rgba8Unorm = 0x00000016,
    rgba8UnormSrgb = 0x00000017,
    rgba8Snorm = 0x00000018,
    rgba8Uint = 0x00000019,
    rgba8Sint = 0x0000001A,
    bgra8Unorm = 0x0000001B,
    bgra8UnormSrgb = 0x0000001C,
    rgb10A2Uint = 0x0000001D,
    rgb10A2Unorm = 0x0000001E,
    rg11B10Ufloat = 0x0000001F,
    rgb9E5Ufloat = 0x00000020,
    rg32Float = 0x00000021,
    rg32Uint = 0x00000022,
    rg32Sint = 0x00000023,
    rgba16Unorm = 0x00000024,
    rgba16Snorm = 0x00000025,
    rgba16Uint = 0x00000026,
    rgba16Sint = 0x00000027,
    rgba16Float = 0x00000028,
    rgba32Float = 0x00000029,
    rgba32Uint = 0x0000002A,
    rgba32Sint = 0x0000002B,
    stencil8 = 0x0000002C,
    depth16Unorm = 0x0000002D,
    depth24Plus = 0x0000002E,
    depth24PlusStencil8 = 0x0000002F,
    depth32Float = 0x00000030,
    depth32FloatStencil8 = 0x00000031,
    bc1RgbaUnorm = 0x00000032,
    bc1RgbaUnormSrgb = 0x00000033,
    bc2RgbaUnorm = 0x00000034,
    bc2RgbaUnormSrgb = 0x00000035,
    bc3RgbaUnorm = 0x00000036,
    bc3RgbaUnormSrgb = 0x00000037,
    bc4RUnorm = 0x00000038,
    bc4RSnorm = 0x00000039,
    bc5RgUnorm = 0x0000003A,
    bc5RgSnorm = 0x0000003B,
    bc6hRgbUfloat = 0x0000003C,
    bc6hRgbFloat = 0x0000003D,
    bc7RgbaUnorm = 0x0000003E,
    bc7RgbaUnormSrgb = 0x0000003F,
    etc2Rgb8Unorm = 0x00000040,
    etc2Rgb8UnormSrgb = 0x00000041,
    etc2Rgb8a1Unorm = 0x00000042,
    etc2Rgb8a1UnormSrgb = 0x00000043,
    etc2Rgba8Unorm = 0x00000044,
    etc2Rgba8UnormSrgb = 0x00000045,
    eacR11Unorm = 0x00000046,
    eacR11Snorm = 0x00000047,
    eacRg11Unorm = 0x00000048,
    eacRg11Snorm = 0x00000049,
    astc4x4Unorm = 0x0000004A,
    astc4x4UnormSrgb = 0x0000004B,
    astc5x4Unorm = 0x0000004C,
    astc5x4UnormSrgb = 0x0000004D,
    astc5x5Unorm = 0x0000004E,
    astc5x5UnormSrgb = 0x0000004F,
    astc6x5Unorm = 0x00000050,
    astc6x5UnormSrgb = 0x00000051,
    astc6x6Unorm = 0x00000052,
    astc6x6UnormSrgb = 0x00000053,
    astc8x5Unorm = 0x00000054,
    astc8x5UnormSrgb = 0x00000055,
    astc8x6Unorm = 0x00000056,
    astc8x6UnormSrgb = 0x00000057,
    astc8x8Unorm = 0x00000058,
    astc8x8UnormSrgb = 0x00000059,
    astc10x5Unorm = 0x0000005A,
    astc10x5UnormSrgb = 0x0000005B,
    astc10x6Unorm = 0x0000005C,
    astc10x6UnormSrgb = 0x0000005D,
    astc10x8Unorm = 0x0000005E,
    astc10x8UnormSrgb = 0x0000005F,
    astc10x10Unorm = 0x00000060,
    astc10x10UnormSrgb = 0x00000061,
    astc12x10Unorm = 0x00000062,
    astc12x10UnormSrgb = 0x00000063,
    astc12x12Unorm = 0x00000064,
    astc12x12UnormSrgb = 0x00000065,
    r8Bg8Biplanar420Unorm = 0x00050000,
    r10x6Bg10x6Biplanar420Unorm = 0x00050001,
    r8Bg8A8Triplanar420Unorm = 0x00050002,
    r8Bg8Biplanar422Unorm = 0x00050003,
    r8Bg8Biplanar444Unorm = 0x00050004,
    r10x6Bg10x6Biplanar422Unorm = 0x00050005,
    r10x6Bg10x6Biplanar444Unorm = 0x00050006,
    opaqueYCbCrAndroid = 0x00050007,
}

enum WGPUTextureViewDimension : uint
{
    undefined = 0x00000000,
    _1d = 0x00000001,
    _2d = 0x00000002,
    _2dArray = 0x00000003,
    cube = 0x00000004,
    cubeArray = 0x00000005,
    _3d = 0x00000006,
}

enum WGPUComponentSwizzle : uint
{
    undefined = 0x00000000,
    zero = 0x00000001,
    one = 0x00000002,
    r = 0x00000003,
    g = 0x00000004,
    b = 0x00000005,
    a = 0x00000006,
}

enum WGPUVertexFormat : uint
{
    uint8 = 0x00000001,
    uint8x2 = 0x00000002,
    uint8x4 = 0x00000003,
    sint8 = 0x00000004,
    sint8x2 = 0x00000005,
    sint8x4 = 0x00000006,
    unorm8 = 0x00000007,
    unorm8x2 = 0x00000008,
    unorm8x4 = 0x00000009,
    snorm8 = 0x0000000A,
    snorm8x2 = 0x0000000B,
    snorm8x4 = 0x0000000C,
    uint16 = 0x0000000D,
    uint16x2 = 0x0000000E,
    uint16x4 = 0x0000000F,
    sint16 = 0x00000010,
    sint16x2 = 0x00000011,
    sint16x4 = 0x00000012,
    unorm16 = 0x00000013,
    unorm16x2 = 0x00000014,
    unorm16x4 = 0x00000015,
    snorm16 = 0x00000016,
    snorm16x2 = 0x00000017,
    snorm16x4 = 0x00000018,
    float16 = 0x00000019,
    float16x2 = 0x0000001A,
    float16x4 = 0x0000001B,
    float32 = 0x0000001C,
    float32x2 = 0x0000001D,
    float32x3 = 0x0000001E,
    float32x4 = 0x0000001F,
    uint32 = 0x00000020,
    uint32x2 = 0x00000021,
    uint32x3 = 0x00000022,
    uint32x4 = 0x00000023,
    sint32 = 0x00000024,
    sint32x2 = 0x00000025,
    sint32x3 = 0x00000026,
    sint32x4 = 0x00000027,
    unorm10_10_10_2 = 0x00000028,
    unorm8x4Bgra = 0x00000029,
}

enum WGPUWgslLanguageFeatureName : uint
{
    readonlyAndReadwriteStorageTextures = 0x00000001,
    packed4x8IntegerDotProduct = 0x00000002,
    unrestrictedPointerParameters = 0x00000003,
    pointerCompositeAccess = 0x00000004,
    uniformBufferStandardLayout = 0x00000005,
    subgroupId = 0x00000006,
    textureAndSamplerLet = 0x00000007,
    subgroupUniformity = 0x00000008,
    textureFormatsTier1 = 0x00000009,
    chromiumTestingUnimplemented = 0x00050000,
    chromiumTestingUnsafeExperimental = 0x00050001,
    chromiumTestingExperimental = 0x00050002,
    chromiumTestingShippedWithKillswitch = 0x00050003,
    chromiumTestingShipped = 0x00050004,
    sizedBindingArray = 0x00050005,
    texelBuffers = 0x00050006,
    chromiumPrint = 0x00050007,
    fragmentDepth = 0x00050008,
    immediateAddressSpace = 0x00050009,
    bufferView = 0x0005000B,
    filteringParameters = 0x0005000C,
    swizzleAssignment = 0x0005000D,
    linearIndexing = 0x0005000E,
}

enum WGPUSubgroupMatrixComponentType : uint
{
    f32 = 0x00000001,
    f16 = 0x00000002,
    u32 = 0x00000003,
    i32 = 0x00000004,
    u8 = 0x00000005,
    i8 = 0x00000006,
}


// Bitmasks

enum WGPUBufferUsage : ulong
{
    none = 0x0000000000000000,
    mapRead = 0x0000000000000001,
    mapWrite = 0x0000000000000002,
    copySrc = 0x0000000000000004,
    copyDst = 0x0000000000000008,
    index = 0x0000000000000010,
    vertex = 0x0000000000000020,
    uniform = 0x0000000000000040,
    storage = 0x0000000000000080,
    indirect = 0x0000000000000100,
    queryResolve = 0x0000000000000200,
    texelBuffer = 0x0000000000050400,
}

enum WGPUColorWriteMask : ulong
{
    none = 0x0000000000000000,
    red = 0x0000000000000001,
    green = 0x0000000000000002,
    blue = 0x0000000000000004,
    alpha = 0x0000000000000008,
    all = 0x000000000000000F,
}

enum WGPUMapMode : ulong
{
    none = 0x0000000000000000,
    read = 0x0000000000000001,
    write = 0x0000000000000002,
}

enum WGPUShaderStage : ulong
{
    none = 0x0000000000000000,
    vertex = 0x0000000000000001,
    fragment = 0x0000000000000002,
    compute = 0x0000000000000004,
}

enum WGPUTextureUsage : ulong
{
    none = 0x0000000000000000,
    copySrc = 0x0000000000000001,
    copyDst = 0x0000000000000002,
    textureBinding = 0x0000000000000004,
    storageBinding = 0x0000000000000008,
    renderAttachment = 0x0000000000000010,
    transientAttachment = 0x0000000000000020,
    storageAttachment = 0x0000000000050040,
}

enum WGPUHeapProperty : ulong
{
    none = 0x0000000000000000,
    deviceLocal = 0x0000000000000001,
    hostVisible = 0x0000000000000002,
    hostCoherent = 0x0000000000000004,
    hostUncached = 0x0000000000000008,
    hostCached = 0x0000000000000010,
}


// Function Pointer Types

alias WGPUProc = extern(C) void function();
alias WGPUDawnLoadCacheDataFunction = extern(C) size_t function(const(void)* key, size_t keySize, void* value, size_t valueSize, void* userdata);
alias WGPUDawnStoreCacheDataFunction = extern(C) void function(const(void)* key, size_t keySize, const(void)* value, size_t valueSize, void* userdata);
alias WGPUCallback = extern(C) void function(void* userdata);

// Callback Function Types

alias WGPURequestAdapterCallback = extern(C) void function(WGPURequestAdapterStatus status, WGPUAdapter adapter, WGPUStringView message, void* userdata1, void* userdata2);
alias WGPUBufferMapCallback = extern(C) void function(WGPUMapAsyncStatus status, WGPUStringView message, void* userdata1, void* userdata2);
alias WGPUCompilationInfoCallback = extern(C) void function(WGPUCompilationInfoRequestStatus status, const(WGPUCompilationInfo)* compilationInfo, void* userdata1, void* userdata2);
alias WGPUCreateComputePipelineAsyncCallback = extern(C) void function(WGPUCreatePipelineAsyncStatus status, WGPUComputePipeline pipeline, WGPUStringView message, void* userdata1, void* userdata2);
alias WGPUCreateRenderPipelineAsyncCallback = extern(C) void function(WGPUCreatePipelineAsyncStatus status, WGPURenderPipeline pipeline, WGPUStringView message, void* userdata1, void* userdata2);
alias WGPUDeviceLostCallback = extern(C) void function(const(WGPUDevice)* device, WGPUDeviceLostReason reason, WGPUStringView message, void* userdata1, void* userdata2);
alias WGPUUncapturedErrorCallback = extern(C) void function(const(WGPUDevice)* device, WGPUErrorType type, WGPUStringView message, void* userdata1, void* userdata2);
alias WGPUPopErrorScopeCallback = extern(C) void function(WGPUPopErrorScopeStatus status, WGPUErrorType type, WGPUStringView message, void* userdata1, void* userdata2);
alias WGPULoggingCallback = extern(C) void function(WGPULoggingType type, WGPUStringView message, void* userdata1, void* userdata2);
alias WGPUQueueWorkDoneCallback = extern(C) void function(WGPUQueueWorkDoneStatus status, WGPUStringView message, void* userdata1, void* userdata2);
alias WGPURequestDeviceCallback = extern(C) void function(WGPURequestDeviceStatus status, WGPUDevice device, WGPUStringView message, void* userdata1, void* userdata2);

// Structures

struct WGPURequestAdapterOptions
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUFeatureLevel featureLevel = WGPUFeatureLevel.undefined;
    WGPUPowerPreference powerPreference = WGPUPowerPreference.undefined;
    WGPUBool forceFallbackAdapter = false;
    WGPUBackendType backendType = WGPUBackendType.undefined;
    WGPUSurface compatibleSurface = null;
}

struct WGPURequestAdapterWebxrOptions
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.requestAdapterWebxrOptions);
    WGPUBool xrCompatible = false;
}

struct WGPURequestAdapterWebgpuBackendOptions
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.requestAdapterWebgpuBackendOptions);
}

struct WGPUAdapterInfo
{
    WGPUChainedStructOut* nextInChain = null;
    WGPUStringView vendor;
    WGPUStringView architecture;
    WGPUStringView device;
    WGPUStringView description;
    WGPUBackendType backendType = WGPUBackendType.undefined;
    WGPUAdapterType adapterType = cast(WGPUAdapterType)0;
    uint32_t vendorId = 0;
    uint32_t deviceId = 0;
    uint32_t subgroupMinSize = 0;
    uint32_t subgroupMaxSize = 0;
}

struct WGPUDeviceDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    size_t requiredFeatureCount = 0;
    const(WGPUFeatureName)* requiredFeatures = null;
    const(WGPULimits)* requiredLimits = null;
    WGPUQueueDescriptor defaultQueue;
    WGPUDeviceLostCallbackInfo deviceLostCallbackInfo;
    WGPUUncapturedErrorCallbackInfo uncapturedErrorCallbackInfo;
}

struct WGPUDawnConsumeAdapterDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnConsumeAdapterDescriptor);
    WGPUBool consumeAdapter = false;
}

struct WGPUDawnTogglesDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnTogglesDescriptor);
    size_t enabledToggleCount = 0;
    const(char*)* enabledToggles = null;
    size_t disabledToggleCount = 0;
    const(char*)* disabledToggles = null;
}

struct WGPUDawnCacheDeviceDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnCacheDeviceDescriptor);
    WGPUStringView isolationKey;
    WGPUDawnLoadCacheDataFunction loadDataFunction = null;
    WGPUDawnStoreCacheDataFunction storeDataFunction = null;
    void* functionUserdata = null;
}

struct WGPUDawnDeviceAllocatorControl
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnDeviceAllocatorControl);
    size_t allocatorHeapBlockSize = 0;
}

struct WGPUDawnWgslBlocklist
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnWgslBlocklist);
    size_t blocklistedFeatureCount = 0;
    const(char*)* blocklistedFeatures = null;
}

struct WGPUBindGroupEntry
{
    const(WGPUChainedStruct)* nextInChain = null;
    uint32_t binding = 0;
    WGPUBuffer buffer = null;
    uint64_t offset = 0;
    uint64_t size = WGPUWholeSize;
    WGPUSampler sampler = null;
    WGPUTextureView textureView = null;
}

struct WGPUBindGroupDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    WGPUBindGroupLayout layout = null;
    size_t entryCount = 0;
    const(WGPUBindGroupEntry)* entries = null;
}

struct WGPUBufferBindingLayout
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUBufferBindingType type = WGPUBufferBindingType.undefined;
    WGPUBool hasDynamicOffset = false;
    uint64_t minBindingSize = 0;
}

struct WGPUSamplerBindingLayout
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUSamplerBindingType type = WGPUSamplerBindingType.undefined;
}

struct WGPUStaticSamplerBindingLayout
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.staticSamplerBindingLayout);
    WGPUSampler sampler = null;
    uint32_t sampledTextureBinding = WGPULimitU32Undefined;
}

struct WGPUTextureBindingLayout
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUTextureSampleType sampleType = WGPUTextureSampleType.undefined;
    WGPUTextureViewDimension viewDimension = WGPUTextureViewDimension.undefined;
    WGPUBool multisampled = false;
}

struct WGPUSurfaceCapabilities
{
    WGPUChainedStructOut* nextInChain = null;
    WGPUTextureUsage usages = WGPUTextureUsage.none;
    size_t formatCount = 0;
    const(WGPUTextureFormat)* formats = null;
    size_t presentModeCount = 0;
    const(WGPUPresentMode)* presentModes = null;
    size_t alphaModeCount = 0;
    const(WGPUCompositeAlphaMode)* alphaModes = null;
}

struct WGPUSurfaceConfiguration
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUDevice device = null;
    WGPUTextureFormat format = WGPUTextureFormat.undefined;
    WGPUTextureUsage usage = WGPUTextureUsage.renderAttachment;
    uint32_t width = 0;
    uint32_t height = 0;
    size_t viewFormatCount = 0;
    const(WGPUTextureFormat)* viewFormats = null;
    WGPUCompositeAlphaMode alphaMode = WGPUCompositeAlphaMode.auto_;
    WGPUPresentMode presentMode = WGPUPresentMode.undefined;
}

struct WGPUExternalTextureBindingEntry
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.externalTextureBindingEntry);
    WGPUExternalTexture externalTexture = null;
}

struct WGPUTexelBufferBindingEntry
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.texelBufferBindingEntry);
    WGPUTexelBufferView texelBufferView = null;
}

struct WGPUExternalTextureBindingLayout
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.externalTextureBindingLayout);
}

struct WGPUStorageTextureBindingLayout
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStorageTextureAccess access = WGPUStorageTextureAccess.undefined;
    WGPUTextureFormat format = WGPUTextureFormat.undefined;
    WGPUTextureViewDimension viewDimension = WGPUTextureViewDimension.undefined;
}

struct WGPUTexelBufferBindingLayout
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.texelBufferBindingLayout);
    WGPUTexelBufferAccess access = WGPUTexelBufferAccess.undefined;
    WGPUTextureFormat format = WGPUTextureFormat.undefined;
}

struct WGPUBindGroupLayoutEntry
{
    const(WGPUChainedStruct)* nextInChain = null;
    uint32_t binding = 0;
    WGPUShaderStage visibility = WGPUShaderStage.none;
    uint32_t bindingArraySize = 0;
    WGPUBufferBindingLayout buffer = { type: WGPUBufferBindingType.bindingNotUsed };
    WGPUSamplerBindingLayout sampler = { type: WGPUSamplerBindingType.bindingNotUsed };
    WGPUTextureBindingLayout texture = { sampleType: WGPUTextureSampleType.bindingNotUsed, viewDimension: WGPUTextureViewDimension.undefined };
    WGPUStorageTextureBindingLayout storageTexture = { access: WGPUStorageTextureAccess.bindingNotUsed, format: WGPUTextureFormat.undefined, viewDimension: WGPUTextureViewDimension.undefined };
}

struct WGPUBindGroupLayoutDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    size_t entryCount = 0;
    const(WGPUBindGroupLayoutEntry)* entries = null;
}

struct WGPUBlendComponent
{
    WGPUBlendOperation operation = WGPUBlendOperation.undefined;
    WGPUBlendFactor srcFactor = WGPUBlendFactor.undefined;
    WGPUBlendFactor dstFactor = WGPUBlendFactor.undefined;
}

struct WGPUStringView
{
    const(char)* data = null;
    size_t length = WGPUStrlen;

    /// Construct from D string (no allocation, just a view)
    this(const(char)[] s) @nogc nothrow pure
    {
        data = s.ptr;
        length = s.length;
    }

    /// Get as a D slice (no allocation, borrows memory)
    const(char)[] slice() const @nogc nothrow pure
    {
        if (data is null) return null;
        return data[0 .. length];
    }

    /// Convert to owned D string (allocates via GC)
    string toGCString() const
    {
        if (data is null || length == 0) return "";
        return cast(string) data[0 .. length].idup;
    }

    /// Alias for slice() to work with writeln etc
    alias toString = slice;
}

struct WGPUBufferDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    WGPUBufferUsage usage = WGPUBufferUsage.none;
    uint64_t size = 0;
    WGPUBool mappedAtCreation = false;
}

struct WGPUBufferHostMappedPointer
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.bufferHostMappedPointer);
    void* pointer = null;
    WGPUCallback disposeCallback = null;
    void* userdata = null;
}

struct WGPUColor
{
    double r = 0.0;
    double g = 0.0;
    double b = 0.0;
    double a = 0.0;
}

struct WGPUConstantEntry
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView key;
    double value = 0.0;
}

struct WGPUCommandBufferDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
}

struct WGPUCommandEncoderDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
}

struct WGPUCompilationInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    size_t messageCount = 0;
    const(WGPUCompilationMessage)* messages = null;
}

struct WGPUCompilationMessage
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView message;
    WGPUCompilationMessageType type = cast(WGPUCompilationMessageType)0;
    uint64_t lineNum = 0;
    uint64_t linePos = 0;
    uint64_t offset = 0;
    uint64_t length = 0;
}

struct WGPUDawnCompilationMessageUtf16
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnCompilationMessageUtf16);
    uint64_t linePos = 0;
    uint64_t offset = 0;
    uint64_t length = 0;
}

struct WGPUComputePassDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    const(WGPUPassTimestampWrites)* timestampWrites = null;
}

struct WGPUComputePipelineDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    WGPUPipelineLayout layout = null;
    WGPUComputeState compute;
}

struct WGPUCopyTextureForBrowserOptions
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUBool flipY = false;
    WGPUBool needsColorSpaceConversion = false;
    WGPUAlphaMode srcAlphaMode = WGPUAlphaMode.unpremultiplied;
    const(float)* srcTransferFunctionParameters = null;
    const(float)* conversionMatrix = null;
    const(float)* dstTransferFunctionParameters = null;
    WGPUAlphaMode dstAlphaMode = WGPUAlphaMode.unpremultiplied;
    WGPUBool internalUsage = false;
}

struct WGPUAHardwareBufferProperties
{
    WGPUYCbCrVkDescriptor yCbCrInfo;
}

struct WGPULimits
{
    WGPUChainedStructOut* nextInChain = null;
    uint32_t maxTextureDimension1d = WGPULimitU32Undefined;
    uint32_t maxTextureDimension2d = WGPULimitU32Undefined;
    uint32_t maxTextureDimension3d = WGPULimitU32Undefined;
    uint32_t maxTextureArrayLayers = WGPULimitU32Undefined;
    uint32_t maxBindGroups = WGPULimitU32Undefined;
    uint32_t maxBindGroupsPlusVertexBuffers = WGPULimitU32Undefined;
    uint32_t maxBindingsPerBindGroup = WGPULimitU32Undefined;
    uint32_t maxDynamicUniformBuffersPerPipelineLayout = WGPULimitU32Undefined;
    uint32_t maxDynamicStorageBuffersPerPipelineLayout = WGPULimitU32Undefined;
    uint32_t maxSampledTexturesPerShaderStage = WGPULimitU32Undefined;
    uint32_t maxSamplersPerShaderStage = WGPULimitU32Undefined;
    uint32_t maxStorageBuffersPerShaderStage = WGPULimitU32Undefined;
    uint32_t maxStorageTexturesPerShaderStage = WGPULimitU32Undefined;
    uint32_t maxUniformBuffersPerShaderStage = WGPULimitU32Undefined;
    uint64_t maxUniformBufferBindingSize = WGPULimitU64Undefined;
    uint64_t maxStorageBufferBindingSize = WGPULimitU64Undefined;
    uint32_t minUniformBufferOffsetAlignment = WGPULimitU32Undefined;
    uint32_t minStorageBufferOffsetAlignment = WGPULimitU32Undefined;
    uint32_t maxVertexBuffers = WGPULimitU32Undefined;
    uint64_t maxBufferSize = WGPULimitU64Undefined;
    uint32_t maxVertexAttributes = WGPULimitU32Undefined;
    uint32_t maxVertexBufferArrayStride = WGPULimitU32Undefined;
    uint32_t maxInterStageShaderVariables = WGPULimitU32Undefined;
    uint32_t maxColorAttachments = WGPULimitU32Undefined;
    uint32_t maxColorAttachmentBytesPerSample = WGPULimitU32Undefined;
    uint32_t maxComputeWorkgroupStorageSize = WGPULimitU32Undefined;
    uint32_t maxComputeInvocationsPerWorkgroup = WGPULimitU32Undefined;
    uint32_t maxComputeWorkgroupSizeX = WGPULimitU32Undefined;
    uint32_t maxComputeWorkgroupSizeY = WGPULimitU32Undefined;
    uint32_t maxComputeWorkgroupSizeZ = WGPULimitU32Undefined;
    uint32_t maxComputeWorkgroupsPerDimension = WGPULimitU32Undefined;
    uint32_t maxImmediateSize = WGPULimitU32Undefined;
}

struct WGPUCompatibilityModeLimits
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.compatibilityModeLimits);
    uint32_t maxStorageBuffersInVertexStage = WGPULimitU32Undefined;
    uint32_t maxStorageTexturesInVertexStage = WGPULimitU32Undefined;
    uint32_t maxStorageBuffersInFragmentStage = WGPULimitU32Undefined;
    uint32_t maxStorageTexturesInFragmentStage = WGPULimitU32Undefined;
}

struct WGPUDawnTexelCopyBufferRowAlignmentLimits
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.dawnTexelCopyBufferRowAlignmentLimits);
    uint32_t minTexelCopyBufferRowAlignment = WGPULimitU32Undefined;
}

struct WGPUDawnHostMappedPointerLimits
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.dawnHostMappedPointerLimits);
    uint32_t hostMappedPointerAlignment = WGPULimitU32Undefined;
}

struct WGPUSupportedFeatures
{
    size_t featureCount = 0;
    const(WGPUFeatureName)* features = null;
}

struct WGPUSupportedInstanceFeatures
{
    size_t featureCount = 0;
    const(WGPUInstanceFeatureName)* features = null;
}

struct WGPUSupportedWgslLanguageFeatures
{
    size_t featureCount = 0;
    const(WGPUWgslLanguageFeatureName)* features = null;
}

struct WGPUExtent2d
{
    uint32_t width = 0;
    uint32_t height = 0;
}

struct WGPUExtent3d
{
    uint32_t width = 0;
    uint32_t height = 1;
    uint32_t depthOrArrayLayers = 1;
}

struct WGPUExternalTextureDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    WGPUTextureView plane0 = null;
    WGPUTextureView plane1 = null;
    WGPUOrigin2d cropOrigin;
    WGPUExtent2d cropSize;
    WGPUExtent2d apparentSize;
    WGPUBool doYuvToRgbConversionOnly = false;
    const(float)* yuvToRgbConversionMatrix = null;
    const(float)* srcTransferFunctionParameters = null;
    const(float)* dstTransferFunctionParameters = null;
    const(float)* gamutConversionMatrix = null;
    WGPUBool mirrored = false;
    WGPUExternalTextureRotation rotation = WGPUExternalTextureRotation.rotate0Degrees;
}

struct WGPUColorSpaceDawn
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUColorSpacePrimariesDawn primaries = cast(WGPUColorSpacePrimariesDawn)0;
    WGPUColorSpaceTransferDawn transfer = cast(WGPUColorSpaceTransferDawn)0;
    WGPUColorSpaceYCbCrRangeDawn yCbCrRange = cast(WGPUColorSpaceYCbCrRangeDawn)0;
    WGPUColorSpaceYCbCrMatrixDawn yCbCrMatrix = cast(WGPUColorSpaceYCbCrMatrixDawn)0;
}

struct WGPUSharedBufferMemoryProperties
{
    WGPUChainedStructOut* nextInChain = null;
    WGPUBufferUsage usage = WGPUBufferUsage.none;
    uint64_t size = 0;
}

struct WGPUSharedBufferMemoryDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
}

struct WGPUSharedBufferMemoryD3d12SharedMemoryFileMappingHandleDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedBufferMemoryD3d12SharedMemoryFileMappingHandleDescriptor);
    void* handle = null;
    uint64_t size = 0;
}

struct WGPUSharedTextureMemoryProperties
{
    WGPUChainedStructOut* nextInChain = null;
    WGPUTextureUsage usage = WGPUTextureUsage.none;
    WGPUExtent3d size;
    WGPUTextureFormat format = WGPUTextureFormat.undefined;
}

struct WGPUSharedTextureMemoryAHardwareBufferProperties
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.sharedTextureMemoryAHardwareBufferProperties);
    WGPUYCbCrVkDescriptor yCbCrInfo;
}

struct WGPUSharedTextureMemoryDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
}

struct WGPUSharedBufferMemoryBeginAccessDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUBool initialized = false;
    size_t fenceCount = 0;
    const(WGPUSharedFence)* fences = null;
    const(uint64_t)* signaledValues = null;
}

struct WGPUSharedBufferMemoryEndAccessState
{
    WGPUChainedStructOut* nextInChain = null;
    WGPUBool initialized = false;
    size_t fenceCount = 0;
    const(WGPUSharedFence)* fences = null;
    const(uint64_t)* signaledValues = null;
}

struct WGPUSharedTextureMemoryVkDedicatedAllocationDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryVkDedicatedAllocationDescriptor);
    WGPUBool dedicatedAllocation = false;
}

struct WGPUSharedTextureMemoryAHardwareBufferDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryAHardwareBufferDescriptor);
    void* handle = null;
}

struct WGPUSharedTextureMemoryDmaBufPlane
{
    int fd = 0;
    uint64_t offset = 0;
    uint32_t stride = 0;
}

struct WGPUSharedTextureMemoryDmaBufDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryDmaBufDescriptor);
    WGPUExtent3d size;
    uint32_t drmFormat = 0;
    uint64_t drmModifier = 0;
    size_t planeCount = 0;
    const(WGPUSharedTextureMemoryDmaBufPlane)* planes = null;
}

struct WGPUSharedTextureMemoryOpaqueFdDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryOpaqueFdDescriptor);
    const(void)* vkImageCreateInfo = null;
    int memoryFd = 0;
    uint32_t memoryTypeIndex = 0;
    uint64_t allocationSize = 0;
    WGPUBool dedicatedAllocation = false;
}

struct WGPUSharedTextureMemoryZirconHandleDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryZirconHandleDescriptor);
    uint32_t memoryFd = 0;
    uint64_t allocationSize = 0;
}

struct WGPUSharedTextureMemoryDxgiSharedHandleDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryDxgiSharedHandleDescriptor);
    void* handle = null;
    WGPUBool useKeyedMutex = false;
}

struct WGPUSharedTextureMemoryIoSurfaceDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryIoSurfaceDescriptor);
    void* ioSurface = null;
    WGPUBool allowStorageBinding = true;
}

struct WGPUSharedTextureMemoryEglImageDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryEglImageDescriptor);
    void* image = null;
}

struct WGPUSharedTextureMemoryBeginAccessDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUBool concurrentRead = false;
    WGPUBool initialized = false;
    size_t fenceCount = 0;
    const(WGPUSharedFence)* fences = null;
    const(uint64_t)* signaledValues = null;
}

struct WGPUSharedTextureMemoryEndAccessState
{
    WGPUChainedStructOut* nextInChain = null;
    WGPUBool initialized = false;
    size_t fenceCount = 0;
    const(WGPUSharedFence)* fences = null;
    const(uint64_t)* signaledValues = null;
}

struct WGPUSharedTextureMemoryMetalEndAccessState
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.sharedTextureMemoryMetalEndAccessState);
    WGPUFuture commandsScheduledFuture;
}

struct WGPUSharedTextureMemoryVkImageLayoutBeginState
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryVkImageLayoutBeginState);
    int32_t oldLayout = 0;
    int32_t newLayout = 0;
}

struct WGPUSharedTextureMemoryVkImageLayoutEndState
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.sharedTextureMemoryVkImageLayoutEndState);
    int32_t oldLayout = 0;
    int32_t newLayout = 0;
}

struct WGPUSharedTextureMemoryD3dSwapchainBeginState
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryD3dSwapchainBeginState);
    WGPUBool isSwapchain = false;
}

struct WGPUSharedTextureMemoryD3d11BeginState
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedTextureMemoryD3d11BeginState);
    WGPUBool requiresEndAccessFence = true;
}

struct WGPUSharedFenceDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
}

struct WGPUSharedFenceVkSemaphoreOpaqueFdDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedFenceVkSemaphoreOpaqueFdDescriptor);
    int handle = 0;
}

struct WGPUSharedFenceSyncFdDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedFenceSyncFdDescriptor);
    int handle = 0;
}

struct WGPUSharedFenceVkSemaphoreZirconHandleDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedFenceVkSemaphoreZirconHandleDescriptor);
    uint32_t handle = 0;
}

struct WGPUSharedFenceDxgiSharedHandleDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedFenceDxgiSharedHandleDescriptor);
    void* handle = null;
}

struct WGPUSharedFenceMtlSharedEventDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedFenceMtlSharedEventDescriptor);
    void* sharedEvent = null;
}

struct WGPUSharedFenceEglSyncDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.sharedFenceEglSyncDescriptor);
    void* sync = null;
}

struct WGPUDawnFakeBufferOomForTesting
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnFakeBufferOomForTesting);
    WGPUBool fakeOomAtWireClientMap = false;
    WGPUBool fakeOomAtNativeMap = false;
    WGPUBool fakeOomAtDevice = false;
}

struct WGPUDawnFakeDeviceInitializeErrorForTesting
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnFakeDeviceInitializeErrorForTesting);
}

struct WGPUSharedFenceExportInfo
{
    WGPUChainedStructOut* nextInChain = null;
    WGPUSharedFenceType type = cast(WGPUSharedFenceType)0;
}

struct WGPUSharedFenceVkSemaphoreOpaqueFdExportInfo
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.sharedFenceVkSemaphoreOpaqueFdExportInfo);
    int handle = 0;
}

struct WGPUSharedFenceSyncFdExportInfo
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.sharedFenceSyncFdExportInfo);
    int handle = 0;
}

struct WGPUSharedFenceVkSemaphoreZirconHandleExportInfo
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.sharedFenceVkSemaphoreZirconHandleExportInfo);
    uint32_t handle = 0;
}

struct WGPUSharedFenceDxgiSharedHandleExportInfo
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.sharedFenceDxgiSharedHandleExportInfo);
    void* handle = null;
}

struct WGPUSharedFenceMtlSharedEventExportInfo
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.sharedFenceMtlSharedEventExportInfo);
    void* sharedEvent = null;
}

struct WGPUSharedFenceEglSyncExportInfo
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.sharedFenceEglSyncExportInfo);
    void* sync = null;
}

struct WGPUDawnFormatCapabilities
{
    WGPUChainedStructOut* nextInChain = null;
}

struct WGPUDawnDrmFormatCapabilities
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.dawnDrmFormatCapabilities);
    size_t propertiesCount = 0;
    const(WGPUDawnDrmFormatProperties)* properties = null;
}

struct WGPUDawnDrmFormatProperties
{
    uint64_t modifier = 0;
    uint32_t modifierPlaneCount = 0;
}

struct WGPUTexelCopyBufferInfo
{
    WGPUTexelCopyBufferLayout layout;
    WGPUBuffer buffer = null;
}

struct WGPUTexelCopyBufferLayout
{
    uint64_t offset = 0;
    uint32_t bytesPerRow = WGPUCopyStrideUndefined;
    uint32_t rowsPerImage = WGPUCopyStrideUndefined;
}

struct WGPUTexelCopyTextureInfo
{
    WGPUTexture texture = null;
    uint32_t mipLevel = 0;
    WGPUOrigin3d origin;
    WGPUTextureAspect aspect = WGPUTextureAspect.undefined;
}

struct WGPUImageCopyExternalTexture
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUExternalTexture externalTexture = null;
    WGPUOrigin3d origin;
    WGPUExtent2d naturalSize;
}

struct WGPUFuture
{
    uint64_t id = 0;
}

struct WGPUFutureWaitInfo
{
    WGPUFuture future;
    WGPUBool completed = false;
}

struct WGPUInstanceLimits
{
    WGPUChainedStructOut* nextInChain = null;
    size_t timedWaitAnyMaxCount = 0;
}

struct WGPUInstanceDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    size_t requiredFeatureCount = 0;
    const(WGPUInstanceFeatureName)* requiredFeatures = null;
    const(WGPUInstanceLimits)* requiredLimits = null;
}

struct WGPUDawnWireWgslControl
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnWireWgslControl);
    WGPUBool enableExperimental = false;
    WGPUBool enableUnsafe = false;
    WGPUBool enableTesting = false;
}

struct WGPUDawnInjectedInvalidSType
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnInjectedInvalidSType);
    WGPUSType invalidSType = cast(WGPUSType)0;
}

struct WGPUVertexAttribute
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUVertexFormat format = cast(WGPUVertexFormat)0;
    uint64_t offset = 0;
    uint32_t shaderLocation = 0;
}

struct WGPUVertexBufferLayout
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUVertexStepMode stepMode = WGPUVertexStepMode.undefined;
    uint64_t arrayStride = 0;
    size_t attributeCount = 0;
    const(WGPUVertexAttribute)* attributes = null;
}

struct WGPUOrigin3d
{
    uint32_t x = 0;
    uint32_t y = 0;
    uint32_t z = 0;
}

struct WGPUOrigin2d
{
    uint32_t x = 0;
    uint32_t y = 0;
}

struct WGPUPassTimestampWrites
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUQuerySet querySet = null;
    uint32_t beginningOfPassWriteIndex = WGPUQuerySetIndexUndefined;
    uint32_t endOfPassWriteIndex = WGPUQuerySetIndexUndefined;
}

struct WGPUPipelineLayoutResourceTable
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.pipelineLayoutResourceTable);
    WGPUBool usesResourceTable = false;
}

struct WGPUPipelineLayoutDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    size_t bindGroupLayoutCount = 0;
    const(WGPUBindGroupLayout)* bindGroupLayouts = null;
    uint32_t immediateSize = 0;
}

struct WGPUPipelineLayoutPixelLocalStorage
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.pipelineLayoutPixelLocalStorage);
    uint64_t totalPixelLocalStorageSize = 0;
    size_t storageAttachmentCount = 0;
    const(WGPUPipelineLayoutStorageAttachment)* storageAttachments = null;
}

struct WGPUPipelineLayoutStorageAttachment
{
    const(WGPUChainedStruct)* nextInChain = null;
    uint64_t offset = 0;
    WGPUTextureFormat format = WGPUTextureFormat.undefined;
}

struct WGPUComputeState
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUShaderModule module_ = null;
    WGPUStringView entryPoint;
    size_t constantCount = 0;
    const(WGPUConstantEntry)* constants = null;
}

struct WGPUQuerySetDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    WGPUQueryType type = cast(WGPUQueryType)0;
    uint32_t count = 0;
}

struct WGPUQueueDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
}

struct WGPURenderBundleDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
}

struct WGPURenderBundleEncoderDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    size_t colorFormatCount = 0;
    const(WGPUTextureFormat)* colorFormats = null;
    WGPUTextureFormat depthStencilFormat = WGPUTextureFormat.undefined;
    uint32_t sampleCount = 1;
    WGPUBool depthReadOnly = false;
    WGPUBool stencilReadOnly = false;
}

struct WGPURenderPassColorAttachment
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUTextureView view = null;
    uint32_t depthSlice = WGPUDepthSliceUndefined;
    WGPUTextureView resolveTarget = null;
    WGPULoadOp loadOp = WGPULoadOp.undefined;
    WGPUStoreOp storeOp = WGPUStoreOp.undefined;
    WGPUColor clearValue;
}

struct WGPURenderPassDepthStencilAttachment
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUTextureView view = null;
    WGPULoadOp depthLoadOp = WGPULoadOp.undefined;
    WGPUStoreOp depthStoreOp = WGPUStoreOp.undefined;
    float depthClearValue = WGPUDepthClearValueUndefined;
    WGPUBool depthReadOnly = false;
    WGPULoadOp stencilLoadOp = WGPULoadOp.undefined;
    WGPUStoreOp stencilStoreOp = WGPUStoreOp.undefined;
    uint32_t stencilClearValue = 0;
    WGPUBool stencilReadOnly = false;
}

struct WGPURenderPassDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    size_t colorAttachmentCount = 0;
    const(WGPURenderPassColorAttachment)* colorAttachments = null;
    const(WGPURenderPassDepthStencilAttachment)* depthStencilAttachment = null;
    WGPUQuerySet occlusionQuerySet = null;
    const(WGPUPassTimestampWrites)* timestampWrites = null;
}

struct WGPUDawnRenderPassSampleCount
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnRenderPassSampleCount);
    uint32_t sampleCount = 1;
}

struct WGPURenderPassMaxDrawCount
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.renderPassMaxDrawCount);
    uint64_t maxDrawCount = 50000000;
}

struct WGPURenderPassRenderAreaRect
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.renderPassRenderAreaRect);
    WGPUOrigin2d origin;
    WGPUExtent2d size;
}

struct WGPURenderPassDescriptorResolveRect
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.renderPassDescriptorResolveRect);
    uint32_t coloroffsetx = 0;
    uint32_t coloroffsety = 0;
    uint32_t resolveoffsetx = 0;
    uint32_t resolveoffsety = 0;
    uint32_t width = 0;
    uint32_t height = 0;
}

struct WGPURenderPassPixelLocalStorage
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.renderPassPixelLocalStorage);
    uint64_t totalPixelLocalStorageSize = 0;
    size_t storageAttachmentCount = 0;
    const(WGPURenderPassStorageAttachment)* storageAttachments = null;
}

struct WGPURenderPassStorageAttachment
{
    const(WGPUChainedStruct)* nextInChain = null;
    uint64_t offset = 0;
    WGPUTextureView storage = null;
    WGPULoadOp loadOp = WGPULoadOp.undefined;
    WGPUStoreOp storeOp = WGPUStoreOp.undefined;
    WGPUColor clearValue;
}

struct WGPUVertexState
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUShaderModule module_ = null;
    WGPUStringView entryPoint;
    size_t constantCount = 0;
    const(WGPUConstantEntry)* constants = null;
    size_t bufferCount = 0;
    const(WGPUVertexBufferLayout)* buffers = null;
}

struct WGPUPrimitiveState
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUPrimitiveTopology topology = WGPUPrimitiveTopology.undefined;
    WGPUIndexFormat stripIndexFormat = WGPUIndexFormat.undefined;
    WGPUFrontFace frontFace = WGPUFrontFace.undefined;
    WGPUCullMode cullMode = WGPUCullMode.undefined;
    WGPUBool unclippedDepth = false;
}

struct WGPUDepthStencilState
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUTextureFormat format = WGPUTextureFormat.undefined;
    WGPUOptionalBool depthWriteEnabled = WGPUOptionalBool.undefined;
    WGPUCompareFunction depthCompare = WGPUCompareFunction.undefined;
    WGPUStencilFaceState stencilFront;
    WGPUStencilFaceState stencilBack;
    uint32_t stencilReadMask = 0xFFFFFFF;
    uint32_t stencilWriteMask = 0xFFFFFFF;
    int32_t depthBias = 0;
    float depthBiasSlopeScale = 0.;
    float depthBiasClamp = 0.;
}

struct WGPUMultisampleState
{
    const(WGPUChainedStruct)* nextInChain = null;
    uint32_t count = 1;
    uint32_t mask = 0xFFFFFFF;
    WGPUBool alphaToCoverageEnabled = false;
}

struct WGPUFragmentState
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUShaderModule module_ = null;
    WGPUStringView entryPoint;
    size_t constantCount = 0;
    const(WGPUConstantEntry)* constants = null;
    size_t targetCount = 0;
    const(WGPUColorTargetState)* targets = null;
}

struct WGPUColorTargetState
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUTextureFormat format = WGPUTextureFormat.undefined;
    const(WGPUBlendState)* blend = null;
    WGPUColorWriteMask writeMask = WGPUColorWriteMask.all;
}

struct WGPUColorTargetStateExpandResolveTextureDawn
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.colorTargetStateExpandResolveTextureDawn);
    WGPUBool enabled = false;
}

struct WGPUBlendState
{
    WGPUBlendComponent color;
    WGPUBlendComponent alpha;
}

struct WGPURenderPipelineDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    WGPUPipelineLayout layout = null;
    WGPUVertexState vertex;
    WGPUPrimitiveState primitive;
    const(WGPUDepthStencilState)* depthStencil = null;
    WGPUMultisampleState multisample;
    const(WGPUFragmentState)* fragment = null;
}

struct WGPUResourceTableDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    uint32_t size = 0;
}

struct WGPUBindingResource
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUBuffer buffer = null;
    uint64_t offset = 0;
    uint64_t size = WGPUWholeSize;
    WGPUSampler sampler = null;
    WGPUTextureView textureView = null;
}

struct WGPUSamplerDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    WGPUAddressMode addressModeU = WGPUAddressMode.undefined;
    WGPUAddressMode addressModeV = WGPUAddressMode.undefined;
    WGPUAddressMode addressModeW = WGPUAddressMode.undefined;
    WGPUFilterMode magFilter = WGPUFilterMode.undefined;
    WGPUFilterMode minFilter = WGPUFilterMode.undefined;
    WGPUMipmapFilterMode mipmapFilter = WGPUMipmapFilterMode.undefined;
    float lodMinClamp = 0.;
    float lodMaxClamp = 32.;
    WGPUCompareFunction compare = WGPUCompareFunction.undefined;
    uint16_t maxAnisotropy = 1;
}

struct WGPUShaderModuleDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
}

struct WGPUShaderSourceSpirv
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.shaderSourceSpirv);
    uint32_t codeSize = 0;
    const(uint32_t)* code = null;
}

struct WGPUShaderSourceWgsl
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.shaderSourceWgsl);
    WGPUStringView code;
}

struct WGPUDawnShaderModuleSpirvOptionsDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnShaderModuleSpirvOptionsDescriptor);
    WGPUBool allowNonUniformDerivatives = false;
}

struct WGPUShaderModuleCompilationOptions
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.shaderModuleCompilationOptions);
    WGPUBool strictMath = false;
}

struct WGPUStencilFaceState
{
    WGPUCompareFunction compare = WGPUCompareFunction.undefined;
    WGPUStencilOperation failOp = WGPUStencilOperation.undefined;
    WGPUStencilOperation depthFailOp = WGPUStencilOperation.undefined;
    WGPUStencilOperation passOp = WGPUStencilOperation.undefined;
}

struct WGPUSurfaceDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
}

struct WGPUSurfaceSourceAndroidNativeWindow
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.surfaceSourceAndroidNativeWindow);
    void* window = null;
}

struct WGPUSurfaceSourceMetalLayer
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.surfaceSourceMetalLayer);
    void* layer = null;
}

struct WGPUSurfaceSourceWindowsHwnd
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.surfaceSourceWindowsHwnd);
    void* hinstance = null;
    void* hwnd = null;
}

struct WGPUSurfaceSourceXcbWindow
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.surfaceSourceXcbWindow);
    void* connection = null;
    uint32_t window = 0;
}

struct WGPUSurfaceSourceXlibWindow
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.surfaceSourceXlibWindow);
    void* display = null;
    uint64_t window = 0;
}

struct WGPUSurfaceSourceWaylandSurface
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.surfaceSourceWaylandSurface);
    void* display = null;
    void* surface = null;
}

struct WGPUSurfaceDescriptorFromWindowsCoreWindow
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.surfaceDescriptorFromWindowsCoreWindow);
    void* coreWindow = null;
}

struct WGPUSurfaceDescriptorFromWindowsUwpSwapChainPanel
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.surfaceDescriptorFromWindowsUwpSwapChainPanel);
    void* swapChainPanel = null;
}

struct WGPUSurfaceDescriptorFromWindowsWinuiSwapChainPanel
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.surfaceDescriptorFromWindowsWinuiSwapChainPanel);
    void* swapChainPanel = null;
}

struct WGPUSurfaceColorManagement
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.surfaceColorManagement);
    WGPUPredefinedColorSpace colorSpace = cast(WGPUPredefinedColorSpace)0;
    WGPUToneMappingMode toneMappingMode = cast(WGPUToneMappingMode)0;
}

struct WGPUSurfaceTexture
{
    WGPUChainedStructOut* nextInChain = null;
    WGPUTexture texture = null;
    WGPUSurfaceGetCurrentTextureStatus status = cast(WGPUSurfaceGetCurrentTextureStatus)0;
}

struct WGPUTextureDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    WGPUTextureUsage usage = WGPUTextureUsage.none;
    WGPUTextureDimension dimension = WGPUTextureDimension.undefined;
    WGPUExtent3d size;
    WGPUTextureFormat format = WGPUTextureFormat.undefined;
    uint32_t mipLevelCount = 1;
    uint32_t sampleCount = 1;
    size_t viewFormatCount = 0;
    const(WGPUTextureFormat)* viewFormats = null;
}

struct WGPUTextureBindingViewDimension
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.textureBindingViewDimension);
    WGPUTextureViewDimension textureBindingViewDimension = WGPUTextureViewDimension.undefined;
}

struct WGPUTextureViewDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    WGPUTextureFormat format = WGPUTextureFormat.undefined;
    WGPUTextureViewDimension dimension = WGPUTextureViewDimension.undefined;
    uint32_t baseMipLevel = 0;
    uint32_t mipLevelCount = WGPUMipLevelCountUndefined;
    uint32_t baseArrayLayer = 0;
    uint32_t arrayLayerCount = WGPUArrayLayerCountUndefined;
    WGPUTextureAspect aspect = WGPUTextureAspect.undefined;
    WGPUTextureUsage usage = WGPUTextureUsage.none;
}

struct WGPUTexelBufferViewDescriptor
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUStringView label;
    WGPUTextureFormat format = WGPUTextureFormat.undefined;
    uint64_t offset = 0;
    uint64_t size = WGPUWholeSize;
}

struct WGPUTextureComponentSwizzleDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.textureComponentSwizzleDescriptor);
    WGPUTextureComponentSwizzle swizzle;
}

struct WGPUTextureComponentSwizzle
{
    WGPUComponentSwizzle r = WGPUComponentSwizzle.undefined;
    WGPUComponentSwizzle g = WGPUComponentSwizzle.undefined;
    WGPUComponentSwizzle b = WGPUComponentSwizzle.undefined;
    WGPUComponentSwizzle a = WGPUComponentSwizzle.undefined;
}

struct WGPUYCbCrVkDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.yCbCrVkDescriptor);
    uint32_t vkFormat = 0;
    uint32_t vkYCbCrModel = 0;
    uint32_t vkYCbCrRange = 0;
    uint32_t vkComponentSwizzleRed = 0;
    uint32_t vkComponentSwizzleGreen = 0;
    uint32_t vkComponentSwizzleBlue = 0;
    uint32_t vkComponentSwizzleAlpha = 0;
    uint32_t vkXChromaOffset = 0;
    uint32_t vkYChromaOffset = 0;
    WGPUFilterMode vkChromaFilter = WGPUFilterMode.undefined;
    WGPUBool forceExplicitReconstruction = false;
    uint64_t externalFormat = 0;
}

struct WGPUDawnTextureInternalUsageDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnTextureInternalUsageDescriptor);
    WGPUTextureUsage internalUsage = WGPUTextureUsage.none;
}

struct WGPUDawnEncoderInternalUsageDescriptor
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnEncoderInternalUsageDescriptor);
    WGPUBool useInternalUsages = false;
}

struct WGPUDawnAdapterPropertiesPowerPreference
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.dawnAdapterPropertiesPowerPreference);
    WGPUPowerPreference powerPreference = WGPUPowerPreference.undefined;
}

struct WGPUMemoryHeapInfo
{
    WGPUHeapProperty properties = WGPUHeapProperty.none;
    uint64_t size = 0;
}

struct WGPUAdapterPropertiesMemoryHeaps
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.adapterPropertiesMemoryHeaps);
    size_t heapCount = 0;
    const(WGPUMemoryHeapInfo)* heapInfo = null;
}

struct WGPUAdapterPropertiesD3d
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.adapterPropertiesD3d);
    uint32_t shaderModel = 0;
}

struct WGPUAdapterPropertiesVk
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.adapterPropertiesVk);
    uint32_t driverVersion = 0;
}

struct WGPUAdapterPropertiesDrm
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.adapterPropertiesDrm);
    WGPUBool hasPrimary = false;
    WGPUBool hasRender = false;
    uint64_t primaryMajor = 0;
    uint64_t primaryMinor = 0;
    uint64_t renderMajor = 0;
    uint64_t renderMinor = 0;
}

struct WGPUAdapterPropertiesWgpu
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.adapterPropertiesWgpu);
    WGPUBackendType backendType = WGPUBackendType.undefined;
}

struct WGPUDawnBufferDescriptorErrorInfoFromWireClient
{
    WGPUChainedStruct chain = WGPUChainedStruct(null, WGPUSType.dawnBufferDescriptorErrorInfoFromWireClient);
    WGPUBool outOfMemory = false;
}

struct WGPUSubgroupMatrixConfig
{
    WGPUSubgroupMatrixComponentType componentType = cast(WGPUSubgroupMatrixComponentType)0;
    WGPUSubgroupMatrixComponentType resultComponentType = cast(WGPUSubgroupMatrixComponentType)0;
    uint32_t m = 0;
    uint32_t n = 0;
    uint32_t k = 0;
}

struct WGPUAdapterPropertiesSubgroupMatrixConfigs
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.adapterPropertiesSubgroupMatrixConfigs);
    size_t configCount = 0;
    const(WGPUSubgroupMatrixConfig)* configs = null;
}

struct WGPUAdapterPropertiesExplicitComputeSubgroupSizeConfigs
{
    WGPUChainedStructOut chain = WGPUChainedStructOut(null, WGPUSType.adapterPropertiesExplicitComputeSubgroupSizeConfigs);
    uint32_t minExplicitComputeSubgroupSize = 0;
    uint32_t maxExplicitComputeSubgroupSize = 0;
    uint32_t maxComputeWorkgroupSubgroups = 0;
}

struct WGPURequestAdapterCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUCallbackMode mode = cast(WGPUCallbackMode)0;
    WGPURequestAdapterCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

struct WGPUBufferMapCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUCallbackMode mode = cast(WGPUCallbackMode)0;
    WGPUBufferMapCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

struct WGPUCompilationInfoCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUCallbackMode mode = cast(WGPUCallbackMode)0;
    WGPUCompilationInfoCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

struct WGPUCreateComputePipelineAsyncCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUCallbackMode mode = cast(WGPUCallbackMode)0;
    WGPUCreateComputePipelineAsyncCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

struct WGPUCreateRenderPipelineAsyncCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUCallbackMode mode = cast(WGPUCallbackMode)0;
    WGPUCreateRenderPipelineAsyncCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

struct WGPUDeviceLostCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUCallbackMode mode = cast(WGPUCallbackMode)0;
    WGPUDeviceLostCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

struct WGPUUncapturedErrorCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUUncapturedErrorCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

struct WGPUPopErrorScopeCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUCallbackMode mode = cast(WGPUCallbackMode)0;
    WGPUPopErrorScopeCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

struct WGPULoggingCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPULoggingCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

struct WGPUQueueWorkDoneCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUCallbackMode mode = cast(WGPUCallbackMode)0;
    WGPUQueueWorkDoneCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

struct WGPURequestDeviceCallbackInfo
{
    const(WGPUChainedStruct)* nextInChain = null;
    WGPUCallbackMode mode = cast(WGPUCallbackMode)0;
    WGPURequestDeviceCallback callback = null;
    void* userdata1 = null;
    void* userdata2 = null;
}

