const std = @import("std");
const os = @import("os.zig");
const util = @import("util.zig");
const mui = @import("mui.zig");
const assert = std.debug.assert;

pub const RGBA = util.Color;
pub const Gui = mui.Context;
pub const png = @import("png.zig");
pub const math = @import("math.zig");

pub const AppOptions = struct {
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

    const Color = if (@hasDecl(UserContext, "color")) UserContext.color else util.Color;

    return struct {
        const Self = @This();

        pub fn start(allocator: std.mem.Allocator, options: AppOptions) !void {
            const context = if (create_alloc) try UserContext.create(allocator) else UserContext.create();
            defer if (create_alloc) context.destroy();

            const win_options = WindowOptions{
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

            const window = try Window.create(allocator, win_options);
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

pub const WindowOptions = struct {
    title: [:0]const u8,
    width: i32,
    height: i32,
    framebuffer: struct {
        width: u32,
        height: u32,
        pixel_size: u32,
        pixel_masks: [4]u32,
    },
    dark_mode: bool,
};

pub const Window = struct {
    const Self = @This();
    const class = "kit-class-name";

    width: i32,
    height: i32,
    framebuffer: struct {
        width: u32,
        height: u32,
        data: []u8,
    },
    want_quit: bool = false,

    keys: [256]enum { down, up } = .{.up} ** 256,
    mod: packed struct { ctrl: bool = false, shift: bool = false, alt: bool = false, meta: bool = false } = .{},

    bmi: os.BITMAPV5HEADER,
    hdc: os.HDC,
    hwnd: os.HWND,

    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator, options: WindowOptions) !*Self {
        const self = try allocator.create(Self);
        const framebuffer = try allocator.alloc(u8, options.framebuffer.width * options.framebuffer.height * options.framebuffer.pixel_size);

        const hinstance = os.GetModuleHandleA(null) orelse unreachable;
        const hicon = os.LoadIconA(hinstance, @ptrFromInt(101));
        const hcursor = os.LoadCursorA(null, os.IDC_ARROW);

        _ = os.RegisterClassExA(&.{
            .style = os.CS_HREDRAW | os.CS_VREDRAW | os.CS_OWNDC,
            .lpfnWndProc = wndproc,
            .hInstance = hinstance,
            .hIcon = hicon,
            .hCursor = hcursor,
            .hbrBackground = null,
            .lpszMenuName = null,
            .lpszClassName = class,
            .hIconSm = null,
        });

        const dwStyle = os.WS_OVERLAPPEDWINDOW;
        var rc = os.RECT{ .right = options.width, .bottom = options.height };
        _ = os.AdjustWindowRectEx(&rc, dwStyle, 0, 0);

        const hwnd = os.CreateWindowExA(
            0,
            class,
            options.title,
            dwStyle,
            os.CW_USEDEFAULT,
            os.CW_USEDEFAULT,
            rc.right - rc.left,
            rc.bottom - rc.top,
            null,
            null,
            hinstance,
            null,
        ) orelse unreachable;

        const hdc = os.GetDC(hwnd) orelse unreachable;

        const bmi = os.BITMAPV5HEADER{
            .bV5Width = @intCast(options.framebuffer.width),
            .bV5Height = -@as(i32, @intCast(options.framebuffer.height)),
            .bV5Planes = 1,
            .bV5BitCount = @intCast(options.framebuffer.pixel_size * 8),
            .bV5Compression = 3,
            .bV5RedMask = options.framebuffer.pixel_masks[0],
            .bV5GreenMask = options.framebuffer.pixel_masks[1],
            .bV5BlueMask = options.framebuffer.pixel_masks[2],
            .bV5AlphaMask = options.framebuffer.pixel_masks[3],
        };

        self.* = .{
            .width = options.width,
            .height = options.height,
            .framebuffer = .{
                .width = options.framebuffer.width,
                .height = options.framebuffer.height,
                .data = framebuffer,
            },

            .bmi = bmi,
            .hdc = hdc,
            .hwnd = hwnd,

            .allocator = allocator,
        };

        if (options.dark_mode) {
            _ = os.DwmSetWindowAttribute(hwnd, os.DWMWA_USE_IMMERSIVE_DARK_MODE, &@as(i32, 1), @sizeOf(i32));
            _ = os.DwmSetWindowAttribute(hwnd, os.DWMWA_WINDOW_CORNER_PREFERENCE, &@as(i32, 3), @sizeOf(i32));
        }

        _ = os.SetWindowLongPtrA(self.hwnd, os.GWLP_USERDATA, @ptrCast(self));
        _ = os.ShowWindow(self.hwnd, os.SW_NORMAL);
        _ = os.UpdateWindow(self.hwnd);

        return self;
    }

    pub fn destroy(self: *Self) void {
        self.allocator.free(self.framebuffer.data);
        self.allocator.destroy(self);
    }

    pub fn step(self: *Self) bool {
        var msg: os.MSG = undefined;
        while (os.PeekMessageA(&msg, null, 0, 0, os.PM_REMOVE) != 0) {
            _ = os.TranslateMessage(&msg);
            _ = os.DispatchMessageA(&msg);
        }
        _ = os.InvalidateRect(self.hwnd, null, 1);

        return !self.want_quit;
    }

    fn getAdjustedWindowRect(self: *const Self) [4]i32 {
        const screen_w: f32 = @floatFromInt(self.framebuffer.width);
        const screen_h: f32 = @floatFromInt(self.framebuffer.height);

        const win_w: f32 = @floatFromInt(self.width);
        const win_h: f32 = @floatFromInt(self.height);

        // work out maximum size to retain aspect ratio
        const src_ar: f32 = screen_h / screen_w;
        const dst_ar: f32 = win_h / win_w;

        const w = if (src_ar < dst_ar) win_w else @ceil(win_h / src_ar);
        const h = if (src_ar < dst_ar) @ceil(win_w * src_ar) else win_h;

        // return centered rect
        return [4]i32{
            @intFromFloat((win_w - w) / 2),
            @intFromFloat((win_h - h) / 2),
            @intFromFloat(w),
            @intFromFloat(h),
        };
    }

    pub fn changeColor(self: *Self, comptime Color: type) !void {
        self.bmi.bV5BitCount = @bitSizeOf(Color);
        self.bmi.bV5RedMask = util.colorMask(Color, "r");
        self.bmi.bV5GreenMask = util.colorMask(Color, "g");
        self.bmi.bV5BlueMask = util.colorMask(Color, "b");
        self.bmi.bV5AlphaMask = util.colorMask(Color, "a");

        const old = self.framebuffer.data.len;
        const size = self.framebuffer.width * self.framebuffer.height * @sizeOf(Color);
        if (size != old) {
            self.framebuffer.data = try self.allocator.realloc(self.framebuffer.data, size);
        }
    }

    pub fn resizeFramebuffer(self: *Self, width: u32, height: u32) !void {
        self.bmi.bV5Width = @intCast(width);
        self.bmi.bV5Height = -@as(i32, @intCast(height));
        self.framebuffer.width = width;
        self.framebuffer.height = height;

        const size = width * height * (self.bmi.bV5BitCount / 8);
        if (size != self.framebuffer.data.len) {
            self.framebuffer.data = try self.allocator.realloc(self.framebuffer.data, size);
        }
    }
};

fn wndproc(hwnd: os.HWND, uMsg: os.UINT, wParam: os.WPARAM, lParam: os.LPARAM) callconv(os.WINAPI) os.LRESULT {
    const keycodes = [_]u8{ 0, 27, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 8, 9, 81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 91, 93, 10, 0, 65, 83, 68, 70, 71, 72, 74, 75, 76, 59, 39, 96, 0, 92, 90, 88, 67, 86, 66, 78, 77, 44, 46, 47, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 17, 3, 0, 20, 0, 19, 0, 5, 18, 4, 26, 127 };
    const ptr = os.GetWindowLongPtrA(hwnd, os.GWLP_USERDATA) orelse return os.DefWindowProcA(hwnd, uMsg, wParam, lParam);
    const self: *Window = @ptrCast(@alignCast(ptr));

    switch (uMsg) {
        os.WM_CREATE => _ = os.BufferedPaintInit(),
        os.WM_QUIT, os.WM_CLOSE => self.want_quit = true,
        os.WM_PAINT => {
            var rc: os.RECT = undefined;
            _ = os.GetClientRect(hwnd, &rc);

            var hdc: os.HDC = undefined;
            const paint = os.BeginBufferedPaint(self.hdc, &rc, .BPBF_COMPATIBLEBITMAP, null, &hdc) orelse return 0;
            defer _ = os.EndBufferedPaint(paint, 1);

            const size = self.getAdjustedWindowRect();
            _ = os.StretchDIBits(
                hdc,
                size[0],
                size[1],
                size[2],
                size[3],
                0,
                0,
                @intCast(self.framebuffer.width),
                @intCast(self.framebuffer.height),
                @ptrCast(self.framebuffer.data),
                @ptrCast(&self.bmi),
                os.DIB_RGB_COLORS,
                os.SRCCOPY,
            );
        },
        os.WM_SIZE => if (wParam != os.SIZE_MINIMIZED) {
            self.width = os.LOWORD(lParam);
            self.height = os.HIWORD(lParam);
            _ = os.RedrawWindow(self.hwnd, null, null, os.RDW_INVALIDATE | os.RDW_UPDATENOW);
        },
        os.WM_KEYDOWN, os.WM_KEYUP => {
            self.keys[keycodes[os.HIWORD(lParam) & 0x1FF]] = @enumFromInt(lParam >> 31 & 1);
            self.mod = .{
                .ctrl = os.GetKeyState(0x11) & 0x8000 != 0,
                .shift = os.GetKeyState(0x10) & 0x8000 != 0,
                .alt = os.GetKeyState(0x12) & 0x8000 != 0,
                .meta = (os.GetKeyState(0x5B) | os.GetKeyState(0x5C)) & 0x8000 != 0,
            };
        },
        else => {},
    }

    return os.DefWindowProcA(hwnd, uMsg, wParam, lParam);
}
