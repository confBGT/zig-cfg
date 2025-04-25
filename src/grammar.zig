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

pub const CFG = struct {
    allocator: std.mem.Allocator,
    productions: std.ArrayList(Production),
    symbols: []Symbol,
    iota: usize,
    rhs_index: std.AutoArrayHashMap(u32, std.ArrayList(Production)),

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
            .rhs_index = undefined,
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

    /// _https://en.wikipedia.org/wiki/Chomsky_normal_form_
    pub fn convertToChomskyNormalForm(self: *Self) !void {
        try self.eliminateNonsolitaryTerminals();
        try self.binarise();
        try self.eliminateUnitaryProductions();
    }

    /// Replace each production of the form
    ///     `A -> X_1 X_2 ... X_n`,
    /// by productions
    ///     `A_1 -> X_1 A_2`,
    ///     `A_2 -> X_2 A_3`,
    ///     `...`,
    ///     `A_(n-2) -> X_(n-1) X_n`,
    /// where `A_i` are new nonterminal symbols.
    pub fn binarise(self: *Self) !void {
        var i: usize = 0;
        const productions_len = self.productions.items.len;
        while (i < productions_len) : (i += 1) {
            try self.binariseProduction(&self.productions.items[i]);
        }
    }

    /// For each production of the form
    ///     `A -> X_1 ... "a" ... X_n`
    /// with a terminal symbol "a" being not the only symbol in the right-hand
    /// side, introduce, for every such terminal, a new nonterminal symbol
    /// `N_a` and a new production such that `N_a -> "a"`. Then, change the
    /// original rule to be of the form
    ///     `A -> X_1 ... N_a ... X_n`.
    pub fn eliminateNonsolitaryTerminals(self: *Self) !void {
        var i: usize = 0;
        const productions_len = self.productions.items.len;
        while (i < productions_len) : (i += 1) {
            var prod = self.productions.items[i];
            try self.eliminateNonsolitaryTerminalsFromProduction(&prod);
        }
    }

    /// For each production of the form
    ///     `A -> B`,
    /// where `A` and `B` are nonterminals, eliminate such production, and, for
    /// every other production of the form
    ///     `B -> X_1 ... X_N`,
    /// where `X_1 ... X_N` is a string of nonterminals and terminals, add a
    /// new production of the form
    ///     `A -> X_1 ... X_N`.
    pub fn eliminateUnitaryProductions(self: *Self) !void {
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

    const FilterRhsIterator = struct {
        g: *const CFG,
        rhs: []const u32,
        index: usize,
        pub fn next(self: *FilterRhsIterator) ?u32 {
            next: while (self.index < self.g.productions.items.len) {
                const prod = self.g.productions.items[self.index];
                self.index += 1;
                if (prod.rhs.count == self.rhs.len) {
                    var k: usize = 0;
                    var it = prod.rhs.iterator();
                    while (it.next()) |id| {
                        if (id.* != self.rhs[k]) {
                            continue :next;
                        }
                        k += 1;
                    }
                    return prod.lhs;
                }
            }
            return null;
        }
    };

    pub fn filterRhsIterator(self: *const Self, rhs: []const u32) FilterRhsIterator {
        return .{
            .g = self,
            .rhs = rhs,
            .index = 0,
        };
    }

    pub fn findTerminalId(self: Self, label: []const u8) ?u32 {
        for (self.symbols, 0..) |symbol, id| {
            if (symbol.tag == .terminal) {
                if (std.mem.eql(u8, symbol.label[1..symbol.label.len - 1], label)) {
                    return @intCast(id);
                }
            }
        }
        return null;
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

    /// Searches for a production where `id` is the only symbol on the
    /// right-hand side. If found, the corresponding left-hand side symbol ID
    /// is returned. Otherwise, `null` is returned.
    pub fn findUniqueLhs(self: *Self, id: u32) ?u32 {
        for (self.productions.items) |prod| {
            if (prod.rhs.count == 1 and prod.rhs.start_ptr.?.item == id) {
                return prod.lhs;
            }
        }
        return null;
    }

    /// Returns whether `id` corresponds to a terminal symbol.
    fn isTerminal(self: Self, id: u32) bool {
        if (id < self.symbols.len) {
            return self.symbols[id].tag == .terminal;
        }
        return false;
    }


    pub fn calculateIndexes(self: *Self) !void {
        self.rhs_index = std.AutoArrayHashMap(u32, std.ArrayList(Production)).init(self.allocator);
        for (self.productions.items) |prod| {
            if (prod.rhs.head()) |head| {
                const result = try self.rhs_index.getOrPut(head);
                if (!result.found_existing) {
                    result.value_ptr.* = std.ArrayList(Production).init(self.allocator);
                }
                try result.value_ptr.append(prod);
            }
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
