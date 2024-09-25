const std = @import("std");
const builtin = @import("builtin");

pub const Level = enum {
    trace,
    debug,
    info,
    warn,
    err,
    fatal,

    const string = [_][]const u8{ "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL" };
    const colors = [_][]const u8{ "\x1b[94m", "\x1b[36m", "\x1b[32m", "\x1b[33m", "\x1b[31m", "\x1b[35m" };
};

pub usingnamespace scoped(._);
pub fn scoped(comptime scope: @Type(.EnumLiteral)) type {
    return struct {
        pub fn trace(comptime fmt: []const u8, args: anytype) void {
            log(.trace, scope, fmt, args);
        }

        pub fn debug(comptime fmt: []const u8, args: anytype) void {
            log(.debug, scope, fmt, args);
        }

        pub fn info(comptime fmt: []const u8, args: anytype) void {
            log(.info, scope, fmt, args);
        }

        pub fn warn(comptime fmt: []const u8, args: anytype) void {
            log(.warn, scope, fmt, args);
        }

        pub fn err(comptime fmt: []const u8, args: anytype) void {
            log(.err, scope, fmt, args);
        }

        pub fn fatal(comptime fmt: []const u8, args: anytype) void {
            log(.fatal, scope, fmt, args);
            std.process.exit(1);
        }
    };
}

var lock: std.Thread.Mutex = .{};

fn log(comptime lvl: Level, comptime scope: @Type(.EnumLiteral), comptime fmt: []const u8, args: anytype) void {
    const clevel = std.fmt.comptimePrint("{s}{s:<5} ", .{
        Level.colors[@intFromEnum(lvl)],
        Level.string[@intFromEnum(lvl)],
    });

    const cscope = if (scope != ._) std.fmt.comptimePrint("{s}{s}{s}", .{
        "\x1b[90m",
        @tagName(scope),
        "\x1b[0m ",
    }) else "\x1b[0m";

    const stdout = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout);
    const writer = bw.writer();

    lock.lock();
    defer lock.unlock();
    nosuspend {
        writer.print(clevel ++ cscope ++ fmt ++ "\n", args) catch return;
        bw.flush() catch return;
    }
}
