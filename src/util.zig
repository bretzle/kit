const std = @import("std");

pub fn colorMask(comptime Col: type, comptime field: []const u8) u32 {
    compileAssert(@hasField(Col, field), "Col must have field: {s}", .{field});

    const offset = @bitOffsetOf(Col, field); // 0
    const size = @bitSizeOf(@TypeOf(@field(@as(Col, undefined), field))); // 8

    const mask = (1 << size) - 1;
    return mask << offset;
}

pub inline fn compileError(comptime format: []const u8, comptime args: anytype) void {
    @compileError(std.fmt.comptimePrint(format, args));
}

pub inline fn compileAssert(comptime ok: bool, comptime format: []const u8, comptime args: anytype) void {
    if (!ok) compileError(format, args);
}
