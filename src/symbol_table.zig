const std = @import("std");

pub const SymbolTable = struct {
    table: std.StringArrayHashMap(usize),
    symbols: std.ArrayList([]const u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .table = std.StringArrayHashMap(usize).init(allocator),
            .symbols = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn getOrPut(self: *Self, symbol: []const u8) !usize {
        if (self.table.get(symbol)) |index| {
            return index;
        }
        const index = self.symbols.items.len;
        try self.table.put(symbol, index);
        try self.symbols.append(symbol);
        return index;
    }

    pub fn deinit(self: *Self) void {
        self.table.deinit();
        self.symbols.deinit();
        self.* = undefined;
    }
};
