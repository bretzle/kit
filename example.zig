const std = @import("std");
const kit = @import("kit");
const Color = kit.RGBA;
const Vec2 = kit.math.Vec2;

const MyApp = kit.App(.{
    .context = Game,
    .color = Color,
    .width = 320,
    .height = 470,
    .enable_gui = true,
});

const Game = struct {
    checks: [3]bool = .{ true, false, true },
    bg: [3]u8 = .{ 0x87, 0x50, 0x7F },

    pub fn create() !Game {
        return .{};
    }

    pub fn update(self: *Game, g: *kit.Gui) void {
        g.begin();
        defer g.end();

        if (g.beginWindowEx("Demo Window", .{ .pos = .{ 10, 10 }, .size = .{ 300, 450 } }, .{})) {
            defer g.endWindow();

            const win = g.getCurrentContainer();
            win.rect.size = @max(win.rect.size, Vec2{ 240, 300 });

            // window info
            if (g.mu_header_ex("Window Info", .{})) {
                const cnt = g.getCurrentContainer();
                var buf: [64]u8 = undefined;

                g.mu_layout_row(2, &.{ 62, -1 }, 0);
                g.mu_label("Position:");
                g.mu_label(std.fmt.bufPrint(&buf, "{any}", .{cnt.rect.pos}) catch unreachable);
                g.mu_label("Size:");
                g.mu_label(std.fmt.bufPrint(&buf, "{any}", .{cnt.rect.size}) catch unreachable);
            }

            // labels + buttons
            if (g.mu_header_ex("Test Buttons", .{ .expanded = true })) {
                g.mu_layout_row(3, &.{ 86, -110, -1 }, 0);
                g.mu_label("Test buttons 1:");
                if (g.mu_button("Button 1")) std.debug.print("Pressed button 1\n", .{});
                if (g.mu_button("Button 2")) std.debug.print("Pressed button 2\n", .{});
                g.mu_label("Test buttons 2:");
                if (g.mu_button("Button 3")) std.debug.print("Pressed button 3\n", .{});
                if (g.mu_button("Popup")) g.openPopup("Test Popup");

                if (g.beginPopup("Test Popup")) {
                    defer g.endPopup();
                    _ = g.mu_button("Hello");
                    _ = g.mu_button("World");
                }
            }

            // tree
            if (g.mu_header_ex("Tree and Text", .{ .expanded = true })) {
                g.mu_layout_row(2, &.{ 140, -1 }, 0);
                g.mu_layout_begin_column();
                if (g.mu_begin_treenode_ex("Test 1", .{})) {
                    if (g.mu_begin_treenode_ex("Test 1a", .{})) {
                        g.mu_label("Hello");
                        g.mu_label("world");
                        g.mu_end_treenode();
                    }
                    if (g.mu_begin_treenode_ex("Test 1b", .{})) {
                        if (g.mu_button_ex("Button 1", 0, .{})) std.debug.print("Pressed button 1\n", .{});
                        if (g.mu_button_ex("Button 2", 0, .{})) std.debug.print("Pressed button 2\n", .{});
                        g.mu_end_treenode();
                    }
                    g.mu_end_treenode();
                }
                if (g.mu_begin_treenode_ex("Test 2", .{})) {
                    g.mu_layout_row(2, &.{ 54, 54 }, 0);
                    if (g.mu_button_ex("Button 3", 0, .{})) std.debug.print("Pressed button 3\n", .{});
                    if (g.mu_button_ex("Button 4", 0, .{})) std.debug.print("Pressed button 4\n", .{});
                    if (g.mu_button_ex("Button 5", 0, .{})) std.debug.print("Pressed button 5\n", .{});
                    if (g.mu_button_ex("Button 6", 0, .{})) std.debug.print("Pressed button 6\n", .{});
                    g.mu_end_treenode();
                }
                if (g.mu_begin_treenode_ex("Test 3", .{})) {
                    _ = g.mu_checkbox("Checkbox 1", &self.checks[0]);
                    _ = g.mu_checkbox("Checkbox 2", &self.checks[1]);
                    _ = g.mu_checkbox("Checkbox 3", &self.checks[2]);
                    g.mu_end_treenode();
                }
                g.mu_layout_end_column();

                g.mu_layout_begin_column();
                g.mu_layout_row(1, &.{-1}, 0);
                g.mu_text("Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas lacinia, sem eu lacinia molestie, mi risus faucibus ipsum, eu varius magna felis a nulla.");
                g.mu_layout_end_column();
            }

            // background color sliders
            if (g.mu_header_ex("Background Color", .{ .expanded = true })) {
                g.mu_layout_row(2, &.{ -78, -1 }, 74);

                // sliders
                g.mu_layout_begin_column();
                g.mu_layout_row(2, &.{ 46, -1 }, 0);
                g.mu_label("Red:");
                _ = g.mu_slider(u8, &self.bg[0], 0, 255);
                g.mu_label("Green:");
                _ = g.mu_slider(u8, &self.bg[1], 0, 255);
                g.mu_label("Blue:");
                _ = g.mu_slider(u8, &self.bg[2], 0, 255);
                g.mu_layout_end_column();

                // color preview
                const r = g.mu_layout_next();
                g.drawRect(r, .{ .r = self.bg[0], .g = self.bg[1], .b = self.bg[2], .a = 255 });
                var buf: [7]u8 = undefined;
                const text = std.fmt.bufPrint(&buf, "#{X:0>2}{X:0>2}{X:0>2}", .{ self.bg[0], self.bg[1], self.bg[2] }) catch unreachable;
                g.drawControlText(text, r, .text, .{ .aligncenter = true });
            }
        }
    }

    pub fn render(_: *Game, _: []Color) void {}

    pub fn destroy(_: *Game) void {}
};

pub fn main() !void {
    try MyApp.start(.{ .title = "example" });
}
