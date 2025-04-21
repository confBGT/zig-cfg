const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("tokenizer.zig").Token;
const Parser = @import("parser.zig").Parser;
const Symbol = @import("symbol_table.zig").Symbol;
const SymbolTable = @import("symbol_table.zig").SymbolTable;
const LinkedList = @import("linked_list.zig").LinkedList;

pub const Production = struct {
    lhs: u32,
    rhs: LinkedList(u32),
};

pub const Grammar = struct {
    allocator: std.mem.Allocator,
    productions: std.ArrayList(Production),
    symbols: []Symbol,
    iota: usize,

    const Self = @This();

    pub fn init(
        allocator: Allocator,
        productions: std.ArrayList(Production),
        symbols: []Symbol,
        iota: usize,
    ) Self {
        return .{
            .allocator = allocator,
            .productions = productions,
            .symbols = symbols,
            .iota = iota,
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

        var symbol_table = SymbolTable.init(allocator);
        defer symbol_table.deinit();

        var parser = Parser.init(allocator, input, &symbol_table);
        while (try parser.next()) |prod| {
            try productions.append(prod);
        }

        const symbols = try allocator.dupe(Symbol, symbol_table.map.keys());
        return init(allocator, productions, symbols, symbols.len);
    }

    fn binariseProduction(self: *Self, prod: *Production) !void {
        if (prod.rhs.count > 2) {
            var n_prod = Production {
                .lhs = @intCast(self.iota),
                .rhs = prod.rhs.splitHead(),
            };
            self.iota += 1;

            try prod.rhs.append(n_prod.lhs);
            try self.binariseProduction(&n_prod);
            try self.productions.append(n_prod);
        }
    }

    pub fn binarise(self: *Self) !void {
        for (self.productions.items) |*prod| {
            try self.binariseProduction(prod);
        }
    }

    pub fn eliminateNonsolitaryTerminals(self: *Self) void {
        _ = self;
    }

    pub fn deinit(self: *Self) void {
        for (self.productions.items) |*production| {
            production.rhs.deinit();
        }

        self.allocator.free(self.symbols);
        self.productions.deinit();
        self.* = undefined;
    }

    fn printSymbol(self: Self, writer: anytype, id: u32) !void {
        if (id < self.symbols.len) {
            try writer.print("{s}", .{self.symbols[id].label});
        } else {
            try writer.print("{d}", .{id});
        }
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
            try self.printSymbol(writer, prod.lhs);
            try writer.print(" ->", .{});

            var it = prod.rhs.iterator();
            while (it.next()) |rhs_id| {
                try writer.print(" ", .{});
                try self.printSymbol(writer, rhs_id);
            }

            try writer.print("\n", .{});
        }
    }
};
