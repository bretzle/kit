const std = @import("std");
const util = @import("util.zig");
const Field = std.builtin.Type.StructField;

//////////////////////////////////////////////////////////////////////////////////////////

// Things to add
// - [ ] check that patterns are valid hashes
// - [ ] prevent executing instructions not covered

// Things to investigate
// - [ ] eval quota
// - [ ] building hash fns from given mask
// - [ ] non-comptime arguments

//////////////////////////////////////////////////////////////////////////////////////////

fn Options(comptime desc: anytype) type {
    comptime validateDesc(desc);

    const options = desc.options;
    const handlers = @typeInfo(@TypeOf(desc.handlers)).Struct.fields;
    const T = std.meta.Int(.unsigned, handlers[0].name.len);

    const defaults = struct {
        /// instruction -> index
        fn hash(data: T) T {
            return data;
        }

        /// index -> instruction
        fn dehash(data: T) T {
            return data;
        }
    };

    return struct {
        T: type = T,
        Handler: type = options.handler,
        Fn: type = @typeInfo(options.handler).Pointer.child,
        Lut: type = [options.size]options.handler,
        Cpu: type = @typeInfo(@typeInfo(options.handler).Pointer.child).Fn.params[0].type.?,
        fields: []const Field = handlers,

        hash: fn (T) T = if (@hasDecl(options, "hash")) options.hash else defaults.hash,
        dehash: fn (T) T = if (@hasDecl(options, "dehash")) options.dehash else defaults.dehash,
    };
}

pub fn decode(comptime desc: anytype) type {
    const options = Options(desc){};

    const casks = buildCasks(options.fields){};

    const inner = struct {
        fn run() options.Lut {
            @setEvalBranchQuota(0x69696969);
            var ret: options.Lut = .{unknown} ** desc.options.size;

            var sorted = std.meta.fieldNames(@TypeOf(casks)).*;
            std.mem.sort([:0]const u8, &sorted, {}, compare);

            for (&ret, 0..) |*handler, idx| {
                for (sorted) |name| {
                    const cask = @field(casks, name);
                    const instruction = options.dehash(idx);
                    if (idx & options.hash(cask.mask) == options.hash(cask.expect)) {
                        handler.* = construct(instruction, cask.pattern, cask.generator);
                        break;
                    }
                }
            }

            return ret;
        }

        fn unknown(_: options.Cpu) (@typeInfo(std.meta.Child(options.Handler)).Fn.return_type orelse void) {
            @breakpoint();
            unreachable;
        }

        fn compare(_: void, lhs: []const u8, rhs: []const u8) bool {
            const left = @field(casks, lhs);
            const right = @field(casks, rhs);
            return @popCount(left.mask) > @popCount(right.mask);
        }

        fn construct(instruction: usize, pattern: []const u8, comptime f: anytype) options.Handler {
            if (@TypeOf(f) == options.Fn) return f;

            const GenT = @TypeOf(f);
            const GenInfo = @typeInfo(GenT).Fn;

            const arg_count = GenInfo.params.len - 1;
            const arg_info = ArgInfo.parse(pattern, arg_count);

            var params: [arg_count]Field = undefined;

            for (0..arg_count) |idx| {
                const mask = arg_info.masks[idx];
                const shift = arg_info.shifts[idx];
                const value = (instruction & mask) >> shift;

                const T = GenInfo.params[idx + 1].type.?;
                const converted: T = switch (@typeInfo(T)) {
                    .Bool => value != 0,
                    .Int => @truncate(value),
                    .Enum => @enumFromInt(value),
                    else => @compileError("unsupported param type: " ++ @typeName(T)),
                };

                params[idx] = .{
                    .name = std.fmt.comptimePrint("{d}", .{idx}),
                    .type = T,
                    .default_value = &converted,
                    .is_comptime = true,
                    .alignment = @alignOf(T),
                };
            }

            const args = @Type(.{ .Struct = .{
                .layout = .auto,
                .fields = &params,
                .decls = &.{},
                .is_tuple = true,
            } });

            return struct {
                fn impl(cpu: options.Cpu) void {
                    @call(.auto, f, .{cpu} ++ args{});
                }
            }.impl;
        }
    };

    return struct {
        const lut: options.Lut = inner.run();

        pub inline fn get(instr: options.T) options.Handler {
            return lut[options.hash(instr)];
        }
    };
}

fn buildCasks(comptime fields: []const Field) type {
    comptime var casks: []const Field = &.{};

    for (fields) |field| {
        comptime var mask: u32 = 0;
        comptime var expect: u32 = 0;

        for (field.name, 0..) |c, idx| {
            if (c == '0' or c == '1') mask |= 1 << (field.name.len - idx - 1);
            if (c == '1') expect |= 1 << (field.name.len - idx - 1);
        }

        const T = struct {
            pattern: []const u8 = field.name,
            generator: field.type = @as(*const field.type, @ptrCast(field.default_value.?)).*,
            mask: u32 = mask,
            expect: u32 = expect,
        };

        casks = casks ++ &[_]Field{.{
            .name = field.name,
            .type = T,
            .default_value = &T{},
            .is_comptime = true,
            .alignment = 1,
        }};
    }

    return @Type(.{ .Struct = .{
        .layout = .auto,
        .fields = casks,
        .decls = &.{},
        .is_tuple = false,
    } });
}

const ArgInfo = struct {
    masks: []const u32,
    shifts: []const u6,

    fn parse(pattern: []const u8, arg_count: usize) ArgInfo {
        comptime var masks = [_]u32{0} ** arg_count;
        comptime var shifts = [_]u6{0} ** arg_count;

        var arg_idx = 0;
        var ch = 0;

        for (pattern, 0..) |c, idx| {
            if (c == '0' or c == '1' or c == '-') {
                if (ch != 0) {
                    ch = 0;
                    arg_idx += 1;
                }
            } else {
                if (ch == 0) {
                    ch = c;
                } else if (ch != c) {
                    ch = c;
                    arg_idx += 1;
                }

                if (arg_count > 0) {
                    const pos = pattern.len - idx - 1;
                    if (arg_idx >= arg_count) @compileError("unexpected field: " ++ &[_]u8{c} ++ " in '" ++ pattern ++ "'");
                    masks[arg_idx] |= 1 << pos;
                    shifts[arg_idx] = pos;
                } else {
                    @compileError("unexpected field");
                }
            }
        }

        return .{ .masks = &masks, .shifts = &shifts };
    }
};

fn validateDesc(comptime desc: anytype) void {
    const Desc = @TypeOf(desc);

    util.compileAssert(@hasField(Desc, "options"), "missing options", .{});
    util.compileAssert(@typeInfo(desc.options) == .Struct, "options should be a struct type", .{});
    const options = desc.options;

    util.compileAssert(@hasDecl(options, "handler"), "missing handler", .{});
    util.compileAssert(@typeInfo(options.handler) == .Pointer, "handler should be a pointer", .{});
    util.compileAssert(@typeInfo(std.meta.Child(options.handler)) == .Fn, "handler should be a pointer to a function", .{});

    util.compileAssert(@hasDecl(options, "size"), "options requires a size", .{});
    util.compileAssert(@TypeOf(options.size) == comptime_int, "options.size should be `comptime_int` not `{s}`", .{@typeName(@TypeOf(options.size))});

    inline for ([2][]const u8{ "hash", "dehash" }) |name| {
        if (@hasDecl(options, name)) {
            util.compileAssert(@typeInfo(@TypeOf(@field(options, name))) == .Fn, "options.{s} must be a func", .{name});
        }
    }

    util.compileAssert(@hasField(Desc, "handlers"), "missing handlers struct", .{});
    const handlers = desc.handlers;
    util.compileAssert(@typeInfo(@TypeOf(handlers)) == .Struct, "handlers must be a struct", .{});
    const fields = @typeInfo(@TypeOf(desc.handlers)).Struct.fields;
    util.compileAssert(fields.len > 0, "there must be at least 1 handler", .{});

    const handler = options.handler;
    const bit_size = fields[0].name.len;
    for (fields, 0..) |field, idx| {
        const info = @typeInfo(field.type);
        util.compileAssert(field.name.len == bit_size, "handlers must be the same size ([{d} {s}]) is {d} bits, expected {d} bits", .{ idx, field.name, field.name.len, bit_size });
        util.compileAssert(
            field.type == handler or field.type == std.meta.Child(handler) or info == .Fn,
            "handler ([{d}] {s}) must be the same as `options.handler` or a func that returns `options.handler` got {s}",
            .{ idx, field.name, @typeName(field.type) },
        );
    }
}
