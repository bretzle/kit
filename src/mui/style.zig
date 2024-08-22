const std = @import("std");
const math = @import("../math.zig");

pub const Control = enum { text, border, window_bg, title_bg, title_text, panel_bg, button, button_hover, button_focus, base, base_hover, base_focus, scroll_base, scroll_thumb };
pub const ColorMap = std.EnumArray(Control, math.Color);

size: math.Vec2 = .{ 68, 10 },
padding: i32 = 5,
spacing: i32 = 4,
indent: i32 = 24,
title_height: i32 = 24,
scrollbar_size: i32 = 12,
thumb_size: i32 = 8,
colors: ColorMap = ColorMap.init(.{
    .text = .{ .r = 0xE6, .g = 0xE6, .b = 0xE6, .a = 0xFF },
    .border = .{ .r = 0x19, .g = 0x19, .b = 0x19, .a = 0xFF },
    .window_bg = .{ .r = 0x32, .g = 0x32, .b = 0x32, .a = 0xFF },
    .title_bg = .{ .r = 0x19, .g = 0x19, .b = 0x19, .a = 0xFF },
    .title_text = .{ .r = 0xF0, .g = 0xF0, .b = 0xF0, .a = 0xFF },
    .panel_bg = .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0x00 },
    .button = .{ .r = 0x4B, .g = 0x4B, .b = 0x4B, .a = 0xFF },
    .button_hover = .{ .r = 0x5F, .g = 0x5F, .b = 0x5F, .a = 0xFF },
    .button_focus = .{ .r = 0x73, .g = 0x73, .b = 0x73, .a = 0xFF },
    .base = .{ .r = 0x1E, .g = 0x1E, .b = 0x1E, .a = 0xFF },
    .base_hover = .{ .r = 0x23, .g = 0x23, .b = 0x23, .a = 0xFF },
    .base_focus = .{ .r = 0x28, .g = 0x28, .b = 0x28, .a = 0xFF },
    .scroll_base = .{ .r = 0x2B, .g = 0x2B, .b = 0x2B, .a = 0xFF },
    .scroll_thumb = .{ .r = 0x1E, .g = 0x1E, .b = 0x1E, .a = 0xFF },
}),
