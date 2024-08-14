const std = @import("std");
const os = @import("os.zig");
const assert = std.debug.assert;

pub const Clip = enum { none, part, all };

pub const StyleColor = enum {
    text,
    border,
    window_bg,
    title_bg,
    title_text,
    panel_bg,
    button,
    button_hover,
    button_focus,
    base,
    base_hover,
    base_focus,
    scroll_base,
    scroll_thumb,
};

pub const Icon = enum { close, check, collapsed, expanded };

pub const Result = packed struct {
    active: bool = false,
    submit: bool = false,
    change: bool = false,
};

pub const Opt = packed struct {
    aligncenter: bool = false,
    alignright: bool = false,
    nointeract: bool = false,
    noframe: bool = false,
    noresize: bool = false,
    noscroll: bool = false,
    noclose: bool = false,
    notitle: bool = false,
    holdfocus: bool = false,
    autosize: bool = false,
    popup: bool = false,
    closed: bool = false,
    expanded: bool = false,
};

pub const Mouse = enum { none, left, right, middle };

pub const Key = packed struct {
    shift: bool = false,
    ctrl: bool = false,
    alt: bool = false,
    backspace: bool = false,
    ret: bool = false,
};

pub const Id = u32;
const HASH_INITIAL = 2166136261;

pub const Command = union(enum) {
    clip: struct { rect: Rect },
    rect: struct { rect: Rect, color: Color },
    text: struct { pos: Vec2, color: Color, str: []const u8 },
    icon: struct { rect: Rect, id: Icon, color: Color },
};

pub const Real = f32;

pub const Vec2 = @Vector(2, i32);

pub const Rect = struct {
    x: i32 = 0,
    y: i32 = 0,
    w: i32 = 0,
    h: i32 = 0,

    const unclipped = .{ .w = 0x1000000, .h = 0x1000000 };

    fn overlaps(r: Rect, p: Vec2) bool {
        return p[0] >= r.x and p[0] < r.x + r.w and p[1] >= r.y and p[1] < r.y + r.h;
    }

    fn expand(r: Rect, n: i32) Rect {
        return .{
            .x = r.x - n,
            .y = r.y - n,
            .w = r.w + n * 2,
            .h = r.h + n * 2,
        };
    }

    fn intersect(r1: Rect, r2: Rect) Rect {
        const x1 = @max(r1.x, r2.x);
        const y1 = @max(r1.y, r2.y);
        var x2 = @min(r1.x + r1.w, r2.x + r2.w);
        var y2 = @min(r1.y + r1.h, r2.y + r2.h);
        if (x2 < x1) x2 = x1;
        if (y2 < y1) y2 = y1;
        return .{ .x = x1, .y = y1, .w = x2 - x1, .h = y2 - y1 };
    }

    pub inline fn windows(self: Rect) os.RECT {
        return os.RECT{ .left = self.x, .top = self.y, .right = self.x + self.w, .bottom = self.y + self.h };
    }
};

pub const Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub inline fn windows(self: Color) os.COLORREF {
        return @as(os.COLORREF, @bitCast(self)) & 0x00FF_FFFF;
    }
};

pub const PoolItem = struct {
    id: Id = 0,
    last_update: i32 = 0,
};

pub const Layout = struct {
    body: Rect = .{},
    next: Rect = .{},
    position: Vec2 = .{ 0, 0 },
    size: Vec2 = .{ 0, 0 },
    max: Vec2 = .{ 0, 0 },
    widths: std.BoundedArray(i32, 16) = .{},
    items: i32 = 0,
    item_index: i32 = 0,
    next_row: i32 = 0,
    next_type: LayoutType = .none,
    indent: i32 = 0,
};

pub const LayoutType = enum { none, relative, absolute };

pub const Container = struct {
    head_idx: u32,
    tail_idx: u32,
    rect: Rect = .{},
    body: Rect = .{},
    content_size: Vec2 = .{ 0, 0 },
    scroll: Vec2 = .{ 0, 0 },
    zindex: i32 = 0,
    open: i32,

    pub fn compare(_: void, lhs: *Container, rhs: *Container) bool {
        return lhs.zindex < rhs.zindex;
    }
};

pub const Style = struct {
    size: Vec2 = .{ 68, 10 },
    padding: i32 = 5,
    spacing: i32 = 4,
    indent: i32 = 24,
    title_height: i32 = 24,
    scrollbar_size: i32 = 12,
    thumb_size: i32 = 8,
    colors: std.EnumArray(StyleColor, Color) = .{ .values = .{
        .{ .r = 0xE6, .g = 0xE6, .b = 0xE6, .a = 0xFF },
        .{ .r = 0x19, .g = 0x19, .b = 0x19, .a = 0xFF },
        .{ .r = 0x32, .g = 0x32, .b = 0x32, .a = 0xFF },
        .{ .r = 0x19, .g = 0x19, .b = 0x19, .a = 0xFF },
        .{ .r = 0xF0, .g = 0xF0, .b = 0xF0, .a = 0xFF },
        .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0x00 },
        .{ .r = 0x4B, .g = 0x4B, .b = 0x4B, .a = 0xFF },
        .{ .r = 0x5F, .g = 0x5F, .b = 0x5F, .a = 0xFF },
        .{ .r = 0x73, .g = 0x73, .b = 0x73, .a = 0xFF },
        .{ .r = 0x1E, .g = 0x1E, .b = 0x1E, .a = 0xFF },
        .{ .r = 0x23, .g = 0x23, .b = 0x23, .a = 0xFF },
        .{ .r = 0x28, .g = 0x28, .b = 0x28, .a = 0xFF },
        .{ .r = 0x2B, .g = 0x2B, .b = 0x2B, .a = 0xFF },
        .{ .r = 0x1E, .g = 0x1E, .b = 0x1E, .a = 0xFF },
    } },

    var default = Style{};
};

pub const Context = struct {
    const Self = @This();

    // callbacks
    textWidth: *const fn ([]const u8) i32 = undefined,
    textHeight: *const fn () i32 = undefined,

    // core state
    style: *Style = &Style.default,
    hover: Id = 0,
    focus: Id = 0,
    last_id: Id = 0,
    last_rect: Rect = .{},
    last_zindex: i32 = 0,
    updated_focus: i32 = 0, // bool?
    frame: i32 = 0,
    hover_root: ?*Container = null,
    next_hover_root: ?*Container = null,
    scroll_target: ?*Container = null,
    number_edit_buf: [127]u8 = [_]u8{0} ** 127,
    number_edit: Id = 0,
    cmd_idx: usize = 0,

    // stacks
    command_list: Stack(Command, 1024) = .{},
    root_list: Stack(*Container, 16) = .{},
    container_stack: Stack(*Container, 16) = .{},
    clip_stack: Stack(Rect, 16) = .{},
    id_stack: Stack(Id, 16) = .{},
    layout_stack: Stack(Layout, 8) = .{},
    text_stack: std.BoundedArray(u8, 16384) = .{},

    // retained pools
    container_pool: Pool(16) = undefined,
    containers: [16]Container = undefined,
    treenode_pool: Pool(16) = undefined,

    // input state
    mouse_pos: Vec2 = .{ 0, 0 },
    last_mouse_pos: Vec2 = .{ 0, 0 },
    mouse_delta: Vec2 = .{ 0, 0 },
    scroll_delta: Vec2 = .{ 0, 0 },
    mouse_down: Mouse = .none,
    mouse_pressed: Mouse = .none,
    key_down: i32 = 0,
    key_pressed: i32 = 0,
    input_text: [32]u8 = [_]u8{0} ** 32,

    pub fn begin(ctx: *Self) void {
        ctx.command_list.len = 0;
        ctx.root_list.len = 0;
        ctx.text_stack.len = 0;
        ctx.scroll_target = null;
        ctx.hover_root = ctx.next_hover_root;
        ctx.next_hover_root = null;
        ctx.mouse_delta = ctx.mouse_pos - ctx.last_mouse_pos;
        ctx.frame += 1;
    }

    pub fn end(ctx: *Self) void {
        // check stacks
        assert(ctx.container_stack.len == 0);
        assert(ctx.clip_stack.len == 0);
        assert(ctx.id_stack.len == 0);
        assert(ctx.layout_stack.len == 0);

        // handle scroll input
        if (ctx.scroll_target) |target| {
            target.scroll += ctx.scroll_delta;
        }

        // unset focus if focus id was not touched this frame
        if (ctx.updated_focus == 0) ctx.focus = 0;
        ctx.updated_focus = 0;

        // bring hover root to front if mouse was pressed
        if (ctx.next_hover_root) |root| {
            if (ctx.mouse_pressed != .none and root.zindex < ctx.last_zindex and root.zindex >= 0) {
                ctx.mu_bring_to_front(root);
            }
        }

        // reset input state
        ctx.key_pressed = 0;
        ctx.input_text[0] = 0;
        ctx.mouse_pressed = .none;
        ctx.scroll_delta = .{ 0, 0 };
        ctx.last_mouse_pos = ctx.mouse_pos;

        // sort root containers by zindex
        std.mem.sort(*Container, ctx.root_list.slice(), {}, Container.compare);
    }

    pub fn setFocus(ctx: *Self, id: Id) void {
        ctx.focus = id;
        ctx.updated_focus = 1;
    }

    pub fn getId(ctx: *Self, data: []const u8) Id {
        const res = ctx.id_stack.peek() orelse HASH_INITIAL;
        var hasher = std.hash.Fnv1a_32{ .value = res };
        hasher.update(data);
        const hash = hasher.final();
        ctx.last_id = hash;
        return hash;
    }

    pub fn pushId(ctx: *Self, data: []const u8) void {
        ctx.id_stack.push(ctx.getId(data));
    }

    pub fn popId(ctx: *Self) void {
        ctx.id_stack.pop();
    }

    pub fn mu_push_clip_rect(ctx: *Self, rect: Rect) void {
        const last = ctx.mu_get_clip_rect();
        ctx.clip_stack.push(rect.intersect(last));
    }

    pub fn mu_pop_clip_rect(ctx: *Self) void {
        ctx.clip_stack.pop();
    }

    pub fn mu_get_clip_rect(ctx: *Self) Rect {
        return ctx.clip_stack.peek().?;
    }

    pub fn mu_check_clip(ctx: *Self, r: Rect) Clip {
        const cr = ctx.mu_get_clip_rect();
        if (r.x > cr.x + cr.w or r.x + r.w < cr.x or r.y > cr.y + cr.h or r.y + r.h < cr.y) return .all;
        if (r.x >= cr.x and r.x + r.w <= cr.x + cr.w and r.y >= cr.y and r.y + r.h <= cr.y + cr.h) return .none;
        return .part;
    }

    pub fn mu_get_current_container(ctx: *Self) *Container {
        return ctx.container_stack.peek() orelse unreachable;
    }

    pub fn mu_get_container(ctx: *Self, name: []const u8) *Container {
        const id = ctx.getId(name);
        return ctx.getContainerInit(id, .{}) orelse unreachable;
    }

    pub fn mu_bring_to_front(ctx: *Self, cnt: *Container) void {
        ctx.last_zindex += 1;
        cnt.zindex = ctx.last_zindex;
    }

    pub fn mu_push_text(ctx: *Self, str: []const u8) []const u8 {
        const start = ctx.text_stack.len;
        ctx.text_stack.appendSliceAssumeCapacity(str);
        return ctx.text_stack.constSlice()[start..];
    }

    pub fn mu_input_mousemove(ctx: *Self, x: i32, y: i32) void {
        ctx.mouse_pos = .{ x, y };
    }

    pub fn mu_input_mousedown(ctx: *Self, x: i32, y: i32, btn: Mouse) void {
        ctx.mu_input_mousemove(x, y);
        ctx.mouse_down = btn;
        ctx.mouse_pressed = btn;
    }

    pub fn mu_input_mouseup(ctx: *Self, x: i32, y: i32, btn: Mouse) void {
        _ = btn; // autofix
        ctx.mu_input_mousemove(x, y);
        ctx.mouse_down = .none;
    }

    pub fn mu_input_scroll(ctx: *Self, x: i32, y: i32) void {
        ctx.scroll_delta[0] += x;
        ctx.scroll_delta[1] += y;
    }

    pub fn mu_input_keydown(ctx: *Self, key: i32) void {
        ctx.key_down |= key;
        ctx.key_pressed |= key;
    }

    pub fn mu_input_keyup(ctx: *Self, key: i32) void {
        ctx.key_down &= ~key;
    }

    pub fn mu_input_text(ctx: *Self, text: []const u8) void {
        @memcpy(ctx.input_text[0..text.len], text);
    }

    pub fn mu_set_clip(ctx: *Self, rect: Rect) void {
        ctx.command_list.push(.{ .clip = .{ .rect = rect } });
    }

    pub fn mu_draw_rect(ctx: *Self, rect: Rect, color: Color) void {
        const r = rect.intersect(ctx.mu_get_clip_rect());
        if (r.w > 0 and r.h > 0) {
            ctx.command_list.push(.{ .rect = .{
                .rect = r,
                .color = color,
            } });
        }
    }

    pub fn mu_draw_box(ctx: *Self, rect: Rect, color: Color) void {
        ctx.mu_draw_rect(.{ .x = rect.x + 1, .y = rect.y, .w = rect.w - 2, .h = 1 }, color);
        ctx.mu_draw_rect(.{ .x = rect.x + 1, .y = rect.y + rect.h - 1, .w = rect.w - 2, .h = 1 }, color);
        ctx.mu_draw_rect(.{ .x = rect.x, .y = rect.y, .w = 1, .h = rect.h }, color);
        ctx.mu_draw_rect(.{ .x = rect.x + rect.w - 1, .y = rect.y, .w = 1, .h = rect.h }, color);
    }

    pub fn mu_draw_text(ctx: *Self, str: []const u8, pos: Vec2, color: Color) void {
        const rect = Rect{ .x = pos[0], .y = pos[1], .w = ctx.textWidth(str), .h = ctx.textHeight() };

        const clipped = mu_check_clip(ctx, rect);
        if (clipped == .all) return;
        if (clipped == .part) mu_set_clip(ctx, mu_get_clip_rect(ctx));

        // add command
        const str_start = ctx.mu_push_text(str);
        ctx.command_list.push(.{ .text = .{
            .str = str_start,
            .pos = pos,
            .color = color,
        } });

        // reset clipping if it was set
        if (clipped != .none) mu_set_clip(ctx, Rect.unclipped);
    }

    pub fn mu_draw_icon(ctx: *Self, id: Icon, rect: Rect, color: Color) void {
        // do clip command if the rect isn't fully contained within the cliprect
        const clipped = ctx.mu_check_clip(rect);
        if (clipped == .all) return;
        if (clipped == .part) ctx.mu_set_clip(ctx.mu_get_clip_rect());

        // do icon command
        ctx.command_list.push(.{ .icon = .{
            .id = id,
            .rect = rect,
            .color = color,
        } });

        // reset clipping if it was set
        if (clipped != .none) ctx.mu_set_clip(Rect.unclipped);
    }

    pub fn mu_layout_row(ctx: *Self, items: i32, widths: ?[]const i32, height: i32) void {
        const layout = ctx.getLayout();
        if (widths) |w| {
            std.debug.assert(items <= 16);
            layout.widths.len = 0;
            layout.widths.appendSliceAssumeCapacity(w);
        }
        layout.items = items;
        layout.position = .{ layout.indent, layout.next_row };
        layout.size[1] = height;
        layout.item_index = 0;
    }

    pub fn mu_layout_width(ctx: *Self, width: i32) void {
        ctx.getLayout().size[0] = width;
    }

    pub fn mu_layout_height(ctx: *Self, height: i32) void {
        ctx.getLayout().size[1] = height;
    }

    pub fn mu_layout_begin_column(ctx: *Self) void {
        ctx.pushLayout(ctx.mu_layout_next(), .{ 0, 0 });
    }

    pub fn mu_layout_end_column(ctx: *Self) void {
        const b = ctx.getLayout();
        ctx.layout_stack.pop();
        // inherit position/next_row/max from child layout if they are greater
        const a = ctx.getLayout();
        a.position[0] = @max(a.position[0], b.position[0] + b.body.x - a.body.x);
        a.next_row = @max(a.next_row, b.next_row + b.body.y - a.body.y);
        a.max[0] = @max(a.max[0], b.max[0]);
        a.max[1] = @max(a.max[1], b.max[1]);
    }

    pub fn mu_layout_set_next(ctx: *Self, r: Rect, next_type: LayoutType) void {
        const layout = ctx.getLayout();
        layout.next = r;
        layout.next_type = next_type;
    }

    pub fn mu_layout_next(ctx: *Self) Rect {
        const layout = ctx.getLayout();
        const style = ctx.style;
        var res = Rect{};

        if (layout.next_type != .none) {
            const ltype = layout.next_type;
            layout.next_type = .none;
            res = layout.next;
            if (ltype == .absolute) {
                ctx.last_rect = res;
                return res;
            }
        } else {
            // handle next row
            if (layout.item_index == layout.items) {
                ctx.mu_layout_row(layout.items, null, layout.size[1]);
            }

            // position
            res.x = layout.position[0];
            res.y = layout.position[1];

            // size
            res.w = if (layout.items > 0) layout.widths.buffer[@intCast(layout.item_index)] else layout.size[0];
            res.h = layout.size[1];
            if (res.w == 0) res.w = style.size[0] + style.padding * 2;
            if (res.h == 0) res.h = style.size[1] + style.padding * 2;
            if (res.w < 0) res.w += layout.body.w - res.x + 1;
            if (res.h < 0) res.h += layout.body.h - res.y + 1;

            layout.item_index += 1;
        }

        // update position
        layout.position[0] += res.w + style.padding;
        layout.next_row = @max(layout.next_row, res.y + res.h + style.spacing);

        // apply body offset
        res.x += layout.body.x;
        res.y += layout.body.y;

        // update max position
        layout.max[0] = @max(layout.max[0], res.x + res.w);
        layout.max[1] = @max(layout.max[1], res.y + res.h);

        ctx.last_rect = res;
        return res;
    }

    pub fn mu_draw_control_frame(ctx: *Self, id: Id, rect: Rect, colorid: StyleColor, opt: Opt) void {
        if (opt.noframe) return;
        const color = @intFromEnum(colorid) + @as(u4, if (ctx.focus == id) 2 else if (ctx.hover == id) 1 else 0);
        ctx.drawFrame(rect, @enumFromInt(color));
    }

    pub fn mu_draw_control_text(ctx: *Self, str: []const u8, rect: Rect, colorid: StyleColor, opt: Opt) void {
        const tw = ctx.textWidth(str);
        ctx.mu_push_clip_rect(rect);
        const y = rect.y + @divFloor(rect.h - ctx.textHeight(), 2);
        const x = if (opt.aligncenter)
            rect.x + @divFloor(rect.w - tw, 2)
        else if (opt.alignright)
            rect.x + rect.w - tw - ctx.style.padding
        else
            rect.x + ctx.style.padding;

        ctx.mu_draw_text(str, .{ x, y }, ctx.style.colors.get(colorid));
        ctx.mu_pop_clip_rect();
    }

    pub fn mu_mouse_over(ctx: *Self, rect: Rect) bool {
        return rect.overlaps(ctx.mouse_pos) and ctx.mu_get_clip_rect().overlaps(ctx.mouse_pos) and ctx.inHoverRoot();
    }

    pub fn mu_update_control(ctx: *Self, id: Id, rect: Rect, opt: Opt) void {
        const mouseover = ctx.mu_mouse_over(rect);

        if (ctx.focus == id) ctx.updated_focus = 1;
        if (opt.nointeract) return;
        if (mouseover and ctx.mouse_down == .none) ctx.hover = id;

        if (ctx.focus == id) {
            if (ctx.mouse_pressed != .none and !mouseover) ctx.setFocus(0);
            if (ctx.mouse_down == .none and !opt.holdfocus) ctx.setFocus(0);
        }

        if (ctx.hover == id) {
            if (ctx.mouse_pressed != .none) {
                ctx.setFocus(id);
            } else if (!mouseover) {
                ctx.hover = 0;
            }
        }
    }

    pub fn mu_text(ctx: *Self, text: []const u8) void {
        const color = ctx.style.colors.get(.text);
        ctx.mu_layout_begin_column();
        ctx.mu_layout_row(1, &.{-1}, ctx.textHeight());

        var p: usize = 0;
        var start_idx: usize = 0;
        var end_idx: usize = 0;
        while (end_idx < text.len) {
            const r = ctx.mu_layout_next();
            var w: i32 = 0;
            end_idx = p;
            start_idx = end_idx;
            while (end_idx < text.len and text[end_idx] != '\n') {
                const word = p;
                while (p < text.len and text[p] != ' ' and text[p] != '\n') p += 1;
                w += ctx.textWidth(text[word..p]);
                if (w > r.w and end_idx != start_idx) break;
                if (p < text.len) w += ctx.textWidth(std.mem.asBytes(&text[p]));
                end_idx = p;
                p += 1;
            }
            ctx.mu_draw_text(text[start_idx..end_idx], .{ r.x, r.y }, color);
            p = end_idx + 1;
        }

        ctx.mu_layout_end_column();
    }

    pub fn mu_label(ctx: *Self, text: []const u8) void {
        ctx.mu_draw_control_text(text, ctx.mu_layout_next(), .text, .{});
    }

    pub fn mu_button(ctx: *Self, label: []const u8) bool {
        return ctx.mu_button_ex(label, 0, .{ .aligncenter = true });
    }

    pub fn mu_button_ex(ctx: *Self, label: []const u8, icon: i32, opt: Opt) bool {
        // TODO icon
        _ = icon; // autofix
        const id = ctx.getId(label);
        const r = ctx.mu_layout_next();
        ctx.mu_update_control(id, r, opt);

        // handle click
        const clicked = ctx.mouse_pressed == .left and ctx.focus == id;

        // draw
        ctx.mu_draw_control_frame(id, r, .button, opt);
        ctx.mu_draw_control_text(label, r, .text, opt);

        return clicked;
    }

    pub fn mu_checkbox(ctx: *Self, label: []const u8, state: *bool) Result {
        var result = Result{};
        const id = ctx.getId(std.mem.asBytes(&state));
        const r = ctx.mu_layout_next();
        const box = Rect{ .x = r.x, .y = r.y, .w = r.h, .h = r.h };
        ctx.mu_update_control(id, r, .{});

        // handle click
        if (ctx.mouse_pressed == .left and ctx.focus == id) {
            result.change = true;
            state.* = !state.*;
        }

        // draw
        ctx.mu_draw_control_frame(id, box, .base, .{});
        if (state.*) ctx.mu_draw_icon(.check, box, ctx.style.colors.get(.text));
        const rr = Rect{ .x = r.x + box.w, .y = r.y, .w = r.w - box.w, .h = r.h };
        ctx.mu_draw_control_text(label, rr, .text, .{});

        return result;
    }

    pub fn mu_textbox_raw(ctx: *Self, buf: []u8, id: Id, r: Rect, opt: Opt) i32 {
        _ = ctx; // autofix
        _ = buf; // autofix
        _ = id; // autofix
        _ = r; // autofix
        _ = opt; // autofix
        @panic("TODO");
    }

    pub fn mu_textbox_ex(ctx: *Self, buf: []u8, opt: Opt) i32 {
        const id = ctx.getId(std.mem.asBytes(&buf));
        const r = ctx.mu_layout_next();
        return ctx.mu_textbox_raw(buf, id, r, opt);
    }

    pub fn mu_slider(ctx: *Self, comptime T: type, value: *T, low: T, high: T) Result {
        return ctx.mu_slider_ex(T, value, low, high, 0, "{}", .{ .aligncenter = true });
    }

    pub fn mu_slider_ex(ctx: *Self, comptime T: type, value: *T, low: T, high: T, step: T, comptime fmt: []const u8, opt: Opt) Result {
        var result = Result{};
        const id = ctx.getId(std.mem.asBytes(&value));
        const base = ctx.mu_layout_next();

        const last = value.*;
        var v: i32 = @intCast(last);

        // handle text input mode
        // TODO

        // handle normal mode
        ctx.mu_update_control(id, base, opt);

        // handle input
        if (ctx.focus == id and (ctx.mouse_down == .left or ctx.mouse_pressed == .left)) {
            v = @divTrunc(low + (ctx.mouse_pos[0] - base.x) * (high - low), base.w);
            const step_: i32 = @intCast(step);
            if (step_ != 0) {
                v = @divTrunc(v + @divTrunc(step_, 2), step_) * step_;
            }
        }

        // clamp and store value, update result
        v = std.math.clamp(v, low, high);
        value.* = @intCast(v);
        if (last != v) result.change = true;

        // draw base
        ctx.mu_draw_control_frame(id, base, .base, opt);

        // draw thumb
        const w = ctx.style.thumb_size;
        const x = @divFloor((v - low) * (base.w - w), (high - low));
        const thumb = Rect{ .x = base.x + x, .y = base.y, .w = w, .h = base.h };
        ctx.mu_draw_control_frame(id, thumb, .button, opt);

        // draw text
        var buf: [16]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, fmt, .{v}) catch unreachable;
        ctx.mu_draw_control_text(text, base, .text, opt);

        return result;
    }

    pub fn mu_number_ex(ctx: *Self, value: []Real, step: Real, fmt: []const u8, opt: i32) i32 {
        _ = ctx; // autofix
        _ = value; // autofix
        _ = step; // autofix
        _ = fmt; // autofix
        _ = opt; // autofix
        unreachable;
    }

    pub fn mu_header_ex(ctx: *Self, label: []const u8, opt: Opt) bool {
        return ctx.headerImpl(label, false, opt);
    }

    pub fn mu_begin_treenode_ex(ctx: *Self, label: []const u8, opt: Opt) bool {
        const result = ctx.headerImpl(label, true, opt);
        if (result) {
            ctx.getLayout().indent += ctx.style.indent;
            ctx.id_stack.push(ctx.last_id);
        }
        return result;
    }

    pub fn mu_end_treenode(ctx: *Self) void {
        ctx.getLayout().indent -= ctx.style.indent;
        ctx.popId();
    }

    pub fn beginWindowEx(ctx: *Self, title: []const u8, bounds: Rect, opt: Opt) bool {
        const id = ctx.getId(title);
        const cnt = ctx.getContainerInit(id, opt) orelse return false;
        if (cnt.open == 0) return false;
        ctx.id_stack.push(id);

        if (cnt.rect.w == 0) cnt.rect = bounds;
        ctx.beginRootContainer(cnt);

        const rect = cnt.rect;
        var body = cnt.rect;

        // draw frame
        if (!opt.noframe) {
            ctx.drawFrame(rect, .window_bg);
        }

        // do title bar
        if (!opt.notitle) {
            var tr = rect;
            tr.h = ctx.style.title_height;
            ctx.drawFrame(tr, .title_bg);

            // title text
            if (true) {
                const iid = ctx.getId("!title");
                ctx.mu_update_control(iid, tr, opt);
                ctx.mu_draw_control_text(title, tr, .title_text, opt);
                if (iid == ctx.focus and ctx.mouse_down == .left) {
                    cnt.rect.x += ctx.mouse_delta[0];
                    cnt.rect.y += ctx.mouse_delta[1];
                }
                body.y += tr.h;
                body.h -= tr.h;
            }

            // close button
            if (!opt.noclose) {
                const iid = ctx.getId("!close");
                const r = Rect{ .x = tr.x + tr.w - tr.h, .y = tr.y, .w = tr.h, .h = tr.h };
                tr.w -= r.w;
                ctx.mu_draw_icon(.close, r, ctx.style.colors.get(.title_text));
                ctx.mu_update_control(iid, r, opt);
                if (ctx.mouse_pressed == .left and iid == ctx.focus) {
                    cnt.open = 0;
                }
            }
        }

        ctx.pushContainerBody(cnt, body, opt);

        // do resize handle
        if (!opt.noresize) {
            const sz = ctx.style.title_height;
            const iid = ctx.getId("!resize");
            const r = Rect{ .x = rect.x + rect.w - sz, .y = rect.y + rect.h - sz, .w = sz, .h = sz };
            ctx.mu_update_control(iid, r, opt);
            if (id == ctx.focus and ctx.mouse_down == .left) {
                cnt.rect.w = @max(96, cnt.rect.w + ctx.mouse_delta[0]);
                cnt.rect.h = @max(64, cnt.rect.h + ctx.mouse_delta[1]);
            }
        }

        // resize to content size
        if (opt.autosize) {
            const r = ctx.getLayout().body;
            cnt.rect.w = cnt.content_size[0] + (cnt.rect.w - r.w);
            cnt.rect.h = cnt.content_size[1] + (cnt.rect.h - r.h);
        }

        if (opt.popup and ctx.mouse_pressed != .none and ctx.hover_root != cnt) {
            cnt.open = 0;
        }

        ctx.mu_push_clip_rect(cnt.body);

        return true;
    }

    pub fn mu_end_window(ctx: *Self) void {
        ctx.mu_pop_clip_rect();
        ctx.endRootContainer();
    }

    pub fn mu_open_popup(ctx: *Self, name: []const u8) void {
        const cnt = ctx.mu_get_container(name);
        ctx.hover_root = cnt;
        ctx.next_hover_root = cnt;
        cnt.rect = .{ .x = ctx.mouse_pos[0], .y = ctx.mouse_pos[1], .w = 1, .h = 1 };
        cnt.open = 1;
        ctx.mu_bring_to_front(cnt);
    }

    pub fn mu_begin_popup(ctx: *Self, name: []const u8) bool {
        return ctx.beginWindowEx(name, .{}, .{
            .popup = true,
            .autosize = true,
            .noresize = true,
            .noscroll = true,
            .notitle = true,
            .closed = true,
        });
    }

    pub fn mu_end_popup(ctx: *Self) void {
        ctx.mu_end_window();
    }

    pub fn mu_begin_panel_ex(ctx: *Self, name: []const u8, opt: Opt) void {
        ctx.pushId(name);
        const cnt = ctx.getContainerInit(ctx.last_id, opt) orelse unreachable;
        cnt.rect = ctx.mu_layout_next();

        if (!opt.noframe) {
            ctx.drawFrame(cnt.rect, .panel_bg);
        }

        ctx.container_stack.push(cnt);
        ctx.pushContainerBody(cnt, cnt.rect, opt);
        ctx.mu_push_clip_rect(cnt.body);
    }

    pub fn mu_end_panel(ctx: *Self) void {
        ctx.mu_pop_clip_rect();
        ctx.popContainer();
    }

    // internals

    fn getContainerInit(ctx: *Self, id: Id, opt: Opt) ?*Container {
        const maybe_idx = ctx.container_pool.get(id);
        if (maybe_idx) |idx| {
            if (ctx.containers[idx].open != 0 or !opt.closed) {
                ctx.container_pool.update(idx, ctx.frame);
            }
            return &ctx.containers[idx];
        }

        if (opt.closed) return null;

        // container not found in pool, init new container
        const idx = ctx.container_pool.init(ctx.frame, id);
        const cnt = &ctx.containers[idx];
        cnt.* = .{
            .head_idx = 0xFFFF_FFFF,
            .tail_idx = 0xFFFF_FFFF,
            .open = 1,
        };

        ctx.mu_bring_to_front(cnt);
        return cnt;
    }

    fn beginRootContainer(ctx: *Self, cnt: *Container) void {
        ctx.container_stack.push(cnt);
        ctx.root_list.push(cnt);

        cnt.head_idx = ctx.command_list.len;
        if (cnt.rect.overlaps(ctx.mouse_pos) and (ctx.next_hover_root == null or cnt.zindex > ctx.next_hover_root.?.zindex)) {
            ctx.next_hover_root = cnt;
        }

        ctx.clip_stack.push(Rect.unclipped);
    }

    fn pushContainerBody(ctx: *Self, cnt: *Container, body: Rect, opt: Opt) void {
        var size = body;
        if (!opt.noscroll) ctx.scrollbars(cnt, &size);
        ctx.pushLayout(size.expand(-ctx.style.padding), cnt.scroll);
        cnt.body = size;
    }

    fn pushLayout(ctx: *Self, body: Rect, scroll: Vec2) void {
        const layout = Layout{
            .body = .{ .x = body.x - scroll[0], .y = body.y - scroll[1], .w = body.w, .h = body.h },
            .max = .{ -0x1000000, -0x1000000 },
        };
        ctx.layout_stack.push(layout);
        ctx.mu_layout_row(1, null, 0);
    }

    fn scrollbars(ctx: *Self, cnt: *Container, body: *Rect) void {
        const sz = ctx.style.scrollbar_size;
        var cs = cnt.content_size;
        cs[0] += ctx.style.padding * 2;
        cs[1] += ctx.style.padding * 2;
        ctx.mu_push_clip_rect(body.*);

        // resize body to make space for scrollbars
        if (cs[1] > cnt.body.h) body.w -= sz;
        if (cs[0] > cnt.body.w) body.h -= sz;

        ctx.scrollbarVertical(cnt, body, cs);
        ctx.scrollbarHorizontal(cnt, body, cs);
        ctx.mu_pop_clip_rect();
    }

    // to create a horizontal or vertical scrollbar almost-identical code is used;
    // only the references to `x|y` `w|h` need to be switched
    fn scrollbarVertical(ctx: *Self, cnt: *Container, b: *Rect, cs: Vec2) void {
        // only add scrollbar if content size is larger than body
        const maxscroll = cs[1] - b.h;

        if (maxscroll > 0 and b.h > 0) {
            const id = ctx.getId("!scrollbar_y");

            // get sizing / positioning
            var base = b.*;
            base.x = b.x + b.w;
            base.w = ctx.style.scrollbar_size;

            // handle input
            ctx.mu_update_control(id, base, .{});
            if (ctx.focus == id and ctx.mouse_down == .left) {
                cnt.scroll[1] += @divTrunc(ctx.mouse_delta[1] * cs[1], base.h);
            }
            // clamp scroll to limits
            cnt.scroll[1] = std.math.clamp(cnt.scroll[1], 0, maxscroll);

            // draw base and thumb
            ctx.drawFrame(base, .scroll_base);
            var thumb = base;
            thumb.h = @max(ctx.style.thumb_size, @divTrunc(base.h * b.h, cs[1]));
            thumb.y += @divTrunc(cnt.scroll[1] * (base.h - thumb.h), maxscroll);
            ctx.drawFrame(thumb, .scroll_thumb);

            // set this as the scroll_target (will get scrolled on mousewheel)
            // if the mouse is over it
            if (ctx.mu_mouse_over(b.*)) ctx.scroll_target = cnt;
        } else {
            cnt.scroll[1] = 0;
        }
    }

    fn scrollbarHorizontal(ctx: *Self, cnt: *Container, b: *Rect, cs: Vec2) void {
        // only add scrollbar if content size is larger than body
        const maxscroll = cs[0] - b.w;

        if (maxscroll > 0 and b.w > 0) {
            const id = ctx.getId("!scrollbar_x");

            // get sizing / positioning
            var base = b.*;
            base.y = b.y + b.h;
            base.h = ctx.style.scrollbar_size;

            // handle input
            ctx.mu_update_control(id, base, .{});
            if (ctx.focus == id and ctx.mouse_down == .left) {
                cnt.scroll[0] += @divTrunc(ctx.mouse_delta[0] * cs[0], base.w);
            }
            // clamp scroll to limits
            cnt.scroll[0] = std.math.clamp(cnt.scroll[0], 0, maxscroll);

            // draw base and thumb
            ctx.drawFrame(base, .scroll_base);
            var thumb = base;
            thumb.w = @max(ctx.style.thumb_size, @divTrunc(base.w * b.w, cs[0]));
            thumb.x += @divTrunc(cnt.scroll[0] * (base.w - thumb.w), maxscroll);
            ctx.drawFrame(thumb, .scroll_thumb);

            // set this as the scroll_target (will get scrolled on mousewheel)
            // if the mouse is over it
            if (ctx.mu_mouse_over(b.*)) ctx.scroll_target = cnt;
        } else {
            cnt.scroll[0] = 0;
        }
    }

    fn getLayout(ctx: *Self) *Layout {
        return ctx.layout_stack.last();
    }

    fn endRootContainer(ctx: *Self) void {
        const cnt = ctx.mu_get_current_container();
        cnt.tail_idx = ctx.command_list.len;
        ctx.mu_pop_clip_rect();
        ctx.popContainer();
    }

    fn popContainer(ctx: *Self) void {
        const cnt = ctx.mu_get_current_container();
        const layout = ctx.getLayout();
        cnt.content_size[0] = layout.max[0] - layout.body.x;
        cnt.content_size[1] = layout.max[1] - layout.body.y;
        ctx.container_stack.pop();
        ctx.layout_stack.pop();
        ctx.popId();
    }

    fn headerImpl(ctx: *Self, label: []const u8, isTreeNode: bool, opt: Opt) bool {
        const id = ctx.getId(label);
        const idx = ctx.treenode_pool.get(id);

        ctx.mu_layout_row(1, &.{-1}, 0);

        var active = idx != null;
        const expanded = if (opt.expanded) !active else active;
        var r = ctx.mu_layout_next();
        ctx.mu_update_control(id, r, .{});

        // handle click
        active = active != (ctx.mouse_pressed == .left and ctx.focus == id);

        // update pool ref
        if (idx) |i| {
            if (active) {
                ctx.treenode_pool.update(i, ctx.frame);
            } else {
                ctx.treenode_pool.buffer[i] = .{};
            }
        } else if (active) {
            _ = ctx.treenode_pool.init(ctx.frame, id);
        }

        // draw
        if (isTreeNode) {
            if (ctx.hover == id) ctx.drawFrame(r, .button_hover);
        } else {
            ctx.mu_draw_control_frame(id, r, .button, .{});
        }

        ctx.mu_draw_icon(if (expanded) .expanded else .collapsed, .{ .x = r.x, .y = r.y, .w = r.h, .h = r.h }, ctx.style.colors.get(.text));
        r.x += r.h - ctx.style.padding;
        r.w -= r.h - ctx.style.padding;
        ctx.mu_draw_control_text(label, r, .text, .{});

        return expanded;
    }

    fn drawFrame(ctx: *Self, rect: Rect, color: StyleColor) void {
        ctx.mu_draw_rect(rect, ctx.style.colors.get(color));
        if (color == .scroll_base or color == .scroll_thumb or color == .title_bg) return;

        // draw border
        if (ctx.style.colors.get(.border).a != 0) {
            ctx.mu_draw_box(rect.expand(1), ctx.style.colors.get(.border));
        }
    }

    fn inHoverRoot(ctx: *Self) bool {
        if (ctx.hover_root) |root| {
            const len = ctx.container_stack.len;
            for (0..len) |i| {
                if (ctx.container_stack.buffer[len - i - 1] == root) return true;
                if (ctx.container_stack.buffer[len - i - 1].head_idx != 0xFFFF_FFFF) break;
            }
        }

        return false;
    }
};

fn Stack(comptime T: type, comptime size: comptime_int) type {
    return struct {
        const Self = @This();

        buffer: [size]T = undefined,
        len: u32 = 0,

        pub fn push(self: *Self, val: T) void {
            self.buffer[self.len] = val;
            self.len += 1;
        }

        pub fn peek(self: *const Self) ?T {
            return if (self.len == 0) null else self.buffer[self.len - 1];
        }

        pub fn last(self: *Self) *T {
            return &self.buffer[self.len - 1];
        }

        pub fn pop(self: *Self) void {
            self.len -= 1;
        }

        pub fn slice(self: *Self) []T {
            return self.buffer[0..self.len];
        }

        pub fn constSlice(self: *const Self) []const T {
            return self.buffer[0..self.len];
        }
    };
}

fn Pool(comptime size: comptime_int) type {
    return struct {
        const Self = @This();

        buffer: [size]PoolItem = undefined,

        fn init(self: *Self, frame: i32, id: Id) usize {
            var n: u32 = 0xFFFF_FFFF;
            var f = frame;
            for (0..size) |i| {
                if (self.buffer[i].last_update < f) {
                    f = self.buffer[i].last_update;
                    n = @truncate(i);
                }
            }

            assert(n != 0xFFFF_FFFF);
            self.buffer[n] = .{ .id = id, .last_update = frame };
            return n;
        }

        fn get(self: *Self, id: Id) ?usize {
            for (0..size) |i| {
                if (self.buffer[i].id == id) return i;
            }
            return null;
        }

        fn update(self: *Self, idx: usize, frame: i32) void {
            self.buffer[idx].last_update = frame;
        }
    };
}
