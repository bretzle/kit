pub const Vec2 = @Vector(2, i32);

pub inline fn add(v: anytype, n: i32) @TypeOf(v) {
    return v + @as(@TypeOf(v), @splat(n));
}

pub inline fn sub(v: anytype, n: i32) @TypeOf(v) {
    return v - @as(@TypeOf(v), @splat(n));
}

pub const Rect = struct {
    pos: Vec2 = .{ 0, 0 },
    size: Vec2 = .{ 0, 0 },

    pub inline fn left(self: *const Rect) i32 {
        return self.pos[0];
    }

    pub inline fn top(self: *const Rect) i32 {
        return self.pos[1];
    }

    pub inline fn right(self: *const Rect) i32 {
        return self.pos[0] + self.size[0];
    }

    pub inline fn bottom(self: *const Rect) i32 {
        return self.pos[1] + self.size[1];
    }

    pub fn overlaps(r: Rect, p: Vec2) bool {
        return p[0] >= r.left() and p[0] < r.right() and p[1] >= r.top() and p[1] < r.bottom();
    }

    pub fn expand(r: Rect, n: i32) Rect {
        return .{
            .pos = sub(r.pos, n),
            .size = add(r.size, n * 2),
        };
    }

    pub fn intersect(r1: Rect, r2: Rect) Rect {
        const pos1 = @max(r1.pos, r2.pos);
        var pos2 = @min(r1.pos + r1.size, r2.pos + r2.size);
        if (pos2[0] < pos1[0]) pos2[0] = pos1[0];
        if (pos2[1] < pos1[1]) pos2[1] = pos1[1];

        return .{
            .pos = pos1,
            .size = pos2 - pos1,
        };
    }
};

pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};
