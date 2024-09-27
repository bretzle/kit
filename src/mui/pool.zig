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
