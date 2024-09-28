const std = @import("std");
const os = @import("os.zig");
const win = @import("../window.zig");
const util = @import("../../util.zig");

const class = "kit-class-name";
const keycodes = [_]u8{ 0, 27, 49, 50, 51, 52, 53, 54, 55, 56, 57, 48, 45, 61, 8, 9, 81, 87, 69, 82, 84, 89, 85, 73, 79, 80, 91, 93, 10, 0, 65, 83, 68, 70, 71, 72, 74, 75, 76, 59, 39, 96, 0, 92, 90, 88, 67, 86, 66, 78, 77, 44, 46, 47, 0, 0, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 17, 3, 0, 20, 0, 19, 0, 5, 18, 4, 26, 127 };

pub const Extra = struct {
    bmi: os.BITMAPV5HEADER,
    hdc: os.HDC,
    hwnd: os.HWND,
};

pub fn create(self: *win.Window, options: win.Options) !void {
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

    self.extra = .{
        .bmi = bmi,
        .hdc = hdc,
        .hwnd = hwnd,
    };

    if (options.dark_mode) {
        _ = os.DwmSetWindowAttribute(hwnd, os.DWMWA_USE_IMMERSIVE_DARK_MODE, &@as(i32, 1), @sizeOf(i32));
        _ = os.DwmSetWindowAttribute(hwnd, os.DWMWA_WINDOW_CORNER_PREFERENCE, &@as(i32, 3), @sizeOf(i32));
    }

    _ = os.SetWindowLongPtrA(self.extra.hwnd, os.GWLP_USERDATA, @ptrCast(self));
    _ = os.ShowWindow(self.extra.hwnd, os.SW_NORMAL);
    _ = os.UpdateWindow(self.extra.hwnd);
}

pub fn destroy(_: *win.Window) void {}

pub fn step(self: *win.Window) void {
    var msg: os.MSG = undefined;
    while (os.PeekMessageA(&msg, null, 0, 0, os.PM_REMOVE) != 0) {
        _ = os.TranslateMessage(&msg);
        _ = os.DispatchMessageA(&msg);
    }
    _ = os.InvalidateRect(self.extra.hwnd, null, 1);
}

pub fn changeColor(self: *win.Window, comptime Color: type) !void {
    self.extra.bmi.bV5BitCount = @bitSizeOf(Color);
    self.extra.bmi.bV5RedMask = util.colorMask(Color, "r");
    self.extra.bmi.bV5GreenMask = util.colorMask(Color, "g");
    self.extra.bmi.bV5BlueMask = util.colorMask(Color, "b");
    self.extra.bmi.bV5AlphaMask = util.colorMask(Color, "a");
}

pub fn resizeFramebuffer(self: *win.Window, width: u32, height: u32) !u32 {
    self.extra.bmi.bV5Width = @intCast(width);
    self.extra.bmi.bV5Height = -@as(i32, @intCast(height));
    return width * height * (self.extra.bmi.bV5BitCount / 8);
}

fn wndproc(hwnd: os.HWND, uMsg: os.UINT, wParam: os.WPARAM, lParam: os.LPARAM) callconv(os.WINAPI) os.LRESULT {
    const ptr = os.GetWindowLongPtrA(hwnd, os.GWLP_USERDATA) orelse return os.DefWindowProcA(hwnd, uMsg, wParam, lParam);
    const self: *win.Window = @ptrCast(@alignCast(ptr));

    switch (uMsg) {
        os.WM_CREATE => _ = os.BufferedPaintInit(),
        os.WM_QUIT, os.WM_CLOSE => self.want_quit = true,
        os.WM_PAINT => {
            var rc: os.RECT = undefined;
            _ = os.GetClientRect(hwnd, &rc);

            var hdc: os.HDC = undefined;
            const paint = os.BeginBufferedPaint(self.extra.hdc, &rc, .BPBF_COMPATIBLEBITMAP, null, &hdc) orelse return 0;
            defer _ = os.EndBufferedPaint(paint, 1);

            const size = win.getAdjustedWindowRect(self);
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
                @ptrCast(&self.extra.bmi),
                os.DIB_RGB_COLORS,
                os.SRCCOPY,
            );
        },
        os.WM_SIZE => if (wParam != os.SIZE_MINIMIZED) {
            self.width = os.LOWORD(lParam);
            self.height = os.HIWORD(lParam);
            _ = os.RedrawWindow(self.extra.hwnd, null, null, os.RDW_INVALIDATE | os.RDW_UPDATENOW);
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
