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

    pub fn fromString(allocator: Allocator, input: [:0]const u8) !Self {
        var productions = std.ArrayList(Production).init(allocator);
        var symbol_table = SymbolTable.init(allocator);

        var parser = Parser.init(allocator, input, &symbol_table);
        while (try parser.next()) |prod| {
            try productions.append(prod);
        }

        const symbols = try symbol_table.demote();

        return .{
            .allocator = allocator,
            .productions = productions,
            .symbols = symbols,
            .iota = symbols.len,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.productions.items) |*production| {
            production.rhs.deinit();
        }

        self.allocator.free(self.symbols);
        self.productions.deinit();

        self.* = undefined;
    }

    pub fn convertToChomskyNormalForm(self: *Self) !void {
        try self.eliminateNonsolitaryTerminals();
        try self.binarise();
        try self.eliminateUnitaryRules();
    }

    pub fn binarise(self: *Self) !void {
        var i: usize = 0;
        const productions_len = self.productions.items.len;
        while (i < productions_len) : (i += 1) {
            try self.binariseProduction(&self.productions.items[i]);
        }
    }

    pub fn eliminateNonsolitaryTerminals(self: *Self) !void {
        var i: usize = 0;
        const productions_len = self.productions.items.len;
        while (i < productions_len) : (i += 1) {
            var prod = self.productions.items[i];
            try self.eliminateNonsolitaryTerminalsFromProduction(&prod);
        }
    }

    pub fn eliminateUnitaryRules(self: *Self) !void {
        var i: usize = 1;
        var productions_len = self.productions.items.len;
        while (i < productions_len) : (i += 1) {
            const prod = self.productions.items[i];

            if (prod.rhs.count == 1) {
                const id = prod.rhs.head().?;

                if (!self.isTerminal(id)) {
                    var removed_prod = self.productions.swapRemove(i);
                    removed_prod.rhs.deinit();
                    productions_len -= 1;
                    i -= 1;

                    for (self.productions.items) |prod2| {
                        if (prod2.lhs == id) {
                            try self.productions.append(.{
                                .lhs = prod.lhs,
                                .rhs = try prod2.rhs.clone(),
                            });
                        }
                    }
                }
            }
        }
    }

    fn eliminateNonsolitaryTerminalsFromProduction(
        self: *Self,
        prod: *Production,
    ) !void {
        if (prod.rhs.count <= 1) return;

        var it = prod.rhs.iterator();
        while (it.next()) |id| {
            if (!self.isTerminal(id.*)) continue;

            if (self.findUniqueLhs(id.*)) |lhs| {
                id.* = lhs;
            } else {
                var new_prod = Production {
                    .lhs = @intCast(self.iota),
                    .rhs = LinkedList(u32).init(self.allocator),
                };
                try new_prod.rhs.append(id.*);
                self.iota += 1;

                id.* = new_prod.lhs;
                try self.productions.append(new_prod);
            }
        }
    }

    fn binariseProduction(self: *Self, prod: *Production) !void {
        if (prod.rhs.count > 2) {
            var new_prod = Production{
                .lhs = @intCast(self.iota),
                .rhs = prod.rhs.splitHead(),
            };
            self.iota += 1;

            try prod.rhs.append(new_prod.lhs);
            try self.binariseProduction(&new_prod);
            try self.productions.append(new_prod);
        }
    }

    /// Searches for a production where `rhs` is the only symbol on the
    /// right-hand side. If found, the corresponding left-hand side symbol ID
    /// is returned. Otherwise, `null` is returned.
    fn findUniqueLhs(self: *Self, rhs: u32) ?u32 {
        for (self.productions.items) |prod| {
            if (prod.rhs.count == 1 and prod.rhs.start_ptr.?.item == rhs) {
                return prod.lhs;
            }
        }
        return null;
    }

    fn isTerminal(self: Self, id: u32) bool {
        if (id < self.symbols.len) {
            return self.symbols[id].tag == .terminal;
        }
        return false;
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
            if (prod.lhs < self.symbols.len) {
                try writer.print("{s} ->", .{self.symbols[prod.lhs].label});
            } else {
                try writer.print("{d} ->", .{prod.lhs});
            }

            var it = prod.rhs.iterator();
            while (it.next()) |id| {
                if (id.* < self.symbols.len) {
                    try writer.print(" {s}", .{self.symbols[id.*].label});
                } else {
                    try writer.print(" {d}", .{id.*});
                }
            }

            try writer.print("\n", .{});
        }
    }
};
