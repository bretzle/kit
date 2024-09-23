const std = @import("std");
const util = @import("util.zig");
const os = @import("os.zig");
const mui = @import("mui.zig");

pub const RGBA = util.Color;
pub const Gui = mui.Context;
pub const png = @import("png.zig");
pub const math = @import("math.zig");

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
};

pub const Event = union(enum) {
    key: struct { keycode: KeyCode, state: enum { down, up } },
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

            const CreateFn = @TypeOf(config.context.create);
            const CreateInfo = @typeInfo(CreateFn);

            var context = if (CreateInfo.Fn.params.len == 0)
                config.context.create()
            else
                try config.context.create(allocator);
            defer context.destroy();

            const window = try Window.create(allocator, context, options);
            defer window.destroy();

            while (window.step()) {
                if (config.enable_gui)
                    context.update(&window.gui)
                else
                    context.update();
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
        user_ctx: *Context,

        width: u32,
        height: u32,

        hwnd: os.HWND,
        hdc: os.HDC,
        hfont: os.HFONT,
        want_quit: bool = false,
        allocator: std.mem.Allocator,

        fn create(allocator: std.mem.Allocator, user_ctx: *Context, options: WindowOptions) !*Self {
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
                .gui = if (config.enable_gui) mui.Context.create(allocator, textHeight, textWidth) else {},
                .user_ctx = user_ctx,
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
            _ = os.DwmFlush();

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
            var iter = self.gui.commands();
            while (iter.next()) |cmd| {
                switch (cmd) {
                    .clip => |data| {
                        _ = os.SelectClipRgn(hdc, null);
                        _ = os.IntersectClipRect(hdc, data.rect.left(), data.rect.top(), data.rect.right(), data.rect.bottom());
                    },
                    .rect => |data| {
                        const rc = winrect(data.rect);
                        const hbr = os.CreateSolidBrush(wincolor(data.color));
                        _ = os.FillRect(hdc, &rc, hbr);
                        _ = os.DeleteObject(hbr);
                    },
                    .text => |data| drawText(hdc, wincolor(data.color), data.str, data.pos[0], data.pos[1]),
                    .icon => |data| {
                        const text = switch (data.id) {
                            .check => "X",
                            .close => "x",
                            .collapsed => ">",
                            .expanded => "v",
                        };
                        const size = textSize(text);
                        const x = data.rect.pos[0] + @divFloor(data.rect.size[0] - size.cx, 2);
                        const y = data.rect.pos[1] + @divFloor(data.rect.size[1] - size.cy, 2);

                        drawText(hdc, wincolor(data.color), text, x, y);
                    },
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
                os.WM_MOUSEMOVE => if (config.enable_gui) self.gui.input.mousemove(os.GET_X_LPARAM(lParam), os.GET_Y_LPARAM(lParam)),
                os.WM_LBUTTONUP => if (config.enable_gui) self.gui.input.mouseup(os.GET_X_LPARAM(lParam), os.GET_Y_LPARAM(lParam), .left),
                os.WM_LBUTTONDOWN => if (config.enable_gui) self.gui.input.mousedown(os.GET_X_LPARAM(lParam), os.GET_Y_LPARAM(lParam), .left),
                os.WM_RBUTTONUP => if (config.enable_gui) self.gui.input.mouseup(os.GET_X_LPARAM(lParam), os.GET_Y_LPARAM(lParam), .right),
                os.WM_RBUTTONDOWN => if (config.enable_gui) self.gui.input.mousedown(os.GET_X_LPARAM(lParam), os.GET_Y_LPARAM(lParam), .right),
                os.WM_MOUSEWHEEL => if (config.enable_gui) self.gui.input.scroll(0, -@divTrunc(os.GET_WHEEL_DELTA_WPARAM(wParam), 5)),

                os.WM_KEYDOWN, os.WM_SYSKEYDOWN => if (@hasDecl(Context, "event")) {
                    const keycode = os.HIWORD(lParam) & 0x1FF;
                    self.user_ctx.event(.{ .key = .{ .keycode = @enumFromInt(keycode), .state = .down } });
                },
                os.WM_KEYUP, os.WM_SYSKEYUP => if (@hasDecl(Context, "event")) {
                    const keycode = os.HIWORD(lParam) & 0x1FF;
                    self.user_ctx.event(.{ .key = .{ .keycode = @enumFromInt(keycode), .state = .up } });
                },

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

        inline fn winrect(self: math.Rect) os.RECT {
            return os.RECT{ .left = self.left(), .top = self.top(), .right = self.right(), .bottom = self.bottom() };
        }

        inline fn wincolor(self: math.Color) os.COLORREF {
            return @as(os.COLORREF, @bitCast(self)) & 0x00FF_FFFF;
        }
    };
}

pub const KeyCode = enum(u16) {
    key0 = 0x000B,
    key1 = 0x0002,
    key2 = 0x0003,
    key3 = 0x0004,
    key4 = 0x0005,
    key5 = 0x0006,
    key6 = 0x0007,
    key7 = 0x0008,
    key8 = 0x0009,
    key9 = 0x000A,
    a = 0x001E,
    b = 0x0030,
    c = 0x002E,
    d = 0x0020,
    e = 0x0012,
    f = 0x0021,
    g = 0x0022,
    h = 0x0023,
    i = 0x0017,
    j = 0x0024,
    k = 0x0025,
    l = 0x0026,
    m = 0x0032,
    n = 0x0031,
    o = 0x0018,
    p = 0x0019,
    q = 0x0010,
    r = 0x0013,
    s = 0x001F,
    t = 0x0014,
    u = 0x0016,
    v = 0x002F,
    w = 0x0011,
    x = 0x002D,
    y = 0x0015,
    z = 0x002C,
    apostrophe = 0x0028,
    backslash = 0x002B,
    comma = 0x0033,
    equal = 0x000D,
    graveaccent = 0x0029,
    leftbracket = 0x001A,
    minus = 0x000C,
    period = 0x0034,
    rightbracket = 0x001B,
    semicolon = 0x0027,
    slash = 0x0035,
    world2 = 0x0056,
    backspace = 0x000E,
    delete = 0x0153,
    end = 0x014F,
    enter = 0x001C,
    escape = 0x0001,
    home = 0x0147,
    insert = 0x0152,
    menu = 0x015D,
    pagedown = 0x0151,
    pageup = 0x0149,
    pause = 0x0045,
    space = 0x0039,
    tab = 0x000F,
    capslock = 0x003A,
    numlock = 0x0145,
    scrolllock = 0x0046,
    f1 = 0x003B,
    f2 = 0x003C,
    f3 = 0x003D,
    f4 = 0x003E,
    f5 = 0x003F,
    f6 = 0x0040,
    f7 = 0x0041,
    f8 = 0x0042,
    f9 = 0x0043,
    f10 = 0x0044,
    f11 = 0x0057,
    f12 = 0x0058,
    f13 = 0x0064,
    f14 = 0x0065,
    f15 = 0x0066,
    f16 = 0x0067,
    f17 = 0x0068,
    f18 = 0x0069,
    f19 = 0x006A,
    f20 = 0x006B,
    f21 = 0x006C,
    f22 = 0x006D,
    f23 = 0x006E,
    f24 = 0x0076,
    leftalt = 0x0038,
    leftcontrol = 0x001D,
    leftshift = 0x002A,
    leftsuper = 0x015B,
    printscreen = 0x0137,
    rightalt = 0x0138,
    rightcontrol = 0x011D,
    rightshift = 0x0036,
    rightsuper = 0x015C,
    down = 0x0150,
    left = 0x014B,
    right = 0x014D,
    up = 0x0148,
    kp0 = 0x0052,
    kp1 = 0x004F,
    kp2 = 0x0050,
    kp3 = 0x0051,
    kp4 = 0x004B,
    kp5 = 0x004C,
    kp6 = 0x004D,
    kp7 = 0x0047,
    kp8 = 0x0048,
    kp9 = 0x0049,
    kpadd = 0x004E,
    kpdecimal = 0x0053,
    kpdivide = 0x0135,
    kpenter = 0x011C,
    kpmultiply = 0x0037,
    kpsubtract = 0x004A,
    _,
};
