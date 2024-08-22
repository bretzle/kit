const math = @import("../math.zig");

const Vec2 = math.Vec2;

pub const Mouse = enum { none, left, right, middle };

pub const Key = packed struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    backspace: bool = false,
    ret: bool = false,
};

const Self = @This();

mouse_pos: Vec2 = .{ 0, 0 },
last_mouse_pos: Vec2 = .{ 0, 0 },
mouse_delta: Vec2 = .{ 0, 0 },
scroll_delta: Vec2 = .{ 0, 0 },
mouse_down: Mouse = .none,
mouse_pressed: Mouse = .none,
key_down: i32 = 0,
key_pressed: i32 = 0,
text: [32]u8 = [_]u8{0} ** 32,

pub fn mousemove(self: *Self, x: i32, y: i32) void {
    self.mouse_pos = .{ x, y };
}

pub fn mousedown(self: *Self, x: i32, y: i32, btn: Mouse) void {
    self.mousemove(x, y);
    self.mouse_down = btn;
    self.mouse_pressed = btn;
}

pub fn mouseup(self: *Self, x: i32, y: i32, _: Mouse) void {
    self.mousemove(x, y);
    self.mouse_down = .none;
}

pub fn scroll(self: *Self, x: i32, y: i32) void {
    self.scroll_delta[0] += x;
    self.scroll_delta[1] += y;
}

pub fn keydown(self: *Self, key: i32) void {
    self.key_down |= key;
    self.key_pressed |= key;
}

pub fn keyup(self: *Self, key: i32) void {
    self.key_down &= ~key;
}

pub fn text(self: *Self, txt: []const u8) void {
    @memcpy(self.text[0..txt.len], txt);
}
