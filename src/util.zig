const std = @import("std");

pub fn isValidContext(comptime ctx: type) void {
    _ = ctx;
}

pub fn isValidColor(comptime color: type) void {
    _ = color;
}

pub fn colorMask(comptime Color: type, comptime field: []const u8) u32 {
    if (!@hasField(Color, field)) return 0;

    const dummy: Color = undefined;

    const offset = @bitOffsetOf(Color, field); // 0
    const size = @bitSizeOf(@TypeOf(@field(dummy, field))); // 8

    const mask = std.math.maxInt(std.meta.Int(.unsigned, size));
    return mask << offset;
}
