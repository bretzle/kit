const std = @import("std");
const win = @import("window.zig");
const math = @import("../math.zig");
const util = @import("../util.zig");
const assert = std.debug.assert;

pub const Options = struct {
    title: [:0]const u8 = "",
    window_width: ?u32 = null,
    window_height: ?u32 = null,
    framebuffer_width: u32,
    framebuffer_height: u32,
    scale: u32 = 1,

    dark_mode: bool = true,
};

pub fn App(comptime UserContext: type) type {
    assert(@hasDecl(UserContext, "create"));
    const CreateFn = @TypeOf(UserContext.create);
    const create_alloc = @typeInfo(CreateFn).Fn.params.len != 0;

    assert(CreateFn == fn () UserContext or CreateFn == fn (std.mem.Allocator) anyerror!*UserContext);
    if (create_alloc) {
        assert(@hasDecl(UserContext, "destroy"));
    }

    const Color = if (@hasDecl(UserContext, "color")) UserContext.color else math.Color;

    return struct {
        const Self = @This();

        pub fn start(allocator: std.mem.Allocator, options: Options) !void {
            const context = if (create_alloc) try UserContext.create(allocator) else UserContext.create();
            defer if (create_alloc) context.destroy();

            const win_options = win.Options{
                .title = options.title,
                .width = @intCast(options.window_width orelse options.framebuffer_width * options.scale),
                .height = @intCast(options.window_height orelse options.framebuffer_height * options.scale),
                .framebuffer = .{
                    .width = options.framebuffer_width,
                    .height = options.framebuffer_height,
                    .pixel_size = @sizeOf(Color),
                    .pixel_masks = [4]u32{
                        util.colorMask(Color, "r"),
                        util.colorMask(Color, "g"),
                        util.colorMask(Color, "b"),
                        util.colorMask(Color, "a"),
                    },
                },
                .dark_mode = options.dark_mode,
            };

            const window = try win.Window.create(allocator, win_options);
            defer window.destroy();

            var now = if (@hasDecl(UserContext, "fps")) std.time.milliTimestamp() else {};
            while (window.step()) {
                if (@hasDecl(UserContext, "update")) {
                    try context.update(window);
                }
                if (@hasDecl(UserContext, "render")) {
                    context.render(window.framebuffer.data);
                }

                if (@hasDecl(UserContext, "fps")) {
                    const time = std.time.milliTimestamp();
                    if (time - now < @divTrunc(1000, UserContext.fps)) {
                        std.time.sleep(@intCast((time - now) * std.time.ns_per_ms));
                    }
                    now = time;
                }
            }
        }
    };
}
