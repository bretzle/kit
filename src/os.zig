const std = @import("std");

pub const WINAPI = std.os.windows.WINAPI;

pub const BOOL = c_int;
pub const CHAR = u8;
pub const ATOM = u16;
pub const HBRUSH = HGDIOBJ;
pub const HCURSOR = *opaque {};
pub const HICON = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HMENU = *opaque {};
pub const HANDLE = *opaque {};
pub const HWND = std.os.windows.HWND;
pub const HDC = *opaque {};
pub const INT = c_int;
pub const LPCSTR = [*:0]const CHAR;
pub const LPCVOID = *const anyopaque;
pub const LPVOID = *anyopaque;
pub const UINT = c_uint;
pub const LONG_PTR = isize;
pub const WORD = u16;
pub const DWORD = u32;
pub const LONG = i32;
pub const BYTE = u8;
pub const HRESULT = c_long;

pub const WPARAM = usize;
pub const LPARAM = LONG_PTR;
pub const LRESULT = LONG_PTR;

pub const HGDIOBJ = *opaque {};
pub const HRGN = HGDIOBJ;
pub const HBITMAP = HGDIOBJ;
pub const HFONT = HGDIOBJ;

pub const COLORREF = DWORD;

pub const HPAINTBUFFER = HANDLE;

pub const CW_USEDEFAULT = @as(i32, @bitCast(@as(u32, 0x80000000)));

pub const RECT = extern struct {
    left: LONG = 0,
    top: LONG = 0,
    right: LONG = 0,
    bottom: LONG = 0,
};

pub const POINT = extern struct {
    x: LONG,
    y: LONG,
};

pub const IDC_ARROW: LPCSTR = @ptrFromInt(32512);
pub const IDC_IBEAM: LPCSTR = @ptrFromInt(32513);
pub const IDC_WAIT: LPCSTR = @ptrFromInt(32514);
pub const IDC_CROSS: LPCSTR = @ptrFromInt(32515);
pub const IDC_UPARROW: LPCSTR = @ptrFromInt(32516);
pub const IDC_SIZE: LPCSTR = @ptrFromInt(32640);
pub const IDC_ICON: LPCSTR = @ptrFromInt(32641);
pub const IDC_SIZENWSE: LPCSTR = @ptrFromInt(32642);
pub const IDC_SIZENESW: LPCSTR = @ptrFromInt(32643);
pub const IDC_SIZEWE: LPCSTR = @ptrFromInt(32644);
pub const IDC_SIZENS: LPCSTR = @ptrFromInt(32645);
pub const IDC_SIZEALL: LPCSTR = @ptrFromInt(32646);
pub const IDC_NO: LPCSTR = @ptrFromInt(32648);
pub const IDC_HAND: LPCSTR = @ptrFromInt(32649);
pub const IDC_APPSTARTING: LPCSTR = @ptrFromInt(32650);
pub const IDC_HELP: LPCSTR = @ptrFromInt(32651);
pub const IDC_PIN: LPCSTR = @ptrFromInt(32671);
pub const IDC_PERSON: LPCSTR = @ptrFromInt(32672);

pub extern "user32" fn LoadCursorA(hInstance: ?HINSTANCE, lpCursorName: LPCSTR) callconv(WINAPI) ?HCURSOR;

pub extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) ATOM;

pub extern "user32" fn GetWindowLongPtrA(hWnd: ?HWND, nIndex: INT) callconv(WINAPI) ?*anyopaque;

pub extern "user32" fn SetWindowLongPtrA(hWnd: ?HWND, nIndex: INT, dwNewLong: ?*anyopaque) callconv(WINAPI) LONG_PTR;

pub extern "user32" fn AdjustWindowRectEx(lpRect: *RECT, dwStyle: DWORD, bMenu: BOOL, dwExStyle: DWORD) callconv(WINAPI) BOOL;

pub extern "user32" fn CreateWindowExA(
    dwExStyle: DWORD,
    lpClassName: ?LPCSTR,
    lpWindowName: ?LPCSTR,
    dwStyle: DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWindParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: HINSTANCE,
    lpParam: ?LPVOID,
) callconv(WINAPI) ?HWND;

pub extern "user32" fn DestroyWindow(hWnd: HWND) BOOL;

pub extern "user32" fn DefWindowProcA(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;

pub const PM_NOREMOVE = 0x0000;
pub const PM_REMOVE = 0x0001;
pub const PM_NOYIELD = 0x0002;

pub extern "user32" fn PeekMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(WINAPI) BOOL;

pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) LRESULT;

pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) BOOL;

pub const WS_BORDER = 0x00800000;
pub const WS_OVERLAPPED = 0x00000000;
pub const WS_SYSMENU = 0x00080000;
pub const WS_DLGFRAME = 0x00400000;
pub const WS_CAPTION = WS_BORDER | WS_DLGFRAME;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
pub const WS_VISIBLE = 0x10000000;

pub const SIZE_RESTORED = 0;
pub const SIZE_MINIMIZED = 1;
pub const SIZE_MAXIMIZED = 2;
pub const SIZE_MAXSHOW = 3;
pub const SIZE_MAXHIDE = 4;

pub const WM_MOUSEMOVE = 0x0200;
pub const WM_LBUTTONDOWN = 0x0201;
pub const WM_LBUTTONUP = 0x0202;
pub const WM_LBUTTONDBLCLK = 0x0203;
pub const WM_RBUTTONDOWN = 0x0204;
pub const WM_RBUTTONUP = 0x0205;
pub const WM_RBUTTONDBLCLK = 0x0206;
pub const WM_MBUTTONDOWN = 0x0207;
pub const WM_MBUTTONUP = 0x0208;
pub const WM_MBUTTONDBLCLK = 0x0209;
pub const WM_MOUSEWHEEL = 0x020A;
pub const WM_MOUSELEAVE = 0x02A3;
pub const WM_INPUT = 0x00FF;
pub const WM_KEYDOWN = 0x0100;
pub const WM_KEYUP = 0x0101;
pub const WM_CHAR = 0x0102;
pub const WM_SYSKEYDOWN = 0x0104;
pub const WM_SYSKEYUP = 0x0105;
pub const WM_SETFOCUS = 0x0007;
pub const WM_KILLFOCUS = 0x0008;
pub const WM_CREATE = 0x0001;
pub const WM_DESTROY = 0x0002;
pub const WM_MOVE = 0x0003;
pub const WM_SIZE = 0x0005;
pub const WM_ACTIVATE = 0x0006;
pub const WM_ENABLE = 0x000A;
pub const WM_PAINT = 0x000F;
pub const WM_CLOSE = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_GETMINMAXINFO = 0x0024;
pub const WM_SETICON = 0x0080;

pub extern "kernel32" fn GetModuleHandleA(lpModuleName: ?LPCSTR) callconv(WINAPI) ?HINSTANCE;

pub const WNDPROC = *const fn (hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;

pub const MSG = extern struct {
    hWnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

pub const CS_VREDRAW = 0x0001;
pub const CS_HREDRAW = 0x0002;
pub const CS_DBLCLKS = 0x0008;
pub const CS_OWNDC = 0x0020;
pub const CS_CLASSDC = 0x0040;
pub const CS_PARENTDC = 0x0080;
pub const CS_NOCLOSE = 0x0200;
pub const CS_SAVEBITS = 0x0800;
pub const CS_BYTEALIGNCLIENT = 0x1000;
pub const CS_BYTEALIGNWINDOW = 0x2000;
pub const CS_GLOBALCLASS = 0x4000;
pub const CS_IME = 0x00010000;
pub const CS_DROPSHADOW = 0x00020000;

pub const WNDCLASSEXA = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXA),
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?LPCSTR,
    lpszClassName: LPCSTR,
    hIconSm: ?HICON,
};

// pub const WHEEL_DELTA = 120;

pub inline fn GET_WHEEL_DELTA_WPARAM(wparam: WPARAM) i16 {
    return @as(i16, @bitCast(@as(u16, @intCast((wparam >> 16) & 0xffff))));
}

pub inline fn GET_X_LPARAM(lparam: LPARAM) i32 {
    return @as(i32, @intCast(@as(i16, @bitCast(@as(u16, @intCast(lparam & 0xffff))))));
}

pub inline fn GET_Y_LPARAM(lparam: LPARAM) i32 {
    return @as(i32, @intCast(@as(i16, @bitCast(@as(u16, @intCast((lparam >> 16) & 0xffff))))));
}

pub inline fn LOWORD(dword: anytype) WORD {
    return @as(WORD, @bitCast(@as(u16, @intCast(dword & 0xffff))));
}

pub inline fn HIWORD(dword: anytype) WORD {
    return @as(WORD, @bitCast(@as(u16, @intCast((dword >> 16) & 0xffff))));
}

pub const SW_HIDE = 0;
pub const SW_SHOWNORMAL = 1;
pub const SW_NORMAL = 1;
pub const SW_SHOWMINIMIZED = 2;
pub const SW_SHOWMAXIMIZED = 3;
pub const SW_MAXIMIZE = 3;
pub const SW_SHOWNOACTIVATE = 4;
pub const SW_SHOW = 5;
pub const SW_MINIMIZE = 6;
pub const SW_SHOWMINNOACTIVE = 7;
pub const SW_SHOWNA = 8;
pub const SW_RESTORE = 9;
pub const SW_SHOWDEFAULT = 10;
pub const SW_FORCEMINIMIZE = 11;

pub extern "user32" fn ShowWindow(hWnd: ?HWND, nCmdShow: u32) callconv(WINAPI) BOOL;

pub const BITMAPINFOHEADER = extern struct {
    biSize: u32 = @sizeOf(BITMAPINFOHEADER),
    biWidth: i32 = 0,
    biHeight: i32 = 0,
    biPlanes: u16 = 0,
    biBitCount: u16 = 0,
    biCompression: u32 = 0,
    biSizeImage: u32 = 0,
    biXPelsPerMeter: i32 = 0,
    biYPelsPerMeter: i32 = 0,
    biClrUsed: u32 = 0,
    biClrImportant: u32 = 0,
};

pub const RGBQUAD = extern struct {
    rgbBlue: u8 = 0,
    rgbGreen: u8 = 0,
    rgbRed: u8 = 0,
    rgbReserved: u8 = 0,
};

pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER = .{},
    bmiColors: [1]RGBQUAD = .{.{}},
};

pub const CIEXYZ = extern struct {
    ciexyzX: i32 = 0,
    ciexyzY: i32 = 0,
    ciexyzZ: i32 = 0,
};

pub const CIEXYZTRIPLE = extern struct {
    ciexyzRed: CIEXYZ = .{},
    ciexyzGreen: CIEXYZ = .{},
    ciexyzBlue: CIEXYZ = .{},
};

pub const BITMAPV5HEADER = extern struct {
    bV5Size: u32 = @sizeOf(BITMAPV5HEADER),
    bV5Width: i32 = 0,
    bV5Height: i32 = 0,
    bV5Planes: u16 = 0,
    bV5BitCount: u16 = 0,
    bV5Compression: u32 = 0,
    bV5SizeImage: u32 = 0,
    bV5XPelsPerMeter: i32 = 0,
    bV5YPelsPerMeter: i32 = 0,
    bV5ClrUsed: u32 = 0,
    bV5ClrImportant: u32 = 0,
    bV5RedMask: u32 = 0,
    bV5GreenMask: u32 = 0,
    bV5BlueMask: u32 = 0,
    bV5AlphaMask: u32 = 0,
    bV5CSType: u32 = 0,
    bV5Endpoints: CIEXYZTRIPLE = .{},
    bV5GammaRed: u32 = 0,
    bV5GammaGreen: u32 = 0,
    bV5GammaBlue: u32 = 0,
    bV5Intent: u32 = 0,
    bV5ProfileData: u32 = 0,
    bV5ProfileSize: u32 = 0,
    bV5Reserved: u32 = 0,
};

pub extern "user32" fn GetDC(hwnd: ?HWND) callconv(WINAPI) ?HDC;

pub extern "user32" fn ReleaseDC(hWnd: ?HWND, hDC: ?HDC) callconv(WINAPI) INT;

pub const DIB_RGB_COLORS = 0; // color table in RGBs
pub const DIB_PAL_COLORS = 1; // color table in palette indices

pub const SRCCOPY = 0x00CC0020; // dest = source
pub const SRCPAINT = 0x00EE0086; // dest = source OR dest
pub const SRCAND = 0x008800C6; // dest = source AND dest
pub const SRCINVERT = 0x00660046; // dest = source XOR dest
pub const SRCERASE = 0x00440328; // dest = source AND (NOT dest )
pub const NOTSRCCOPY = 0x00330008; // dest = (NOT source)
pub const NOTSRCERASE = 0x001100A6; // dest = (NOT src) AND (NOT dest)
pub const MERGECOPY = 0x00C000CA; // dest = (source AND pattern)
pub const MERGEPAINT = 0x00BB0226; // dest = (NOT source) OR dest
pub const PATCOPY = 0x00F00021; // dest = pattern
pub const PATPAINT = 0x00FB0A09; // dest = DPSnoo
pub const PATINVERT = 0x005A0049; // dest = pattern XOR dest
pub const DSTINVERT = 0x00550009; // dest = (NOT dest)
pub const BLACKNESS = 0x00000042; // dest = BLACK
pub const WHITENESS = 0x00FF0062; // dest = WHITE

pub extern "gdi32" fn StretchDIBits(hdc: HDC, xDest: INT, yDest: INT, DestWidth: INT, DestHeight: INT, xSrc: INT, ySrc: INT, SrcWidth: INT, SrcHeight: INT, lpBits: ?*const anyopaque, lpbmi: ?*const BITMAPINFO, iUsage: UINT, rop: DWORD) i32;

pub extern "user32" fn ValidateRect(hWnd: ?HWND, lpRect: ?*const RECT) callconv(WINAPI) BOOL;

pub const RDW_INVALIDATE = 0x0001;
pub const RDW_INTERNALPAINT = 0x0002;
pub const RDW_ERASE = 0x0004;
pub const RDW_VALIDATE = 0x0008;
pub const RDW_NOINTERNALPAINT = 0x0010;
pub const RDW_NOERASE = 0x0020;
pub const RDW_NOCHILDREN = 0x0040;
pub const RDW_ALLCHILDREN = 0x0080;
pub const RDW_UPDATENOW = 0x0100;
pub const RDW_ERASENOW = 0x0200;
pub const RDW_FRAME = 0x0400;
pub const RDW_NOFRAME = 0x0800;

pub extern "user32" fn RedrawWindow(hwnd: ?HWND, lprcUpdate: ?*const RECT, hrgnUpdate: ?HRGN, flags: UINT) callconv(WINAPI) BOOL;

pub const PAINTSTRUCT = extern struct {
    hdc: ?HDC,
    fErase: BOOL,
    rcPaint: RECT,
    fRestore: BOOL,
    fIncUpdate: BOOL,
    rgbReserved: [32]u8,
};

pub extern "user32" fn BeginPaint(hwnd: ?HWND, lpPaint: ?*PAINTSTRUCT) callconv(WINAPI) ?HDC;

pub extern "gdi32" fn CreateSolidBrush(color: u32) callconv(WINAPI) ?HBRUSH;

pub extern "user32" fn FillRect(hdc: ?HDC, lprc: ?*const RECT, hbr: ?HBRUSH) callconv(WINAPI) i32;

pub extern "gdi32" fn DeleteObject(ho: ?HGDIOBJ) callconv(WINAPI) BOOL;

pub extern "user32" fn EndPaint(hwnd: ?HWND, lpPaint: ?*const PAINTSTRUCT) callconv(WINAPI) BOOL;

pub const GWLP_USERDATA = -21;

pub const DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
pub const DWMWA_WINDOW_CORNER_PREFERENCE = 33;

pub extern "dwmapi" fn DwmSetWindowAttribute(hwnd: HWND, dwAttribute: DWORD, pvAttribute: LPCVOID, cbAttribute: DWORD) callconv(WINAPI) HRESULT;

pub extern "user32" fn LoadIconA(hInstance: ?HINSTANCE, lpIconName: ?[*:0]const u8) callconv(WINAPI) ?HICON;

pub inline fn RGB(r: u8, g: u8, b: u8) COLORREF {
    return @as(DWORD, r) | (@as(DWORD, g) << 8) | (@as(DWORD, b) << 16);
}

pub const ANSI_VAR_FONT = 12;

pub extern "gdi32" fn GetStockObject(i: i32) callconv(WINAPI) ?HGDIOBJ;

pub extern "gdi32" fn SelectObject(hdc: HDC, h: HGDIOBJ) callconv(WINAPI) ?HGDIOBJ;

pub const TRANSPARENT = 1;

pub extern "gdi32" fn SetBkMode(hdc: HDC, mode: i32) callconv(WINAPI) i32;

pub extern "gdi32" fn SetBkColor(hdc: HDC, color: COLORREF) callconv(WINAPI) COLORREF;

pub extern "gdi32" fn SetTextColor(hdc: HDC, color: COLORREF) callconv(WINAPI) COLORREF;

pub const ETO_OPAQUE = 0x0002;

pub extern "gdi32" fn ExtTextOutA(hdc: HDC, x: i32, y: i32, options: UINT, lprect: ?*const RECT, lpString: ?LPCSTR, c: UINT, lpDx: ?*const i32) callconv(WINAPI) BOOL;

pub extern "uxtheme" fn BufferedPaintInit() callconv(WINAPI) HRESULT;

pub const BLENDFUNCTION = extern struct {
    BlendOp: BYTE,
    BlendFlags: BYTE,
    SourceConstantAlpha: BYTE,
    AlphaFormat: BYTE,
};

pub const BP_PAINTPARAMS = extern struct {
    cbSize: DWORD,
    dwFlags: DWORD,
    prcExclude: *const RECT,
    pBlendFunction: *const BLENDFUNCTION,
};

pub const BP_BUFFERFORMAT = enum(u32) {
    BPBF_COMPATIBLEBITMAP,
    BPBF_DIB,
    BPBF_TOPDOWNDIB,
    BPBF_TOPDOWNMONODIB,
};

pub extern "uxtheme" fn BeginBufferedPaint(hdcTarget: HDC, prcTarget: *const RECT, dwFormat: BP_BUFFERFORMAT, pPaintParams: ?*BP_PAINTPARAMS, phdc: *HDC) callconv(WINAPI) ?HPAINTBUFFER;

pub extern "uxtheme" fn EndBufferedPaint(hBufferedPaint: HPAINTBUFFER, fUpdateTarget: BOOL) callconv(WINAPI) HRESULT;

pub extern "user32" fn GetClientRect(hwnd: HWND, lpRect: *RECT) callconv(WINAPI) BOOL;

pub extern "gdi32" fn SelectClipRgn(hdc: HDC, hrgn: ?HRGN) callconv(WINAPI) INT;

pub extern "gdi32" fn IntersectClipRect(hdc: HDC, left: INT, top: INT, right: INT, bottom: INT) callconv(WINAPI) INT;

pub const SIZE = extern struct {
    cx: LONG = 0,
    cy: LONG = 0,
};

pub extern "gdi32" fn GetTextExtentPoint32A(hdc: ?HDC, lpString: LPCSTR, c: i32, psizl: *SIZE) callconv(WINAPI) BOOL;

pub const MK_LBUTTON = 1;
pub const MK_RBUTTON = 2;