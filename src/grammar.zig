const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("tokenizer.zig").Token;
const Parser = @import("parser.zig").Parser;
const Symbol = @import("symbol_table.zig").Symbol;
const LinkedList = @import("linked_list.zig").LinkedList;

pub const Production = struct {
    lhs: u64,
    rhs: LinkedList(u64),
};

pub const Grammar = struct {
    allocator: std.mem.Allocator,
    productions: std.ArrayList(Production),
    symbols: std.ArrayList(Symbol),

    const Self = @This();

    pub fn init(
        allocator: Allocator,
        productions: std.ArrayList(Production),
        symbols: std.ArrayList(Symbol),
    ) Self {
        return .{
            .allocator = allocator,
            .productions = productions,
            .symbols = symbols,
        };
    }

    pub fn fromString(allocator: Allocator, input: [:0]const u8) !Self {
        // parse input
        var productions = std.ArrayList(Production).init(allocator);
        errdefer {
            defer productions.deinit();
            for (productions.items) |*production| {
                production.rhs.deinit();
            }
        }

        // var symbol_table = SymbolTable.init(allocator);
        // errdefer symbol_table.deinit();
        //
        // var parser = Parser.init(allocator, input, &symbol_table);
        // while (try parser.next()) |prod| {
        //     try productions.append(prod);
        // }

        var symbols = std.ArrayList(Symbol).init(allocator);
        var parser = Parser.init(allocator, input, &symbols);
        while (try parser.next()) |prod| {
            try productions.append(prod);
        }

        return init(allocator, productions, symbols);
    }

    pub fn deinit(self: *Self) void {
        for (self.productions.items) |*production| {
            production.rhs.deinit();
        }

        self.productions.deinit();
        self.symbols.deinit();
        self.* = undefined;
    }

    pub fn format(
        self: Self,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print(
            "Grammar with {d} productions:\n",
            .{self.productions.items.len},
        );

        for (self.productions.items) |prod| {
            const lhs = self.symbols.items[prod.lhs];
            try writer.print("{string} ->", .{lhs.label});

            var it = prod.rhs.iterator();
            while (it.next()) |rhs_id| {
                const rhs = self.symbols.items[rhs_id];
                try writer.print(" {string}", .{rhs.label});
            }

            try writer.print("\n", .{});
        }
    }
};
