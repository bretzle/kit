const std = @import("std");
const util = @import("util.zig");
const os = @import("os.zig");
const mui = @import("mui.zig");

pub const RGBA = util.Color;
pub const Gui = mui.Context;
pub const png = @import("png.zig");

pub const Config = struct {
    context: type,
    color: type,
    width: comptime_int,
    height: comptime_int,
    enable_gui: bool = false,
};

pub const WindowOptions = struct {
    title: [:0]const u8 = "",
    scale: i32 = 1,
    fps: f64 = 60.0,
};

pub fn App(comptime config: Config) type {
    comptime util.isValidContext(config.context);
    comptime util.isValidColor(config.color);

    return struct {
        const Self = @This();

        const Window = Device(config);

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};

        pub fn start(options: WindowOptions) !void {
            const allocator = gpa.allocator();

            var context = try config.context.create();
            defer context.destroy();

            const window = try Window.create(allocator, options);
            defer window.destroy();

            while (window.step()) {
                context.update(&window.gui);
                context.render(window.canvas);
            }
        }
    };
}

fn Device(comptime config: Config) type {
    return struct {
        const Self = @This();

        const Context = config.context;
        const Color = config.color;

        const bmi = os.BITMAPV5HEADER{
            .bV5Width = config.width,
            .bV5Height = -config.height,
            .bV5Planes = 1,
            .bV5BitCount = @bitSizeOf(Color),
            .bV5Compression = 3,
            .bV5RedMask = util.colorMask(Color, "r"),
            .bV5GreenMask = util.colorMask(Color, "g"),
            .bV5BlueMask = util.colorMask(Color, "b"),
            .bV5AlphaMask = util.colorMask(Color, "a"),
        };

        var textHDC: os.HDC = undefined;

        canvas: []config.color,
        gui: if (config.enable_gui) mui.Context else void,

        width: u32,
        height: u32,

        hwnd: os.HWND,
        hdc: os.HDC,
        hfont: os.HFONT,
        timer: std.time.Timer,
        step_time: f64,
        want_quit: bool = false,
        allocator: std.mem.Allocator,

        fn create(allocator: std.mem.Allocator, options: WindowOptions) !*Self {
            const self = try allocator.create(Self);
            const canvas = try allocator.alloc(Color, config.width * config.height);

            const class = @typeName(Context);
            const hinstance = os.GetModuleHandleA(null) orelse unreachable;
            const icon = os.LoadIconA(hinstance, @ptrFromInt(101));

            const hfont = os.CreateFontA(
                16,
                0,
                0,
                0,
                400,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                "Arial",
            ) orelse unreachable;

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
            var rc = os.RECT{ .right = config.width * options.scale, .bottom = config.height * options.scale };
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

            _ = os.DwmSetWindowAttribute(hwnd, os.DWMWA_USE_IMMERSIVE_DARK_MODE, &@as(i32, 1), @sizeOf(i32));
            _ = os.DwmSetWindowAttribute(hwnd, os.DWMWA_WINDOW_CORNER_PREFERENCE, &@as(i32, 3), @sizeOf(i32));

            const hdc = os.GetDC(hwnd) orelse unreachable;
            _ = os.SelectObject(hdc, hfont);
            textHDC = hdc;

            self.* = .{
                .canvas = canvas,
                .width = @intCast(config.width * options.scale),
                .height = @intCast(config.height * options.scale),
                .hwnd = hwnd,
                .hdc = hdc,
                .hfont = hfont,
                .timer = try std.time.Timer.start(),
                .step_time = (if (options.fps != 0) 1.0 / options.fps else 0) * std.time.ns_per_s,
                .gui = if (config.enable_gui) mui.Context.create(allocator, textHeight, textWidth) else {},
                .allocator = allocator,
            };

            _ = os.SetWindowLongPtrA(hwnd, os.GWLP_USERDATA, @ptrCast(self));
            _ = os.ShowWindow(self.hwnd, os.SW_NORMAL);

            return self;
        }

        pub fn destroy(self: *Self) void {
            if (config.enable_gui) self.gui.destroy();
            self.allocator.free(self.canvas);
            self.allocator.destroy(self);
        }

        fn step(self: *Self) bool {
            _ = os.RedrawWindow(self.hwnd, null, null, os.RDW_INVALIDATE | os.RDW_UPDATENOW);

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

        fn drawCanvas(self: *const Self, hdc: os.HDC) void {
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
                @ptrCast(self.canvas),
                @ptrCast(&bmi),
                os.DIB_RGB_COLORS,
                os.SRCCOPY,
            );
        }

        fn drawGUI(self: *Self, hdc: os.HDC) void {
            for (self.gui.root_list.items) |cnt| {
                for (self.gui.command_list.items[cnt.head_idx..cnt.tail_idx]) |cmd| {
                    switch (cmd) {
                        .clip => |data| {
                            _ = os.SelectClipRgn(hdc, null);
                            _ = os.IntersectClipRect(hdc, data.rect.x, data.rect.y, data.rect.x + data.rect.w, data.rect.y + data.rect.h);
                        },
                        .rect => |data| {
                            const rc = data.rect.windows();
                            const hbr = os.CreateSolidBrush(data.color.windows());
                            _ = os.FillRect(hdc, &rc, hbr);
                            _ = os.DeleteObject(hbr);
                        },
                        .text => |data| drawText(hdc, data.color.windows(), data.str, data.pos[0], data.pos[1]),
                        .icon => |data| {
                            const text = switch (data.id) {
                                .check => "X",
                                .close => "x",
                                .collapsed => ">",
                                .expanded => "v",
                            };
                            const size = textSize(text);
                            const x = data.rect.x + @divFloor(data.rect.w - size.cx, 2);
                            const y = data.rect.y + @divFloor(data.rect.h - size.cy, 2);

                            drawText(hdc, data.color.windows(), text, x, y);
                        },
                    }
                }
            }
        }

        var textScratch: [256]u16 = undefined;
        inline fn drawText(hdc: os.HDC, color: u32, text: []const u8, x: i32, y: i32) void {
            _ = os.SetBkMode(hdc, os.TRANSPARENT);
            _ = os.SetTextColor(hdc, color);

            const len = std.unicode.utf8ToUtf16Le(&textScratch, text) catch unreachable;

            _ = os.ExtTextOutW(hdc, x, y, os.ETO_OPAQUE, null, @ptrCast(&textScratch), @truncate(len), null);
        }

        fn wndproc(hwnd: os.HWND, uMsg: os.UINT, wParam: os.WPARAM, lParam: os.LPARAM) callconv(os.WINAPI) os.LRESULT {
            const ptr = os.GetWindowLongPtrA(hwnd, os.GWLP_USERDATA) orelse return os.DefWindowProcA(hwnd, uMsg, wParam, lParam);
            const self: *Self = @ptrCast(@alignCast(ptr));

            switch (uMsg) {
                os.WM_CREATE => _ = os.BufferedPaintInit(),
                os.WM_QUIT, os.WM_CLOSE => self.want_quit = true,
                os.WM_PAINT => {
                    var rc: os.RECT = undefined;
                    _ = os.GetClientRect(hwnd, &rc);

                    var hdc: os.HDC = undefined;
                    const paint = os.BeginBufferedPaint(self.hdc, &rc, .BPBF_COMPATIBLEBITMAP, null, &hdc) orelse return 0;
                    defer _ = os.EndBufferedPaint(paint, 1);
                    _ = os.SelectObject(hdc, self.hfont);

                    self.drawCanvas(hdc);
                    if (config.enable_gui) self.drawGUI(hdc);
                },
                os.WM_SIZE => if (wParam != os.SIZE_MINIMIZED) {
                    self.width = os.LOWORD(lParam);
                    self.height = os.HIWORD(lParam);
                    _ = os.RedrawWindow(self.hwnd, null, null, os.RDW_INVALIDATE | os.RDW_UPDATENOW);
                },
                os.WM_MOUSEMOVE => if (config.enable_gui) self.gui.mu_input_mousemove(os.GET_X_LPARAM(lParam), os.GET_Y_LPARAM(lParam)),
                os.WM_LBUTTONUP => if (config.enable_gui) self.gui.mu_input_mouseup(os.GET_X_LPARAM(lParam), os.GET_Y_LPARAM(lParam), .left),
                os.WM_LBUTTONDOWN => if (config.enable_gui) self.gui.mu_input_mousedown(os.GET_X_LPARAM(lParam), os.GET_Y_LPARAM(lParam), .left),
                os.WM_RBUTTONUP => if (config.enable_gui) self.gui.mu_input_mouseup(os.GET_X_LPARAM(lParam), os.GET_Y_LPARAM(lParam), .right),
                os.WM_RBUTTONDOWN => if (config.enable_gui) self.gui.mu_input_mousedown(os.GET_X_LPARAM(lParam), os.GET_Y_LPARAM(lParam), .right),
                os.WM_MOUSEWHEEL => if (config.enable_gui) self.gui.mu_input_scroll(0, -@divTrunc(os.GET_WHEEL_DELTA_WPARAM(wParam), 5)),
                else => {},
            }

            return os.DefWindowProcA(hwnd, uMsg, wParam, lParam);
        }

        fn textWidth(text: []const u8) i32 {
            return textSize(text).cx;
        }

        fn textHeight() i32 {
            return textSize("E").cy;
        }

        inline fn textSize(text: []const u8) os.SIZE {
            var size: os.SIZE = undefined;
            _ = os.GetTextExtentPoint32A(textHDC, @ptrCast(text), @intCast(text.len), &size);
            return size;
        }
    };
}
