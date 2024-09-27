const std = @import("std");

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

pub inline fn compileError(
    comptime format: []const u8,
    comptime args: anytype,
) void {
    @compileError(std.fmt.comptimePrint(format, args));
}

pub inline fn compileAssert(
    comptime ok: bool,
    comptime format: []const u8,
    comptime args: anytype,
) void {
    if (!ok) compileError(format, args);
}

pub fn Pool(comptime T: type, comptime Id: type, comptime size: comptime_int) type {
    return struct {
        const Self = @This();

        pub const Item = struct {
            data: T,
            id: Id = .invalid,
            generation: ?u32 = null,
        };

        buffer: [size]Item = undefined,

        pub fn init(self: *Self, generation: u32, id: Id) *T {
            var slot: ?u32 = null;
            var f = generation;
            for (0..size) |i| {
                if (self.buffer[i].generation) |last| {
                    if (last < f) {
                        f = last;
                        slot = @truncate(i);
                    }
                } else {
                    slot = @truncate(i);
                    break;
                }
            }

            const idx = slot orelse unreachable;
            self.buffer[idx] = .{ .data = undefined, .id = id, .generation = generation };
            return &self.buffer[idx].data;
        }

        pub fn get(self: *Self, id: Id) ?*Item {
            for (0..size) |i| {
                if (self.buffer[i].id == id) return &self.buffer[i];
            }
            return null;
        }
    };
}
