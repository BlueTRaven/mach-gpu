const Buffer = @This();

/// The type erased pointer to the Buffer implementation
/// Equal to c.WGPUBuffer for NativeInstance.
ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    reference: fn (ptr: *anyopaque) void,
    release: fn (ptr: *anyopaque) void,
    // TODO:
    // WGPU_EXPORT void wgpuBufferDestroy(WGPUBuffer buffer);
    // WGPU_EXPORT void const * wgpuBufferGetConstMappedRange(WGPUBuffer buffer, size_t offset, size_t size);
    // WGPU_EXPORT void * wgpuBufferGetMappedRange(WGPUBuffer buffer, size_t offset, size_t size);
    // WGPU_EXPORT void wgpuBufferMapAsync(WGPUBuffer buffer, WGPUMapModeFlags mode, size_t offset, size_t size, WGPUBufferMapCallback callback, void * userdata);
    setLabel: fn (ptr: *anyopaque, label: [:0]const u8) void,
    // WGPU_EXPORT void wgpuBufferUnmap(WGPUBuffer buffer);
};

pub inline fn reference(buf: Buffer) void {
    buf.vtable.reference(buf.ptr);
}

pub inline fn release(buf: Buffer) void {
    buf.vtable.release(buf.ptr);
}

pub inline fn setLabel(buf: Buffer, label: [:0]const u8) void {
    buf.vtable.setLabel(buf.ptr, label);
}

test "syntax" {
    _ = VTable;
    _ = reference;
    _ = release;
    _ = setLabel;
}
