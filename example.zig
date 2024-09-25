const std = @import("std");
const kit = @import("kit");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const RGBA8 = packed struct { r: u8, g: u8, b: u8, a: u8 };
const RGB5 = packed struct { r: u5, g: u5, b: u5, a: u1 };
const BGR5 = packed struct { b: u5, g: u5, r: u5, a: u1 };

const colors = [3]type{ RGBA8, RGB5, BGR5 };

const DemoUserContext = struct {
    const Self = @This();

    pub const fps = 59.5;
    pub const color = BGR5;

    color: usize = 2,
    width: u32 = 320,
    height: u32 = 240,
    frame: usize = 0,
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator) anyerror!*Self {
        const self = try allocator.create(Self);
        self.* = .{ .allocator = allocator };
        return self;
    }

    pub fn destroy(self: *Self) void {
        self.allocator.destroy(self);
    }

    pub fn update(self: *Self, window: *kit.Window) !void {
        self.frame += 1;

        if (window.keys['1'] == .down) try self.updateColor(window, 0);
        if (window.keys['2'] == .down) try self.updateColor(window, 1);
        if (window.keys['3'] == .down) try self.updateColor(window, 2);

        if (window.keys['-'] == .down) try self.resize(window, 100, 100);
        if (window.keys['='] == .down) try self.resize(window, 320, 240);
    }

    pub fn render(self: *Self, framebuffer: []u8) void {
        if (self.color == 0) {
            self.draw(std.mem.bytesAsSlice(u32, framebuffer));
        } else {
            self.draw(std.mem.bytesAsSlice(u16, framebuffer));
        }
    }

    fn draw(self: *Self, pixels: anytype) void {
        for (0..self.width) |x| {
            for (0..self.height) |y| {
                pixels[(y * self.width) + x] = @truncate(x ^ y ^ self.frame);
            }
        }
    }

    fn updateColor(self: *Self, window: *kit.Window, comptime idx: comptime_int) !void {
        self.color = idx;
        try window.changeColor(colors[idx]);
    }

    fn resize(self: *Self, window: *kit.Window, width: u32, height: u32) !void {
        self.width = width;
        self.height = height;
        try window.resizeFramebuffer(width, height);
    }
};

pub fn main() !void {
    defer _ = gpa.deinit();

    try kit.App(DemoUserContext).start(gpa.allocator(), .{ .framebuffer_width = 320, .framebuffer_height = 240 });
}
