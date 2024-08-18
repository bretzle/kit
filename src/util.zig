const std = @import("std");

pub fn isValidContext(comptime ctx: type) void {
    _ = ctx;
}

pub fn isValidColor(comptime color: type) void {
    _ = color;
}

pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub fn colorMask(comptime Col: type, comptime field: []const u8) u32 {
    if (!@hasField(Col, field)) return 0;

    const dummy: Col = undefined;

    const offset = @bitOffsetOf(Col, field); // 0
    const size = @bitSizeOf(@TypeOf(@field(dummy, field))); // 8

    const mask = std.math.maxInt(std.meta.Int(.unsigned, size));
    return mask << offset;
}
