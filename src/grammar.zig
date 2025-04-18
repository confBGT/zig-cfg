const std = @import("std");
const Token = @import("tokenizer.zig").Token;
const Parser = @import("parser.zig").Parser;

pub const Production = struct {
    lhs: []const u8,
    rhs: [][]const u8,
};

pub const Grammar = struct {
    allocator: std.mem.Allocator,
    lhs_index: IndexMap,
    rhs_index: IndexMap,
    productions: std.ArrayList(Production),

    const Self = @This();
    const IndexMap = std.StringArrayHashMap(std.ArrayList(Production));
    // const IndexMap = std.StringArrayHashMap(std.ArrayList(*const Production));

    fn calculateIndexes(self: *Self) !void {
        for (self.productions.items) |prod| {
            const lhs_result = try self.lhs_index.getOrPut(prod.lhs);
            if (!lhs_result.found_existing) {
                // lhs_result.value_ptr.* = std.ArrayList(*const Production).init(self.allocator);
                lhs_result.value_ptr.* = std.ArrayList(Production).init(self.allocator);
            }
            try lhs_result.value_ptr.append(prod);

            for (prod.rhs) |rhs| {
                const rhs_result = try self.rhs_index.getOrPut(rhs);
                if (!rhs_result.found_existing) {
                    rhs_result.value_ptr.*=  std.ArrayList(Production).init(self.allocator);
                }
                try rhs_result.value_ptr.append(prod);
            }
        }
    }

    pub fn fromString(allocator: std.mem.Allocator, input: [:0]const u8) !Self {
        // parsing input grammar
        var productions = std.ArrayList(Production).init(allocator);
        errdefer {
            for (productions.items) |prod| {
                allocator.free(prod.rhs);
            }
            productions.deinit();
        }

        var parser = Parser.init(allocator, input);
        while (try parser.next()) |prod| {
            try productions.append(prod);
        }

        // initializing grammar instance
        var self = Self {
            .allocator = allocator,
            .lhs_index = IndexMap.init(allocator),
            .rhs_index = IndexMap.init(allocator),
            .productions = productions,
        };

        try self.calculateIndexes();
        return self;
    }

    pub fn foo(self: *Self) !void {
        for (self.productions.items) |prod| {
            if (prod.rhs.len <= 1) {
                return;
            }

            for (prod.rhs) |token| {
                if (token.tag == .terminal) {
                    const p = Production {
                        .lhs = undefined,
                        .rhs = token,
                    };

                    try self.productions.append(p);
                }
            }
        }
    }

    pub fn deinit(self: *Self) void {
        for (self.lhs_index.values()) |value| {
            value.deinit();
        }

        for (self.rhs_index.values()) |value| {
            value.deinit();
        }

        for (self.productions.items) |prod| {
            self.allocator.free(prod.rhs);
        }

        self.productions.deinit();
        self.lhs_index.deinit();
        self.rhs_index.deinit();
        self.* = undefined;
    }

    pub fn format(
        self: Self,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        // const start = if (self.start) |s| s.lhs else "N/A";
        const start = "N/A";

        try writer.print("Grammar with {d} productions (start = {string})\n", .{self.productions.items.len, start});
        for (self.productions.items, 0..) |prod, i| {
            try writer.print("    {any}", .{prod});
            if (i < self.productions.items.len - 1) {
                try writer.print("\n", .{});
            }
        }
    }
};
