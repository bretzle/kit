pub const Vec2 = @Vector(2, i32);

pub const Rect = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,

    pub fn overlaps(r: Rect, p: Vec2) bool {
        return p[0] >= r.x and p[0] < r.x + r.w and p[1] >= r.y and p[1] < r.y + r.h;
    }

    pub fn expand(r: Rect, n: i32) Rect {
        return .{
            .x = r.x - n,
            .y = r.y - n,
            .w = r.w + n * 2,
            .h = r.h + n * 2,
        };
    }

    pub fn intersect(r1: Rect, r2: Rect) Rect {
        const x1 = @max(r1.x, r2.x);
        const y1 = @max(r1.y, r2.y);
        var x2 = @min(r1.x + r1.w, r2.x + r2.w);
        var y2 = @min(r1.y + r1.h, r2.y + r2.h);
        if (x2 < x1) x2 = x1;
        if (y2 < y1) y2 = y1;
        return .{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }
};

pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};
