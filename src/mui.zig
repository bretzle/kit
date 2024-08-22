const std = @import("std");
const os = @import("os.zig");
const math = @import("math.zig");
const util = @import("util.zig");
const assert = std.debug.assert;

const Vec2 = math.Vec2;
const Rect = math.Rect;
const Color = math.Color;

pub const Style = @import("mui/style.zig");
pub const Input = @import("mui/input.zig");

const unclipped = Rect{ .w = 0x1000000, .h = 0x1000000 };

pub const Clip = enum { none, part, all };

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

pub const Id = enum(u32) {
    const initial: Id = @enumFromInt(2166136261);

    invalid = 0,
    _,
};

pub const Command = union(enum) {
    clip: struct { rect: Rect },
    rect: struct { rect: Rect, color: Color },
    text: struct { pos: Vec2, color: Color, str: []const u8 },
    icon: struct { rect: Rect, id: Icon, color: Color },
};

pub const CommandIter = struct {
    containers: []const *Container,
    commands: []const Command,
    offset: usize = 0,

    pub fn next(self: *CommandIter) ?Command {
        while (true) {
            if (self.containers.len == 0) return null;

            const cnt = self.containers[0];
            if (cnt.start + self.offset == cnt.end) {
                self.containers = self.containers[1..];
                self.offset = 0;
                continue;
            }

            self.offset += 1;
            return self.commands[cnt.start + self.offset - 1];
        }
    }
};

pub const Layout = struct {
    pub const Type = enum { none, relative, absolute };

    body: Rect = .{},
    next: Rect = .{},
    position: Vec2 = .{ 0, 0 },
    size: Vec2 = .{ 0, 0 },
    max: Vec2 = .{ 0, 0 },
    widths: std.BoundedArray(i32, 16) = .{},
    items: i32 = 0,
    item_index: i32 = 0,
    next_row: i32 = 0,
    next_type: Type = .none,
    indent: i32 = 0,
};

pub const Container = struct {
    rect: Rect = .{},
    body: Rect = .{},
    content_size: Vec2 = .{ 0, 0 },
    scroll: Vec2 = .{ 0, 0 },
    zindex: u32 = 0,
    open: bool = true,
    start: u32 = 0xFFFF_FFFF,
    end: u32 = 0xFFFF_FFFF,

    fn compare(_: void, lhs: *Container, rhs: *Container) bool {
        return lhs.zindex < rhs.zindex;
    }
};

pub const Context = struct {
    const Self = @This();

    var default_style = Style{};

    // callbacks
    textWidth: *const fn ([]const u8) i32 = undefined,
    textHeight: *const fn () i32 = undefined,

    // core state
    style: *Style = &default_style,
    hover: Id = .invalid,
    focus: Id = .invalid,
    last_id: Id = .invalid,
    last_rect: Rect = .{},
    last_zindex: u32 = 0,
    updated_focus: bool = false,
    frame: u32 = 0,
    hover_root: ?*Container = null,
    next_hover_root: ?*Container = null,
    scroll_target: ?*Container = null,
    number_edit_buf: [127]u8 = [_]u8{0} ** 127,
    number_edit: Id = .invalid,

    // stacks
    command_list: std.ArrayList(Command),
    root_list: std.ArrayList(*Container),
    container_stack: std.ArrayList(*Container),
    clip_stack: std.ArrayList(Rect),
    id_stack: std.ArrayList(Id),
    layout_stack: std.ArrayList(Layout),
    text_stack: std.BoundedArray(u8, 16384) = .{},

    // retained pools
    container_pool: util.Pool(Container, Id, 16) = undefined,
    treenode_pool: util.Pool(void, Id, 16) = undefined,

    // input state
    input: Input = .{},

    pub fn create(allocator: std.mem.Allocator, textHeight: *const fn () i32, textWidth: *const fn ([]const u8) i32) Self {
        return .{
            .textHeight = textHeight,
            .textWidth = textWidth,
            .command_list = std.ArrayList(Command).init(allocator),
            .root_list = std.ArrayList(*Container).init(allocator),
            .container_stack = std.ArrayList(*Container).init(allocator),
            .clip_stack = std.ArrayList(Rect).init(allocator),
            .id_stack = std.ArrayList(Id).init(allocator),
            .layout_stack = std.ArrayList(Layout).init(allocator),
        };
    }

    pub fn destroy(self: *Self) void {
        self.command_list.deinit();
        self.root_list.deinit();
        self.container_stack.deinit();
        self.clip_stack.deinit();
        self.id_stack.deinit();
        self.layout_stack.deinit();
    }

    pub fn begin(ctx: *Self) void {
        ctx.command_list.clearRetainingCapacity();
        ctx.root_list.clearRetainingCapacity();
        ctx.text_stack.len = 0;
        ctx.scroll_target = null;
        ctx.hover_root = ctx.next_hover_root;
        ctx.next_hover_root = null;
        ctx.input.mouse_delta = ctx.input.mouse_pos - ctx.input.last_mouse_pos;
        ctx.frame += 1;
    }

    pub fn end(ctx: *Self) void {
        // check stacks
        assert(ctx.container_stack.items.len == 0);
        assert(ctx.clip_stack.items.len == 0);
        assert(ctx.id_stack.items.len == 0);
        assert(ctx.layout_stack.items.len == 0);

        // handle scroll input
        if (ctx.scroll_target) |target| {
            target.scroll += ctx.input.scroll_delta;
        }

        // unset focus if focus id was not touched this frame
        if (!ctx.updated_focus) ctx.focus = .invalid;
        ctx.updated_focus = false;

        // bring hover root to front if mouse was pressed
        if (ctx.next_hover_root) |root| {
            if (ctx.input.mouse_pressed != .none and root.zindex < ctx.last_zindex and root.zindex >= 0) {
                ctx.bringToFront(root);
            }
        }

        // reset input state
        ctx.input.key_pressed = 0;
        ctx.input.text[0] = 0;
        ctx.input.mouse_pressed = .none;
        ctx.input.scroll_delta = .{ 0, 0 };
        ctx.input.last_mouse_pos = ctx.input.mouse_pos;

        // sort root containers by zindex
        std.mem.sort(*Container, ctx.root_list.items, {}, Container.compare);
    }

    pub fn pushCommand(self: *Self, cmd: Command) void {
        self.command_list.append(cmd) catch unreachable;
    }

    pub fn commands(self: *Self) CommandIter {
        return .{
            .containers = self.root_list.items,
            .commands = self.command_list.items,
        };
    }

    pub fn setFocus(ctx: *Self, id: Id) void {
        ctx.focus = id;
        ctx.updated_focus = true;
    }

    pub fn getId(ctx: *Self, data: []const u8) Id {
        const res = ctx.id_stack.getLastOrNull() orelse Id.initial;
        var hasher = std.hash.Fnv1a_32{ .value = @intFromEnum(res) };
        hasher.update(data);
        ctx.last_id = @enumFromInt(hasher.final());
        return ctx.last_id;
    }

    pub fn pushId(ctx: *Self, data: []const u8) void {
        ctx.id_stack.push(ctx.getId(data));
    }

    pub fn popId(ctx: *Self) void {
        _ = ctx.id_stack.pop();
    }

    pub fn pushClipRect(ctx: *Self, rect: Rect) void {
        const last = ctx.getClipRect();
        ctx.clip_stack.append(rect.intersect(last)) catch unreachable;
    }

    pub fn popClipRect(ctx: *Self) void {
        _ = ctx.clip_stack.pop();
    }

    pub fn getClipRect(ctx: *Self) Rect {
        return ctx.clip_stack.getLast();
    }

    pub fn checkClip(ctx: *Self, r: Rect) Clip {
        const cr = ctx.getClipRect();
        if (r.x > cr.x + cr.w or r.x + r.w < cr.x or r.y > cr.y + cr.h or r.y + r.h < cr.y) return .all;
        if (r.x >= cr.x and r.x + r.w <= cr.x + cr.w and r.y >= cr.y and r.y + r.h <= cr.y + cr.h) return .none;
        return .part;
    }

    pub fn getCurrentContainer(ctx: *Self) *Container {
        return ctx.container_stack.getLast();
    }

    pub fn getContainer(ctx: *Self, name: []const u8) *Container {
        const id = ctx.getId(name);
        return ctx.getContainerInit(id, .{}) orelse unreachable;
    }

    pub fn bringToFront(ctx: *Self, cnt: *Container) void {
        ctx.last_zindex += 1;
        cnt.zindex = ctx.last_zindex;
    }

    pub fn pushText(ctx: *Self, str: []const u8) []const u8 {
        const start = ctx.text_stack.len;
        ctx.text_stack.appendSliceAssumeCapacity(str);
        return ctx.text_stack.constSlice()[start..];
    }

    pub fn setClip(ctx: *Self, rect: Rect) void {
        ctx.pushCommand(.{ .clip = .{ .rect = rect } });
    }

    pub fn drawRect(ctx: *Self, rect: Rect, color: Color) void {
        const r = rect.intersect(ctx.getClipRect());
        if (r.w > 0 and r.h > 0) {
            ctx.pushCommand(.{ .rect = .{ .rect = r, .color = color } });
        }
    }

    pub fn drawBox(ctx: *Self, rect: Rect, color: Color) void {
        ctx.drawRect(.{ .x = rect.x + 1, .y = rect.y, .w = rect.w - 2, .h = 1 }, color);
        ctx.drawRect(.{ .x = rect.x + 1, .y = rect.y + rect.h - 1, .w = rect.w - 2, .h = 1 }, color);
        ctx.drawRect(.{ .x = rect.x, .y = rect.y, .w = 1, .h = rect.h }, color);
        ctx.drawRect(.{ .x = rect.x + rect.w - 1, .y = rect.y, .w = 1, .h = rect.h }, color);
    }

    pub fn drawText(ctx: *Self, str: []const u8, pos: Vec2, color: Color) void {
        const rect = Rect{ .x = pos[0], .y = pos[1], .w = ctx.textWidth(str), .h = ctx.textHeight() };

        const clipped = checkClip(ctx, rect);
        if (clipped == .all) return;
        if (clipped == .part) setClip(ctx, getClipRect(ctx));

        // add command
        const str_start = ctx.pushText(str);
        ctx.pushCommand(.{ .text = .{ .str = str_start, .pos = pos, .color = color } });

        // reset clipping if it was set
        if (clipped != .none) setClip(ctx, unclipped);
    }

    pub fn drawIcon(ctx: *Self, id: Icon, rect: Rect, color: Color) void {
        // do clip command if the rect isn't fully contained within the cliprect
        const clipped = ctx.checkClip(rect);
        if (clipped == .all) return;
        if (clipped == .part) ctx.setClip(ctx.getClipRect());

        // do icon command
        ctx.pushCommand(.{ .icon = .{ .id = id, .rect = rect, .color = color } });

        // reset clipping if it was set
        if (clipped != .none) ctx.setClip(unclipped);
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
        _ = ctx.layout_stack.pop();
        // inherit position/next_row/max from child layout if they are greater
        const a = ctx.getLayout();
        a.position[0] = @max(a.position[0], b.position[0] + b.body.x - a.body.x);
        a.next_row = @max(a.next_row, b.next_row + b.body.y - a.body.y);
        a.max[0] = @max(a.max[0], b.max[0]);
        a.max[1] = @max(a.max[1], b.max[1]);
    }

    pub fn mu_layout_set_next(ctx: *Self, r: Rect, next_type: Layout.Type) void {
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

    pub fn drawControlFrame(ctx: *Self, id: Id, rect: Rect, control: Style.Control, opt: Opt) void {
        if (opt.noframe) return;
        const color = @intFromEnum(control) + @as(u4, if (ctx.focus == id) 2 else if (ctx.hover == id) 1 else 0);
        ctx.drawFrame(rect, @enumFromInt(color));
    }

    pub fn drawControlText(ctx: *Self, str: []const u8, rect: Rect, control: Style.Control, opt: Opt) void {
        const tw = ctx.textWidth(str);
        ctx.pushClipRect(rect);
        const y = rect.y + @divFloor(rect.h - ctx.textHeight(), 2);
        const x = if (opt.aligncenter)
            rect.x + @divFloor(rect.w - tw, 2)
        else if (opt.alignright)
            rect.x + rect.w - tw - ctx.style.padding
        else
            rect.x + ctx.style.padding;

        ctx.drawText(str, .{ x, y }, ctx.style.colors.get(control));
        ctx.popClipRect();
    }

    pub fn mu_mouse_over(ctx: *Self, rect: Rect) bool {
        return rect.overlaps(ctx.input.mouse_pos) and ctx.getClipRect().overlaps(ctx.input.mouse_pos) and ctx.inHoverRoot();
    }

    pub fn updateControl(ctx: *Self, id: Id, rect: Rect, opt: Opt) void {
        const mouseover = ctx.mu_mouse_over(rect);

        if (ctx.focus == id) ctx.updated_focus = true;
        if (opt.nointeract) return;
        if (mouseover and ctx.input.mouse_down == .none) ctx.hover = id;

        if (ctx.focus == id) {
            if (ctx.input.mouse_pressed != .none and !mouseover) ctx.setFocus(.invalid);
            if (ctx.input.mouse_down == .none and !opt.holdfocus) ctx.setFocus(.invalid);
        }

        if (ctx.hover == id) {
            if (ctx.input.mouse_pressed != .none) {
                ctx.setFocus(id);
            } else if (!mouseover) {
                ctx.hover = .invalid;
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
            ctx.drawText(text[start_idx..end_idx], .{ r.x, r.y }, color);
            p = end_idx + 1;
        }

        ctx.mu_layout_end_column();
    }

    pub fn mu_label(ctx: *Self, text: []const u8) void {
        ctx.drawControlText(text, ctx.mu_layout_next(), .text, .{});
    }

    pub fn mu_button(ctx: *Self, label: []const u8) bool {
        return ctx.mu_button_ex(label, 0, .{ .aligncenter = true });
    }

    pub fn mu_button_ex(ctx: *Self, label: []const u8, icon: i32, opt: Opt) bool {
        // TODO icon
        _ = icon; // autofix
        const id = ctx.getId(label);
        const r = ctx.mu_layout_next();
        ctx.updateControl(id, r, opt);

        // handle click
        const clicked = ctx.input.mouse_pressed == .left and ctx.focus == id;

        // draw
        ctx.drawControlFrame(id, r, .button, opt);
        ctx.drawControlText(label, r, .text, opt);

        return clicked;
    }

    pub fn mu_checkbox(ctx: *Self, label: []const u8, state: *bool) Result {
        var result = Result{};
        const id = ctx.getId(std.mem.asBytes(&state));
        const r = ctx.mu_layout_next();
        const box = Rect{ .x = r.x, .y = r.y, .w = r.h, .h = r.h };
        ctx.updateControl(id, r, .{});

        // handle click
        if (ctx.input.mouse_pressed == .left and ctx.focus == id) {
            result.change = true;
            state.* = !state.*;
        }

        // draw
        ctx.drawControlFrame(id, box, .base, .{});
        if (state.*) ctx.drawIcon(.check, box, ctx.style.colors.get(.text));
        const rr = Rect{ .x = r.x + box.w, .y = r.y, .w = r.w - box.w, .h = r.h };
        ctx.drawControlText(label, rr, .text, .{});

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
        ctx.updateControl(id, base, opt);

        // handle input
        if (ctx.focus == id and (ctx.input.mouse_down == .left or ctx.input.mouse_pressed == .left)) {
            v = @divTrunc(low + (ctx.input.mouse_pos[0] - base.x) * (high - low), base.w);
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
        ctx.drawControlFrame(id, base, .base, opt);

        // draw thumb
        const w = ctx.style.thumb_size;
        const x = @divFloor((v - low) * (base.w - w), (high - low));
        const thumb = Rect{ .x = base.x + x, .y = base.y, .w = w, .h = base.h };
        ctx.drawControlFrame(id, thumb, .button, opt);

        // draw text
        var buf: [16]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, fmt, .{v}) catch unreachable;
        ctx.drawControlText(text, base, .text, opt);

        return result;
    }

    pub fn mu_number_ex(ctx: *Self, value: []f32, step: f32, fmt: []const u8, opt: i32) i32 {
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
            ctx.id_stack.append(ctx.last_id) catch unreachable;
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
        if (!cnt.open) return false;
        ctx.id_stack.append(id) catch unreachable;

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
                ctx.updateControl(iid, tr, opt);
                ctx.drawControlText(title, tr, .title_text, opt);
                if (iid == ctx.focus and ctx.input.mouse_down == .left) {
                    cnt.rect.x += ctx.input.mouse_delta[0];
                    cnt.rect.y += ctx.input.mouse_delta[1];
                }
                body.y += tr.h;
                body.h -= tr.h;
            }

            // close button
            if (!opt.noclose) {
                const iid = ctx.getId("!close");
                const r = Rect{ .x = tr.x + tr.w - tr.h, .y = tr.y, .w = tr.h, .h = tr.h };
                tr.w -= r.w;
                ctx.drawIcon(.close, r, ctx.style.colors.get(.title_text));
                ctx.updateControl(iid, r, opt);
                if (ctx.input.mouse_pressed == .left and iid == ctx.focus) {
                    cnt.open = false;
                }
            }
        }

        ctx.pushContainerBody(cnt, body, opt);

        // do resize handle
        if (!opt.noresize) {
            const sz = ctx.style.title_height;
            const iid = ctx.getId("!resize");
            const r = Rect{ .x = rect.x + rect.w - sz, .y = rect.y + rect.h - sz, .w = sz, .h = sz };
            ctx.updateControl(iid, r, opt);
            if (id == ctx.focus and ctx.input.mouse_down == .left) {
                cnt.rect.w = @max(96, cnt.rect.w + ctx.input.mouse_delta[0]);
                cnt.rect.h = @max(64, cnt.rect.h + ctx.input.mouse_delta[1]);
            }
        }

        // resize to content size
        if (opt.autosize) {
            const r = ctx.getLayout().body;
            cnt.rect.w = cnt.content_size[0] + (cnt.rect.w - r.w);
            cnt.rect.h = cnt.content_size[1] + (cnt.rect.h - r.h);
        }

        if (opt.popup and ctx.input.mouse_pressed != .none and ctx.hover_root != cnt) {
            cnt.open = false;
        }

        ctx.pushClipRect(cnt.body);

        return true;
    }

    pub fn endWindow(ctx: *Self) void {
        ctx.popClipRect();
        ctx.endRootContainer();
    }

    pub fn openPopup(ctx: *Self, name: []const u8) void {
        const cnt = ctx.getContainer(name);
        ctx.hover_root = cnt;
        ctx.next_hover_root = cnt;
        cnt.rect = .{ .x = ctx.input.mouse_pos[0], .y = ctx.input.mouse_pos[1], .w = 1, .h = 1 };
        cnt.open = true;
        ctx.bringToFront(cnt);
    }

    pub fn beginPopup(ctx: *Self, name: []const u8) bool {
        return ctx.beginWindowEx(name, .{}, .{
            .popup = true,
            .autosize = true,
            .noresize = true,
            .noscroll = true,
            .notitle = true,
            .closed = true,
        });
    }

    pub fn endPopup(ctx: *Self) void {
        ctx.endWindow();
    }

    pub fn beginPanelEx(ctx: *Self, name: []const u8, opt: Opt) void {
        ctx.pushId(name);
        const cnt = ctx.getContainerInit(ctx.last_id, opt) orelse unreachable;
        cnt.rect = ctx.mu_layout_next();

        if (!opt.noframe) {
            ctx.drawFrame(cnt.rect, .panel_bg);
        }

        ctx.container_stack.append(cnt) catch unreachable;
        ctx.pushContainerBody(cnt, cnt.rect, opt);
        ctx.pushClipRect(cnt.body);
    }

    pub fn endPanel(ctx: *Self) void {
        ctx.popClipRect();
        ctx.popContainer();
    }

    // internals

    fn getContainerInit(ctx: *Self, id: Id, opt: Opt) ?*Container {
        if (ctx.container_pool.get(id)) |val| {
            if (val.data.open or !opt.closed) {
                val.generation = ctx.frame;
            }
            return &val.data;
        }

        if (opt.closed) return null;

        // container not found in pool, init new container
        const cnt = ctx.container_pool.init(ctx.frame, id);
        cnt.* = .{};

        ctx.bringToFront(cnt);
        return cnt;
    }

    fn beginRootContainer(ctx: *Self, cnt: *Container) void {
        ctx.container_stack.append(cnt) catch unreachable;
        ctx.root_list.append(cnt) catch unreachable;

        cnt.start = @truncate(ctx.command_list.items.len);
        if (cnt.rect.overlaps(ctx.input.mouse_pos) and (ctx.next_hover_root == null or cnt.zindex > ctx.next_hover_root.?.zindex)) {
            ctx.next_hover_root = cnt;
        }

        ctx.clip_stack.append(unclipped) catch unreachable;
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
        ctx.layout_stack.append(layout) catch unreachable;
        ctx.mu_layout_row(1, null, 0);
    }

    fn scrollbars(ctx: *Self, cnt: *Container, body: *Rect) void {
        const sz = ctx.style.scrollbar_size;
        var cs = cnt.content_size;
        cs[0] += ctx.style.padding * 2;
        cs[1] += ctx.style.padding * 2;
        ctx.pushClipRect(body.*);

        // resize body to make space for scrollbars
        if (cs[1] > cnt.body.h) body.w -= sz;
        if (cs[0] > cnt.body.w) body.h -= sz;

        ctx.scrollbarVertical(cnt, body, cs);
        ctx.scrollbarHorizontal(cnt, body, cs);
        ctx.popClipRect();
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
            ctx.updateControl(id, base, .{});
            if (ctx.focus == id and ctx.input.mouse_down == .left) {
                cnt.scroll[1] += @divTrunc(ctx.input.mouse_delta[1] * cs[1], base.h);
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
            ctx.updateControl(id, base, .{});
            if (ctx.focus == id and ctx.input.mouse_down == .left) {
                cnt.scroll[0] += @divTrunc(ctx.input.mouse_delta[0] * cs[0], base.w);
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
        return &ctx.layout_stack.items[ctx.layout_stack.items.len - 1];
    }

    fn endRootContainer(ctx: *Self) void {
        const cnt = ctx.getCurrentContainer();
        cnt.end = @truncate(ctx.command_list.items.len);
        ctx.popClipRect();
        ctx.popContainer();
    }

    fn popContainer(ctx: *Self) void {
        const cnt = ctx.getCurrentContainer();
        const layout = ctx.getLayout();
        cnt.content_size[0] = layout.max[0] - layout.body.x;
        cnt.content_size[1] = layout.max[1] - layout.body.y;
        _ = ctx.container_stack.pop();
        _ = ctx.layout_stack.pop();
        ctx.popId();
    }

    fn headerImpl(ctx: *Self, label: []const u8, isTreeNode: bool, opt: Opt) bool {
        const id = ctx.getId(label);
        const node = ctx.treenode_pool.get(id);

        ctx.mu_layout_row(1, &.{-1}, 0);

        var active = node != null;
        const expanded = if (opt.expanded) !active else active;
        var r = ctx.mu_layout_next();
        ctx.updateControl(id, r, .{});

        // handle click
        active = active != (ctx.input.mouse_pressed == .left and ctx.focus == id);

        // update pool ref
        if (node) |i| {
            if (active) {
                i.generation = ctx.frame;
            } else {
                i.* = .{ .data = undefined };
            }
        } else if (active) {
            _ = ctx.treenode_pool.init(ctx.frame, id);
        }

        // draw
        if (isTreeNode) {
            if (ctx.hover == id) ctx.drawFrame(r, .button_hover);
        } else {
            ctx.drawControlFrame(id, r, .button, .{});
        }

        ctx.drawIcon(if (expanded) .expanded else .collapsed, .{ .x = r.x, .y = r.y, .w = r.h, .h = r.h }, ctx.style.colors.get(.text));
        r.x += r.h - ctx.style.padding;
        r.w -= r.h - ctx.style.padding;
        ctx.drawControlText(label, r, .text, .{});

        return expanded;
    }

    fn drawFrame(ctx: *Self, rect: Rect, color: Style.Control) void {
        ctx.drawRect(rect, ctx.style.colors.get(color));
        if (color == .scroll_base or color == .scroll_thumb or color == .title_bg) return;

        // draw border
        if (ctx.style.colors.get(.border).a != 0) {
            ctx.drawBox(rect.expand(1), ctx.style.colors.get(.border));
        }
    }

    fn inHoverRoot(ctx: *Self) bool {
        if (ctx.hover_root) |root| {
            const len = ctx.container_stack.items.len;
            for (0..len) |i| {
                if (ctx.container_stack.items[len - i - 1] == root) return true;
                if (ctx.container_stack.items[len - i - 1].start != 0xFFFF_FFFF) break;
            }
        }

        return false;
    }
};
