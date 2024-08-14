const std = @import("std");
const os = @import("os.zig");

pub const Config = struct {
    title: [:0]const u8 = "",
    width: comptime_int = 400,
    height: comptime_int = 400,
    scale: comptime_int = 1,
    fps: comptime_float = 60,

    context: type,
    color: type,
};

// pub const Event = union(enum) {
//     key: struct { key: u8, state: enum { pressed, released } },
// };

pub const KeyState = enum { pressed, released };

pub const Events = struct {
    keys: [256]KeyState = [_]KeyState{.released} ** 256,
};

pub fn Screen(comptime config: Config) type {
    const class = @typeName(config.context);

    const Context = config.context;
    const Color = config.color;

    const Bitmap = [config.width * config.height]Color;

    const bmi = os.BITMAPV5HEADER{
        .bV5Width = config.width,
        .bV5Height = -config.height,
        .bV5Planes = 1,
        .bV5BitCount = @bitSizeOf(Color),
        .bV5Compression = 3,
        .bV5RedMask = colorMask(Color, "r"),
        .bV5GreenMask = colorMask(Color, "g"),
        .bV5BlueMask = colorMask(Color, "b"),
        .bV5AlphaMask = colorMask(Color, "a"),
    };

    return struct {
        const Self = @This();
        var singleton: Self = undefined;

        user_data: Context,
        canvas: Bitmap = std.mem.zeroes(Bitmap),

        width: u32,
        height: u32,

        hwnd: os.HWND,
        hdc: os.HDC,
        timer: std.time.Timer,
        step_time: f64 = 0,
        want_quit: bool = false,
        frame: usize = 0,

        events: Events = .{},

        pub fn start() !void {
            const hinstance = os.GetModuleHandleA(null) orelse unreachable;
            const icon = os.LoadIconA(hinstance, @ptrFromInt(101));

            _ = os.RegisterClassExA(&.{
                .style = os.CS_HREDRAW | os.CS_VREDRAW | os.CS_OWNDC,
                .lpfnWndProc = wndproc,
                .hInstance = hinstance,
                .hIcon = icon,
                .hCursor = os.LoadCursorA(null, os.IDC_ARROW),
                .hbrBackground = null,
                .lpszMenuName = null,
                .lpszClassName = class,
                .hIconSm = null,
            });

            const dwStyle = os.WS_OVERLAPPEDWINDOW;
            var rc = os.RECT{ .right = config.width * config.scale, .bottom = config.height * config.scale };
            _ = os.AdjustWindowRectEx(&rc, dwStyle, 0, 0);

            const hwnd = os.CreateWindowExA(
                0,
                class,
                config.title,
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

            _ = os.SetWindowLongPtrA(hwnd, os.GWLP_USERDATA, @ptrCast(&singleton));
            var value: i32 = 1;
            _ = os.DwmSetWindowAttribute(hwnd, os.DWMWA_USE_IMMERSIVE_DARK_MODE, &value, @sizeOf(i32));
            value = 3;
            _ = os.DwmSetWindowAttribute(hwnd, os.DWMWA_WINDOW_CORNER_PREFERENCE, &value, @sizeOf(i32));

            singleton = .{
                .width = config.width * config.scale,
                .height = config.height * config.scale,
                .user_data = try Context.create(),

                .hwnd = hwnd,
                .hdc = hdc,
                .step_time = (if (config.fps != 0) 1.0 / config.fps else 0) * std.time.ns_per_s,
                .timer = try std.time.Timer.start(),
            };

            _ = os.ShowWindow(hwnd, os.SW_NORMAL);

            while (singleton.step()) {
                singleton.user_data.update(&singleton.events);
                singleton.user_data.render(&singleton.canvas);
            }

            singleton.destroy();
        }

        fn step(self: *Self) bool {
            _ = os.RedrawWindow(self.hwnd, null, null, os.RDW_INVALIDATE | os.RDW_UPDATENOW);
            self.frame += 1;

            const now: f64 = @floatFromInt(self.timer.lap());
            const wait: f64 = self.step_time - now;
            if (wait > 0) {
                std.time.sleep(@intFromFloat(wait));
            }

            var msg: os.MSG = undefined;
            while (os.PeekMessageA(&msg, self.hwnd, 0, 0, os.PM_REMOVE) != 0) {
                _ = os.TranslateMessage(&msg);
                _ = os.DispatchMessageA(&msg);
            }

            return !self.want_quit;
        }

        fn destroy(self: *Self) void {
            _ = os.ReleaseDC(self.hwnd, self.hdc);
            _ = os.DestroyWindow(self.hwnd);
            self.user_data.destroy();
        }

        fn getAdjustedWindowRect(self: *const Self) [4]i32 {
            const screen_w: f32 = @floatFromInt(config.width);
            const screen_h: f32 = @floatFromInt(config.height);

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

        fn wndproc(hwnd: os.HWND, uMsg: os.UINT, wParam: os.WPARAM, lParam: os.LPARAM) callconv(os.WINAPI) os.LRESULT {
            const ptr = os.GetWindowLongPtrA(hwnd, os.GWLP_USERDATA) orelse return os.DefWindowProcA(hwnd, uMsg, wParam, lParam);
            const self: *Self = @ptrCast(@alignCast(ptr));

            switch (uMsg) {
                os.WM_CREATE => {
                    _ = os.BufferedPaintInit();
                },
                os.WM_QUIT, os.WM_CLOSE => self.want_quit = true,
                os.WM_PAINT => {
                    var rc: os.RECT = undefined;
                    _ = os.GetClientRect(hwnd, &rc);

                    var hdc: os.HDC = undefined;
                    const paint = os.BeginBufferedPaint(self.hdc, &rc, .BPBF_COMPATIBLEBITMAP, null, &hdc) orelse unreachable;

                    const size = self.getAdjustedWindowRect();
                    _ = os.StretchDIBits(
                        hdc,
                        size[0],
                        size[1],
                        size[2],
                        size[3],
                        0,
                        0,
                        config.width,
                        config.height,
                        @ptrCast(&self.canvas),
                        @ptrCast(&bmi),
                        os.DIB_RGB_COLORS,
                        os.SRCCOPY,
                    );

                    {
                        var buf = [_]u8{0} ** 32;
                        const text = std.fmt.bufPrint(&buf, "frame: {d}", .{self.frame}) catch unreachable;

                        _ = os.SetBkMode(hdc, os.TRANSPARENT);
                        _ = os.SetTextColor(hdc, os.RGB(255, 255, 255));
                        _ = os.ExtTextOutA(hdc, 10, 10, 0, null, @ptrCast(text), @truncate(text.len), null);
                    }

                    _ = os.EndBufferedPaint(paint, 1);
                },
                os.WM_SIZE => if (wParam != os.SIZE_MINIMIZED) {
                    self.width = os.LOWORD(lParam);
                    self.height = os.HIWORD(lParam);

                    var ps: os.PAINTSTRUCT = undefined;
                    const hdc = os.BeginPaint(hwnd, &ps);
                    const hbrush = os.CreateSolidBrush(0);
                    _ = os.FillRect(hdc, &ps.rcPaint, hbrush);
                    _ = os.DeleteObject(hbrush);
                    _ = os.EndPaint(hwnd, &ps);
                    _ = os.RedrawWindow(self.hwnd, null, null, os.RDW_INVALIDATE | os.RDW_UPDATENOW);
                },
                os.WM_KEYDOWN, os.WM_SYSKEYDOWN => {
                    if (lParam & (1 << 30) == 0) {
                        self.events.keys[wParam] = .pressed;
                    }
                },
                os.WM_KEYUP, os.WM_SYSKEYUP => {
                    self.events.keys[wParam] = .released;
                },
                else => {},
            }

            return os.DefWindowProcA(hwnd, uMsg, wParam, lParam);
        }
    };
}

fn colorMask(comptime Color: type, comptime field: []const u8) u32 {
    std.debug.assert(@inComptime());
    if (!@hasField(Color, field)) return 0;

    const dummy: Color = undefined;

    const offset = @bitOffsetOf(Color, field); // 0
    const size = @bitSizeOf(@TypeOf(@field(dummy, field))); // 8

    const mask = std.math.maxInt(std.meta.Int(.unsigned, size));
    return mask << offset;
}
