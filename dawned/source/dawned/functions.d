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
module dawned.functions;

import dawned.types;
import core.stdc.stdint;

extern(C) @nogc nothrow:

WGPUInstance wgpuCreateInstance(const(WGPUInstanceDescriptor)* descriptor);
WGPUProc wgpuGetProcAddress(WGPUStringView procName);
void wgpuGetInstanceFeatures(WGPUSupportedInstanceFeatures* features);
WGPUBool wgpuHasInstanceFeature(WGPUInstanceFeatureName feature);
WGPUStatus wgpuGetInstanceLimits(WGPUInstanceLimits* limits);
WGPUInstance wgpuAdapterGetInstance(WGPUAdapter adapter);
WGPUStatus wgpuAdapterGetLimits(WGPUAdapter adapter, WGPULimits* limits);
WGPUStatus wgpuAdapterGetInfo(WGPUAdapter adapter, WGPUAdapterInfo* info);
WGPUBool wgpuAdapterHasFeature(WGPUAdapter adapter, WGPUFeatureName feature);
void wgpuAdapterGetFeatures(WGPUAdapter adapter, WGPUSupportedFeatures* features);
WGPUFuture wgpuAdapterRequestDevice(WGPUAdapter adapter, const(WGPUDeviceDescriptor)* descriptor, WGPURequestDeviceCallbackInfo callbackInfo);
WGPUDevice wgpuAdapterCreateDevice(WGPUAdapter adapter, const(WGPUDeviceDescriptor)* descriptor);
WGPUStatus wgpuAdapterGetFormatCapabilities(WGPUAdapter adapter, WGPUTextureFormat format, WGPUDawnFormatCapabilities* capabilities);
void wgpuAdapterAddRef(WGPUAdapter adapter);
void wgpuAdapterRelease(WGPUAdapter adapter);

void wgpuBindGroupSetLabel(WGPUBindGroup bindGroup, WGPUStringView label);
void wgpuBindGroupAddRef(WGPUBindGroup bindGroup);
void wgpuBindGroupRelease(WGPUBindGroup bindGroup);

void wgpuBindGroupLayoutSetLabel(WGPUBindGroupLayout bindGroupLayout, WGPUStringView label);
void wgpuBindGroupLayoutAddRef(WGPUBindGroupLayout bindGroupLayout);
void wgpuBindGroupLayoutRelease(WGPUBindGroupLayout bindGroupLayout);

WGPUFuture wgpuBufferMapAsync(WGPUBuffer buffer, WGPUMapMode mode, size_t offset, size_t size, WGPUBufferMapCallbackInfo callbackInfo);
void* wgpuBufferGetMappedRange(WGPUBuffer buffer, size_t offset, size_t size);
const(void)* wgpuBufferGetConstMappedRange(WGPUBuffer buffer, size_t offset, size_t size);
WGPUStatus wgpuBufferWriteMappedRange(WGPUBuffer buffer, size_t offset, const(void)* data, size_t size);
WGPUStatus wgpuBufferReadMappedRange(WGPUBuffer buffer, size_t offset, void* data, size_t size);
WGPUTexelBufferView wgpuBufferCreateTexelView(WGPUBuffer buffer, const(WGPUTexelBufferViewDescriptor)* descriptor);
void wgpuBufferSetLabel(WGPUBuffer buffer, WGPUStringView label);
WGPUBufferUsage wgpuBufferGetUsage(WGPUBuffer buffer);
uint64_t wgpuBufferGetSize(WGPUBuffer buffer);
WGPUBufferMapState wgpuBufferGetMapState(WGPUBuffer buffer);
void wgpuBufferUnmap(WGPUBuffer buffer);
void wgpuBufferDestroy(WGPUBuffer buffer);
void wgpuBufferAddRef(WGPUBuffer buffer);
void wgpuBufferRelease(WGPUBuffer buffer);

void wgpuCommandBufferSetLabel(WGPUCommandBuffer commandBuffer, WGPUStringView label);
void wgpuCommandBufferAddRef(WGPUCommandBuffer commandBuffer);
void wgpuCommandBufferRelease(WGPUCommandBuffer commandBuffer);

WGPUCommandBuffer wgpuCommandEncoderFinish(WGPUCommandEncoder commandEncoder, const(WGPUCommandBufferDescriptor)* descriptor);
WGPUComputePassEncoder wgpuCommandEncoderBeginComputePass(WGPUCommandEncoder commandEncoder, const(WGPUComputePassDescriptor)* descriptor);
WGPURenderPassEncoder wgpuCommandEncoderBeginRenderPass(WGPUCommandEncoder commandEncoder, const(WGPURenderPassDescriptor)* descriptor);
void wgpuCommandEncoderCopyBufferToBuffer(WGPUCommandEncoder commandEncoder, WGPUBuffer source, uint64_t sourceOffset, WGPUBuffer destination, uint64_t destinationOffset, uint64_t size);
void wgpuCommandEncoderCopyBufferToTexture(WGPUCommandEncoder commandEncoder, const(WGPUTexelCopyBufferInfo)* source, const(WGPUTexelCopyTextureInfo)* destination, const(WGPUExtent3d)* copySize);
void wgpuCommandEncoderCopyTextureToBuffer(WGPUCommandEncoder commandEncoder, const(WGPUTexelCopyTextureInfo)* source, const(WGPUTexelCopyBufferInfo)* destination, const(WGPUExtent3d)* copySize);
void wgpuCommandEncoderCopyTextureToTexture(WGPUCommandEncoder commandEncoder, const(WGPUTexelCopyTextureInfo)* source, const(WGPUTexelCopyTextureInfo)* destination, const(WGPUExtent3d)* copySize);
void wgpuCommandEncoderClearBuffer(WGPUCommandEncoder commandEncoder, WGPUBuffer buffer, uint64_t offset, uint64_t size);
void wgpuCommandEncoderInjectValidationError(WGPUCommandEncoder commandEncoder, WGPUStringView message);
void wgpuCommandEncoderInsertDebugMarker(WGPUCommandEncoder commandEncoder, WGPUStringView markerLabel);
void wgpuCommandEncoderPopDebugGroup(WGPUCommandEncoder commandEncoder);
void wgpuCommandEncoderPushDebugGroup(WGPUCommandEncoder commandEncoder, WGPUStringView groupLabel);
void wgpuCommandEncoderResolveQuerySet(WGPUCommandEncoder commandEncoder, WGPUQuerySet querySet, uint32_t firstQuery, uint32_t queryCount, WGPUBuffer destination, uint64_t destinationOffset);
void wgpuCommandEncoderWriteBuffer(WGPUCommandEncoder commandEncoder, WGPUBuffer buffer, uint64_t bufferOffset, const(uint8_t)* data, uint64_t size);
void wgpuCommandEncoderWriteTimestamp(WGPUCommandEncoder commandEncoder, WGPUQuerySet querySet, uint32_t queryIndex);
void wgpuCommandEncoderSetLabel(WGPUCommandEncoder commandEncoder, WGPUStringView label);
void wgpuCommandEncoderAddRef(WGPUCommandEncoder commandEncoder);
void wgpuCommandEncoderRelease(WGPUCommandEncoder commandEncoder);

void wgpuComputePassEncoderInsertDebugMarker(WGPUComputePassEncoder computePassEncoder, WGPUStringView markerLabel);
void wgpuComputePassEncoderPopDebugGroup(WGPUComputePassEncoder computePassEncoder);
void wgpuComputePassEncoderPushDebugGroup(WGPUComputePassEncoder computePassEncoder, WGPUStringView groupLabel);
void wgpuComputePassEncoderSetPipeline(WGPUComputePassEncoder computePassEncoder, WGPUComputePipeline pipeline);
void wgpuComputePassEncoderSetBindGroup(WGPUComputePassEncoder computePassEncoder, uint32_t groupIndex, WGPUBindGroup group, size_t dynamicOffsetCount, const(uint32_t)* dynamicOffsets);
void wgpuComputePassEncoderWriteTimestamp(WGPUComputePassEncoder computePassEncoder, WGPUQuerySet querySet, uint32_t queryIndex);
void wgpuComputePassEncoderDispatchWorkgroups(WGPUComputePassEncoder computePassEncoder, uint32_t workgroupcountx, uint32_t workgroupcounty, uint32_t workgroupcountz);
void wgpuComputePassEncoderDispatchWorkgroupsIndirect(WGPUComputePassEncoder computePassEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset);
void wgpuComputePassEncoderEnd(WGPUComputePassEncoder computePassEncoder);
void wgpuComputePassEncoderSetLabel(WGPUComputePassEncoder computePassEncoder, WGPUStringView label);
void wgpuComputePassEncoderSetImmediates(WGPUComputePassEncoder computePassEncoder, uint32_t offset, const(void)* data, size_t size);
void wgpuComputePassEncoderSetResourceTable(WGPUComputePassEncoder computePassEncoder, WGPUResourceTable table);
void wgpuComputePassEncoderAddRef(WGPUComputePassEncoder computePassEncoder);
void wgpuComputePassEncoderRelease(WGPUComputePassEncoder computePassEncoder);

WGPUBindGroupLayout wgpuComputePipelineGetBindGroupLayout(WGPUComputePipeline computePipeline, uint32_t groupIndex);
void wgpuComputePipelineSetLabel(WGPUComputePipeline computePipeline, WGPUStringView label);
void wgpuComputePipelineAddRef(WGPUComputePipeline computePipeline);
void wgpuComputePipelineRelease(WGPUComputePipeline computePipeline);

WGPUBindGroup wgpuDeviceCreateBindGroup(WGPUDevice device, const(WGPUBindGroupDescriptor)* descriptor);
WGPUBindGroupLayout wgpuDeviceCreateBindGroupLayout(WGPUDevice device, const(WGPUBindGroupLayoutDescriptor)* descriptor);
WGPUBuffer wgpuDeviceCreateBuffer(WGPUDevice device, const(WGPUBufferDescriptor)* descriptor);
WGPUBuffer wgpuDeviceCreateErrorBuffer(WGPUDevice device, const(WGPUBufferDescriptor)* descriptor);
WGPUCommandEncoder wgpuDeviceCreateCommandEncoder(WGPUDevice device, const(WGPUCommandEncoderDescriptor)* descriptor);
WGPUComputePipeline wgpuDeviceCreateComputePipeline(WGPUDevice device, const(WGPUComputePipelineDescriptor)* descriptor);
WGPUFuture wgpuDeviceCreateComputePipelineAsync(WGPUDevice device, const(WGPUComputePipelineDescriptor)* descriptor, WGPUCreateComputePipelineAsyncCallbackInfo callbackInfo);
WGPUExternalTexture wgpuDeviceCreateExternalTexture(WGPUDevice device, const(WGPUExternalTextureDescriptor)* externalTextureDescriptor);
WGPUExternalTexture wgpuDeviceCreateErrorExternalTexture(WGPUDevice device);
WGPUPipelineLayout wgpuDeviceCreatePipelineLayout(WGPUDevice device, const(WGPUPipelineLayoutDescriptor)* descriptor);
WGPUQuerySet wgpuDeviceCreateQuerySet(WGPUDevice device, const(WGPUQuerySetDescriptor)* descriptor);
WGPUFuture wgpuDeviceCreateRenderPipelineAsync(WGPUDevice device, const(WGPURenderPipelineDescriptor)* descriptor, WGPUCreateRenderPipelineAsyncCallbackInfo callbackInfo);
WGPURenderBundleEncoder wgpuDeviceCreateRenderBundleEncoder(WGPUDevice device, const(WGPURenderBundleEncoderDescriptor)* descriptor);
WGPURenderPipeline wgpuDeviceCreateRenderPipeline(WGPUDevice device, const(WGPURenderPipelineDescriptor)* descriptor);
WGPUSampler wgpuDeviceCreateSampler(WGPUDevice device, const(WGPUSamplerDescriptor)* descriptor);
WGPUShaderModule wgpuDeviceCreateShaderModule(WGPUDevice device, const(WGPUShaderModuleDescriptor)* descriptor);
WGPUShaderModule wgpuDeviceCreateErrorShaderModule(WGPUDevice device, const(WGPUShaderModuleDescriptor)* descriptor, WGPUStringView errorMessage);
WGPUTexture wgpuDeviceCreateTexture(WGPUDevice device, const(WGPUTextureDescriptor)* descriptor);
WGPUResourceTable wgpuDeviceCreateResourceTable(WGPUDevice device, const(WGPUResourceTableDescriptor)* descriptor);
WGPUSharedBufferMemory wgpuDeviceImportSharedBufferMemory(WGPUDevice device, const(WGPUSharedBufferMemoryDescriptor)* descriptor);
WGPUSharedTextureMemory wgpuDeviceImportSharedTextureMemory(WGPUDevice device, const(WGPUSharedTextureMemoryDescriptor)* descriptor);
WGPUSharedFence wgpuDeviceImportSharedFence(WGPUDevice device, const(WGPUSharedFenceDescriptor)* descriptor);
WGPUTexture wgpuDeviceCreateErrorTexture(WGPUDevice device, const(WGPUTextureDescriptor)* descriptor);
void wgpuDeviceDestroy(WGPUDevice device);
WGPUStatus wgpuDeviceGetAHardwareBufferProperties(WGPUDevice device, void* handle, WGPUAHardwareBufferProperties* properties);
WGPUStatus wgpuDeviceGetLimits(WGPUDevice device, WGPULimits* limits);
WGPUFuture wgpuDeviceGetLostFuture(WGPUDevice device);
WGPUBool wgpuDeviceHasFeature(WGPUDevice device, WGPUFeatureName feature);
void wgpuDeviceGetFeatures(WGPUDevice device, WGPUSupportedFeatures* features);
WGPUStatus wgpuDeviceGetAdapterInfo(WGPUDevice device, WGPUAdapterInfo* adapterInfo);
WGPUAdapter wgpuDeviceGetAdapter(WGPUDevice device);
WGPUQueue wgpuDeviceGetQueue(WGPUDevice device);
void wgpuDeviceInjectError(WGPUDevice device, WGPUErrorType type, WGPUStringView message);
void wgpuDeviceForceLoss(WGPUDevice device, WGPUDeviceLostReason type, WGPUStringView message);
void wgpuDeviceTick(WGPUDevice device);
void wgpuDeviceSetLoggingCallback(WGPUDevice device, WGPULoggingCallbackInfo callbackInfo);
void wgpuDevicePushErrorScope(WGPUDevice device, WGPUErrorFilter filter);
WGPUFuture wgpuDevicePopErrorScope(WGPUDevice device, WGPUPopErrorScopeCallbackInfo callbackInfo);
void wgpuDeviceSetLabel(WGPUDevice device, WGPUStringView label);
void wgpuDeviceValidateTextureDescriptor(WGPUDevice device, const(WGPUTextureDescriptor)* descriptor);
void wgpuDeviceAddRef(WGPUDevice device);
void wgpuDeviceRelease(WGPUDevice device);

void wgpuExternalTextureSetLabel(WGPUExternalTexture externalTexture, WGPUStringView label);
void wgpuExternalTextureDestroy(WGPUExternalTexture externalTexture);
void wgpuExternalTextureExpire(WGPUExternalTexture externalTexture);
void wgpuExternalTextureRefresh(WGPUExternalTexture externalTexture);
void wgpuExternalTextureAddRef(WGPUExternalTexture externalTexture);
void wgpuExternalTextureRelease(WGPUExternalTexture externalTexture);

void wgpuSharedBufferMemorySetLabel(WGPUSharedBufferMemory sharedBufferMemory, WGPUStringView label);
WGPUStatus wgpuSharedBufferMemoryGetProperties(WGPUSharedBufferMemory sharedBufferMemory, WGPUSharedBufferMemoryProperties* properties);
WGPUBuffer wgpuSharedBufferMemoryCreateBuffer(WGPUSharedBufferMemory sharedBufferMemory, const(WGPUBufferDescriptor)* descriptor);
WGPUStatus wgpuSharedBufferMemoryBeginAccess(WGPUSharedBufferMemory sharedBufferMemory, WGPUBuffer buffer, const(WGPUSharedBufferMemoryBeginAccessDescriptor)* descriptor);
WGPUStatus wgpuSharedBufferMemoryEndAccess(WGPUSharedBufferMemory sharedBufferMemory, WGPUBuffer buffer, WGPUSharedBufferMemoryEndAccessState* descriptor);
WGPUBool wgpuSharedBufferMemoryIsDeviceLost(WGPUSharedBufferMemory sharedBufferMemory);
void wgpuSharedBufferMemoryAddRef(WGPUSharedBufferMemory sharedBufferMemory);
void wgpuSharedBufferMemoryRelease(WGPUSharedBufferMemory sharedBufferMemory);

void wgpuSharedTextureMemorySetLabel(WGPUSharedTextureMemory sharedTextureMemory, WGPUStringView label);
WGPUStatus wgpuSharedTextureMemoryGetProperties(WGPUSharedTextureMemory sharedTextureMemory, WGPUSharedTextureMemoryProperties* properties);
WGPUTexture wgpuSharedTextureMemoryCreateTexture(WGPUSharedTextureMemory sharedTextureMemory, const(WGPUTextureDescriptor)* descriptor);
WGPUStatus wgpuSharedTextureMemoryBeginAccess(WGPUSharedTextureMemory sharedTextureMemory, WGPUTexture texture, const(WGPUSharedTextureMemoryBeginAccessDescriptor)* descriptor);
WGPUStatus wgpuSharedTextureMemoryEndAccess(WGPUSharedTextureMemory sharedTextureMemory, WGPUTexture texture, WGPUSharedTextureMemoryEndAccessState* descriptor);
WGPUBool wgpuSharedTextureMemoryIsDeviceLost(WGPUSharedTextureMemory sharedTextureMemory);
void wgpuSharedTextureMemoryAddRef(WGPUSharedTextureMemory sharedTextureMemory);
void wgpuSharedTextureMemoryRelease(WGPUSharedTextureMemory sharedTextureMemory);

void wgpuSharedFenceSetLabel(WGPUSharedFence sharedFence, WGPUStringView label);
void wgpuSharedFenceExportInfo(WGPUSharedFence sharedFence, WGPUSharedFenceExportInfo* info);
void wgpuSharedFenceAddRef(WGPUSharedFence sharedFence);
void wgpuSharedFenceRelease(WGPUSharedFence sharedFence);

WGPUSurface wgpuInstanceCreateSurface(WGPUInstance instance, const(WGPUSurfaceDescriptor)* descriptor);
void wgpuInstanceProcessEvents(WGPUInstance instance);
WGPUWaitStatus wgpuInstanceWaitAny(WGPUInstance instance, size_t futureCount, WGPUFutureWaitInfo* futures, uint64_t timeoutNs);
WGPUFuture wgpuInstanceRequestAdapter(WGPUInstance instance, const(WGPURequestAdapterOptions)* options, WGPURequestAdapterCallbackInfo callbackInfo);
WGPUBool wgpuInstanceHasWgslLanguageFeature(WGPUInstance instance, WGPUWgslLanguageFeatureName feature);
void wgpuInstanceGetWgslLanguageFeatures(WGPUInstance instance, WGPUSupportedWgslLanguageFeatures* features);
void wgpuInstanceAddRef(WGPUInstance instance);
void wgpuInstanceRelease(WGPUInstance instance);

void wgpuPipelineLayoutSetLabel(WGPUPipelineLayout pipelineLayout, WGPUStringView label);
void wgpuPipelineLayoutAddRef(WGPUPipelineLayout pipelineLayout);
void wgpuPipelineLayoutRelease(WGPUPipelineLayout pipelineLayout);

void wgpuQuerySetSetLabel(WGPUQuerySet querySet, WGPUStringView label);
WGPUQueryType wgpuQuerySetGetType(WGPUQuerySet querySet);
uint32_t wgpuQuerySetGetCount(WGPUQuerySet querySet);
void wgpuQuerySetDestroy(WGPUQuerySet querySet);
void wgpuQuerySetAddRef(WGPUQuerySet querySet);
void wgpuQuerySetRelease(WGPUQuerySet querySet);

void wgpuQueueSubmit(WGPUQueue queue, size_t commandCount, const(WGPUCommandBuffer)* commands);
WGPUFuture wgpuQueueOnSubmittedWorkDone(WGPUQueue queue, WGPUQueueWorkDoneCallbackInfo callbackInfo);
void wgpuQueueWriteBuffer(WGPUQueue queue, WGPUBuffer buffer, uint64_t bufferOffset, const(void)* data, size_t size);
void wgpuQueueWriteTexture(WGPUQueue queue, const(WGPUTexelCopyTextureInfo)* destination, const(void)* data, size_t dataSize, const(WGPUTexelCopyBufferLayout)* dataLayout, const(WGPUExtent3d)* writeSize);
void wgpuQueueCopyTextureForBrowser(WGPUQueue queue, const(WGPUTexelCopyTextureInfo)* source, const(WGPUTexelCopyTextureInfo)* destination, const(WGPUExtent3d)* copySize, const(WGPUCopyTextureForBrowserOptions)* options);
void wgpuQueueCopyExternalTextureForBrowser(WGPUQueue queue, const(WGPUImageCopyExternalTexture)* source, const(WGPUTexelCopyTextureInfo)* destination, const(WGPUExtent3d)* copySize, const(WGPUCopyTextureForBrowserOptions)* options);
void wgpuQueueSetLabel(WGPUQueue queue, WGPUStringView label);
void wgpuQueueAddRef(WGPUQueue queue);
void wgpuQueueRelease(WGPUQueue queue);

void wgpuRenderBundleSetLabel(WGPURenderBundle renderBundle, WGPUStringView label);
void wgpuRenderBundleAddRef(WGPURenderBundle renderBundle);
void wgpuRenderBundleRelease(WGPURenderBundle renderBundle);

void wgpuRenderBundleEncoderSetPipeline(WGPURenderBundleEncoder renderBundleEncoder, WGPURenderPipeline pipeline);
void wgpuRenderBundleEncoderSetBindGroup(WGPURenderBundleEncoder renderBundleEncoder, uint32_t groupIndex, WGPUBindGroup group, size_t dynamicOffsetCount, const(uint32_t)* dynamicOffsets);
void wgpuRenderBundleEncoderDraw(WGPURenderBundleEncoder renderBundleEncoder, uint32_t vertexCount, uint32_t instanceCount, uint32_t firstVertex, uint32_t firstInstance);
void wgpuRenderBundleEncoderDrawIndexed(WGPURenderBundleEncoder renderBundleEncoder, uint32_t indexCount, uint32_t instanceCount, uint32_t firstIndex, int32_t baseVertex, uint32_t firstInstance);
void wgpuRenderBundleEncoderDrawIndirect(WGPURenderBundleEncoder renderBundleEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset);
void wgpuRenderBundleEncoderDrawIndexedIndirect(WGPURenderBundleEncoder renderBundleEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset);
void wgpuRenderBundleEncoderInsertDebugMarker(WGPURenderBundleEncoder renderBundleEncoder, WGPUStringView markerLabel);
void wgpuRenderBundleEncoderPopDebugGroup(WGPURenderBundleEncoder renderBundleEncoder);
void wgpuRenderBundleEncoderPushDebugGroup(WGPURenderBundleEncoder renderBundleEncoder, WGPUStringView groupLabel);
void wgpuRenderBundleEncoderSetVertexBuffer(WGPURenderBundleEncoder renderBundleEncoder, uint32_t slot, WGPUBuffer buffer, uint64_t offset, uint64_t size);
void wgpuRenderBundleEncoderSetIndexBuffer(WGPURenderBundleEncoder renderBundleEncoder, WGPUBuffer buffer, WGPUIndexFormat format, uint64_t offset, uint64_t size);
WGPURenderBundle wgpuRenderBundleEncoderFinish(WGPURenderBundleEncoder renderBundleEncoder, const(WGPURenderBundleDescriptor)* descriptor);
void wgpuRenderBundleEncoderSetLabel(WGPURenderBundleEncoder renderBundleEncoder, WGPUStringView label);
void wgpuRenderBundleEncoderSetImmediates(WGPURenderBundleEncoder renderBundleEncoder, uint32_t offset, const(void)* data, size_t size);
void wgpuRenderBundleEncoderSetResourceTable(WGPURenderBundleEncoder renderBundleEncoder, WGPUResourceTable table);
void wgpuRenderBundleEncoderAddRef(WGPURenderBundleEncoder renderBundleEncoder);
void wgpuRenderBundleEncoderRelease(WGPURenderBundleEncoder renderBundleEncoder);

void wgpuRenderPassEncoderSetPipeline(WGPURenderPassEncoder renderPassEncoder, WGPURenderPipeline pipeline);
void wgpuRenderPassEncoderSetBindGroup(WGPURenderPassEncoder renderPassEncoder, uint32_t groupIndex, WGPUBindGroup group, size_t dynamicOffsetCount, const(uint32_t)* dynamicOffsets);
void wgpuRenderPassEncoderDraw(WGPURenderPassEncoder renderPassEncoder, uint32_t vertexCount, uint32_t instanceCount, uint32_t firstVertex, uint32_t firstInstance);
void wgpuRenderPassEncoderDrawIndexed(WGPURenderPassEncoder renderPassEncoder, uint32_t indexCount, uint32_t instanceCount, uint32_t firstIndex, int32_t baseVertex, uint32_t firstInstance);
void wgpuRenderPassEncoderDrawIndirect(WGPURenderPassEncoder renderPassEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset);
void wgpuRenderPassEncoderDrawIndexedIndirect(WGPURenderPassEncoder renderPassEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset);
void wgpuRenderPassEncoderMultiDrawIndirect(WGPURenderPassEncoder renderPassEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset, uint32_t maxDrawCount, WGPUBuffer drawCountBuffer, uint64_t drawCountBufferOffset);
void wgpuRenderPassEncoderMultiDrawIndexedIndirect(WGPURenderPassEncoder renderPassEncoder, WGPUBuffer indirectBuffer, uint64_t indirectOffset, uint32_t maxDrawCount, WGPUBuffer drawCountBuffer, uint64_t drawCountBufferOffset);
void wgpuRenderPassEncoderExecuteBundles(WGPURenderPassEncoder renderPassEncoder, size_t bundleCount, const(WGPURenderBundle)* bundles);
void wgpuRenderPassEncoderInsertDebugMarker(WGPURenderPassEncoder renderPassEncoder, WGPUStringView markerLabel);
void wgpuRenderPassEncoderPopDebugGroup(WGPURenderPassEncoder renderPassEncoder);
void wgpuRenderPassEncoderPushDebugGroup(WGPURenderPassEncoder renderPassEncoder, WGPUStringView groupLabel);
void wgpuRenderPassEncoderSetStencilReference(WGPURenderPassEncoder renderPassEncoder, uint32_t reference);
void wgpuRenderPassEncoderSetBlendConstant(WGPURenderPassEncoder renderPassEncoder, const(WGPUColor)* color);
void wgpuRenderPassEncoderSetViewport(WGPURenderPassEncoder renderPassEncoder, float x, float y, float width, float height, float minDepth, float maxDepth);
void wgpuRenderPassEncoderSetScissorRect(WGPURenderPassEncoder renderPassEncoder, uint32_t x, uint32_t y, uint32_t width, uint32_t height);
void wgpuRenderPassEncoderSetVertexBuffer(WGPURenderPassEncoder renderPassEncoder, uint32_t slot, WGPUBuffer buffer, uint64_t offset, uint64_t size);
void wgpuRenderPassEncoderSetIndexBuffer(WGPURenderPassEncoder renderPassEncoder, WGPUBuffer buffer, WGPUIndexFormat format, uint64_t offset, uint64_t size);
void wgpuRenderPassEncoderBeginOcclusionQuery(WGPURenderPassEncoder renderPassEncoder, uint32_t queryIndex);
void wgpuRenderPassEncoderEndOcclusionQuery(WGPURenderPassEncoder renderPassEncoder);
void wgpuRenderPassEncoderWriteTimestamp(WGPURenderPassEncoder renderPassEncoder, WGPUQuerySet querySet, uint32_t queryIndex);
void wgpuRenderPassEncoderPixelLocalStorageBarrier(WGPURenderPassEncoder renderPassEncoder);
void wgpuRenderPassEncoderEnd(WGPURenderPassEncoder renderPassEncoder);
void wgpuRenderPassEncoderSetLabel(WGPURenderPassEncoder renderPassEncoder, WGPUStringView label);
void wgpuRenderPassEncoderSetImmediates(WGPURenderPassEncoder renderPassEncoder, uint32_t offset, const(void)* data, size_t size);
void wgpuRenderPassEncoderSetResourceTable(WGPURenderPassEncoder renderPassEncoder, WGPUResourceTable table);
void wgpuRenderPassEncoderAddRef(WGPURenderPassEncoder renderPassEncoder);
void wgpuRenderPassEncoderRelease(WGPURenderPassEncoder renderPassEncoder);

WGPUBindGroupLayout wgpuRenderPipelineGetBindGroupLayout(WGPURenderPipeline renderPipeline, uint32_t groupIndex);
void wgpuRenderPipelineSetLabel(WGPURenderPipeline renderPipeline, WGPUStringView label);
void wgpuRenderPipelineAddRef(WGPURenderPipeline renderPipeline);
void wgpuRenderPipelineRelease(WGPURenderPipeline renderPipeline);

uint32_t wgpuResourceTableGetSize(WGPUResourceTable resourceTable);
void wgpuResourceTableDestroy(WGPUResourceTable resourceTable);
WGPUStatus wgpuResourceTableUpdate(WGPUResourceTable resourceTable, uint32_t slot, const(WGPUBindingResource)* resource);
uint32_t wgpuResourceTableInsertBinding(WGPUResourceTable resourceTable, const(WGPUBindingResource)* resource);
WGPUStatus wgpuResourceTableRemoveBinding(WGPUResourceTable resourceTable, uint32_t slot);
void wgpuResourceTableAddRef(WGPUResourceTable resourceTable);
void wgpuResourceTableRelease(WGPUResourceTable resourceTable);

void wgpuSamplerSetLabel(WGPUSampler sampler, WGPUStringView label);
void wgpuSamplerAddRef(WGPUSampler sampler);
void wgpuSamplerRelease(WGPUSampler sampler);

WGPUFuture wgpuShaderModuleGetCompilationInfo(WGPUShaderModule shaderModule, WGPUCompilationInfoCallbackInfo callbackInfo);
void wgpuShaderModuleSetLabel(WGPUShaderModule shaderModule, WGPUStringView label);
void wgpuShaderModuleAddRef(WGPUShaderModule shaderModule);
void wgpuShaderModuleRelease(WGPUShaderModule shaderModule);

void wgpuSurfaceConfigure(WGPUSurface surface, const(WGPUSurfaceConfiguration)* config);
WGPUStatus wgpuSurfaceGetCapabilities(WGPUSurface surface, WGPUAdapter adapter, WGPUSurfaceCapabilities* capabilities);
void wgpuSurfaceGetCurrentTexture(WGPUSurface surface, WGPUSurfaceTexture* surfaceTexture);
WGPUStatus wgpuSurfacePresent(WGPUSurface surface);
void wgpuSurfaceUnconfigure(WGPUSurface surface);
void wgpuSurfaceSetLabel(WGPUSurface surface, WGPUStringView label);
void wgpuSurfaceAddRef(WGPUSurface surface);
void wgpuSurfaceRelease(WGPUSurface surface);

WGPUTextureView wgpuTextureCreateView(WGPUTexture texture, const(WGPUTextureViewDescriptor)* descriptor);
WGPUTextureView wgpuTextureCreateErrorView(WGPUTexture texture, const(WGPUTextureViewDescriptor)* descriptor);
void wgpuTextureSetLabel(WGPUTexture texture, WGPUStringView label);
uint32_t wgpuTextureGetWidth(WGPUTexture texture);
uint32_t wgpuTextureGetHeight(WGPUTexture texture);
uint32_t wgpuTextureGetDepthOrArrayLayers(WGPUTexture texture);
uint32_t wgpuTextureGetMipLevelCount(WGPUTexture texture);
uint32_t wgpuTextureGetSampleCount(WGPUTexture texture);
WGPUTextureDimension wgpuTextureGetDimension(WGPUTexture texture);
WGPUTextureFormat wgpuTextureGetFormat(WGPUTexture texture);
WGPUTextureUsage wgpuTextureGetUsage(WGPUTexture texture);
WGPUTextureViewDimension wgpuTextureGetTextureBindingViewDimension(WGPUTexture texture);
void wgpuTextureDestroy(WGPUTexture texture);
void wgpuTexturePin(WGPUTexture texture, WGPUTextureUsage usage);
void wgpuTextureUnpin(WGPUTexture texture);
void wgpuTextureSetOwnershipForMemoryDump(WGPUTexture texture, uint64_t ownerGuid);
void wgpuTextureAddRef(WGPUTexture texture);
void wgpuTextureRelease(WGPUTexture texture);

void wgpuTextureViewSetLabel(WGPUTextureView textureView, WGPUStringView label);
void wgpuTextureViewAddRef(WGPUTextureView textureView);
void wgpuTextureViewRelease(WGPUTextureView textureView);

void wgpuTexelBufferViewSetLabel(WGPUTexelBufferView texelBufferView, WGPUStringView label);
void wgpuTexelBufferViewAddRef(WGPUTexelBufferView texelBufferView);
void wgpuTexelBufferViewRelease(WGPUTexelBufferView texelBufferView);

void wgpuAdapterInfoFreeMembers(WGPUAdapterInfo adapterInfo);
void wgpuSurfaceCapabilitiesFreeMembers(WGPUSurfaceCapabilities surfaceCapabilities);
void wgpuSupportedFeaturesFreeMembers(WGPUSupportedFeatures supportedFeatures);
void wgpuSupportedInstanceFeaturesFreeMembers(WGPUSupportedInstanceFeatures supportedInstanceFeatures);
void wgpuSupportedWgslLanguageFeaturesFreeMembers(WGPUSupportedWgslLanguageFeatures supportedWgslLanguageFeatures);
void wgpuSharedBufferMemoryEndAccessStateFreeMembers(WGPUSharedBufferMemoryEndAccessState sharedBufferMemoryEndAccessState);
void wgpuSharedTextureMemoryEndAccessStateFreeMembers(WGPUSharedTextureMemoryEndAccessState sharedTextureMemoryEndAccessState);
void wgpuDawnDrmFormatCapabilitiesFreeMembers(WGPUDawnDrmFormatCapabilities dawnDrmFormatCapabilities);
void wgpuAdapterPropertiesMemoryHeapsFreeMembers(WGPUAdapterPropertiesMemoryHeaps adapterPropertiesMemoryHeaps);
void wgpuAdapterPropertiesSubgroupMatrixConfigsFreeMembers(WGPUAdapterPropertiesSubgroupMatrixConfigs adapterPropertiesSubgroupMatrixConfigs);