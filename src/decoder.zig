const std = @import("std");
const Field = std.builtin.Type.StructField;

//////////////////////////////////////////////////////////////////////////////////////////

// Things to add
// - [ ] compile checks/errors
// - [ ] check that patterns are valid hashes
// - [ ] prevent executing instructions not covered
// - [ ] move to standalone library and genericize (CPU -> Context) (possible to have no context?)
// - [ ] better names + docs

// Things to investigate
// - [ ] constants instead of fields?
// - [ ] does alignment matter?
// - [ ] figure out how to verify decoder works...
// - [ ] eval quota
// - [ ] building hash fns from given mask
// - [ ] non-comptime arguments

//////////////////////////////////////////////////////////////////////////////////////////

fn Options(comptime desc: anytype) type {
    const Desc = @TypeOf(desc);
    const info = @typeInfo(Desc).Struct;

    const options = desc.options;
    const T = std.meta.Int(.unsigned, info.fields[1].name.len);

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
        fields: []const Field = info.fields[1..],

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
            var ret: options.Lut = undefined;

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
