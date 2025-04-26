const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Symbol = struct {
    tag: Tag,
    label: []const u8,

    pub const Tag = enum {
        terminal,
        non_terminal,
    };
};

const SymbolContext = struct {
    const Self = @This();

    pub fn hash(_: Self, key: Symbol) u32 {
        var hasher = std.hash.XxHash32.init(0);
        hasher.update(key.label);
        hasher.update(std.mem.asBytes(&key.tag));
        return hasher.final();
    }

    pub fn eql(_: Self, a: Symbol, b: Symbol, _: usize) bool {
        return std.array_hash_map.eqlString(a.label, b.label) and a.tag == b.tag;
    }
};

pub const SymbolTable = struct {
    allocator: Allocator,
    map: std.ArrayHashMap(Symbol, u32, SymbolContext, true),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .map = std.ArrayHashMap(Symbol, u32, SymbolContext, true).init(allocator),
        };
    }

    /// Inserts the symbol in the table if it doesn't exist and returns its ID.
    pub fn intern(self: *Self, symbol: Symbol) !u32 {
        const result = try self.map.getOrPut(symbol);
        if (!result.found_existing) {
            result.value_ptr.* = @intCast(self.map.count() - 1);
        }
        return result.value_ptr.*;
    }

    /// Extracts and returns all symbols as a slice, consuming the table.
    pub fn demote(self: *Self) ![]Symbol {
        const ret = self.allocator.dupe(Symbol, self.map.keys());
        self.deinit();
        return ret;
    }

    fn deinit(self: *Self) void {
        self.map.deinit();
        self.* = undefined;
    }
};
