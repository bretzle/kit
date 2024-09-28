const std = @import("std");
const builtin = @import("builtin");

const backend = switch (builtin.os.tag) {
    .windows => @import("winapi/window.zig"),
    else => unreachable,
};

pub const Options = struct {
    title: [:0]const u8,
    width: i32,
    height: i32,
    framebuffer: struct {
        width: u32,
        height: u32,
        pixel_size: u32,
        pixel_masks: [4]u32,
    },
    dark_mode: bool,
};

pub const Window = struct {
    const Self = @This();

    width: i32,
    height: i32,
    framebuffer: struct {
        width: u32,
        height: u32,
        data: []u8,
    },
    want_quit: bool = false,

    keys: [256]enum { down, up } = .{.up} ** 256,
    mod: packed struct { ctrl: bool = false, shift: bool = false, alt: bool = false, meta: bool = false } = .{},

    extra: backend.Extra,

    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator, options: Options) !*Self {
        const self = try allocator.create(Self);
        const framebuffer = try allocator.alloc(u8, options.framebuffer.width * options.framebuffer.height * options.framebuffer.pixel_size);

        self.* = .{
            .width = options.width,
            .height = options.height,
            .framebuffer = .{
                .width = options.framebuffer.width,
                .height = options.framebuffer.height,
                .data = framebuffer,
            },

            .extra = undefined,

            .allocator = allocator,
        };

        try backend.create(self, options);

        return self;
    }

    pub fn destroy(self: *Self) void {
        backend.destroy(self);
        self.allocator.free(self.framebuffer.data);
        self.allocator.destroy(self);
    }

    pub fn step(self: *Self) bool {
        backend.step(self);
        return !self.want_quit;
    }

    pub fn changeColor(self: *Self, comptime Color: type) !void {
        try backend.changeColor(self, Color);

        const old = self.framebuffer.data.len;
        const size = self.framebuffer.width * self.framebuffer.height * @sizeOf(Color);
        if (size != old) {
            self.framebuffer.data = try self.allocator.realloc(self.framebuffer.data, size);
        }
    }

    pub fn resizeFramebuffer(self: *Self, width: u32, height: u32) !void {
        self.framebuffer.width = width;
        self.framebuffer.height = height;

        const size = try backend.resizeFramebuffer(self, width, height);
        if (size != self.framebuffer.data.len) {
            self.framebuffer.data = try self.allocator.realloc(self.framebuffer.data, size);
        }
    }
};

pub fn getAdjustedWindowRect(self: *const Window) [4]i32 {
    const screen_w: f32 = @floatFromInt(self.framebuffer.width);
    const screen_h: f32 = @floatFromInt(self.framebuffer.height);

    const win_w: f32 = @floatFromInt(self.width);
    const win_h: f32 = @floatFromInt(self.height);

    // work out maximum size to retain aspect ratio
    const src_ar: f32 = screen_h / screen_w;
    const dst_ar: f32 = win_h / win_w;

    const w = if (src_ar < dst_ar) win_w else @ceil(win_h / src_ar);
    const h = if (src_ar < dst_ar) @ceil(win_w * src_ar) else win_h;

    // return centered rect
    return [4]i32{
        @intFromFloat((win_w - w) / 2),
        @intFromFloat((win_h - h) / 2),
        @intFromFloat(w),
        @intFromFloat(h),
    };
}
