const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Symbol = struct {
    tag: Tag,
    label: []const u8,

    const Tag = enum {
        terminal,
        non_terminal,
    };
};

const SymbolContext = struct {
    const Self = @This();

    pub fn hash(_: Self, key: Symbol) u32 {
        return std.array_hash_map.hashString(key.label);
    }

    pub fn eql(_: Self, a: Symbol, b: Symbol, _: usize) bool {
        return std.array_hash_map.eqlString(a.label, b.label);
    }
};

pub const SymbolTable = struct {
    map: std.ArrayHashMap(Symbol, u32, SymbolContext, true),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .map = std.ArrayHashMap(Symbol, u32, SymbolContext, true).init(allocator),
        };
    }

    pub fn getOrPut(self: *Self, symbol: Symbol) !u32 {
        const result = try self.map.getOrPut(symbol);
        if (!result.found_existing) {
            result.value_ptr.* = @intCast(self.map.count());
        }
        return result.value_ptr.*;
    }

    pub fn deinit(self: *Self) void {
        self.map.deinit();
        self.* = undefined;
    }
};
