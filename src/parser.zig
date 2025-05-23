const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("tokenizer.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Production = @import("grammar.zig").Production;
const Symbol = @import("symbol_table.zig").Symbol;
const SymbolTable = @import("symbol_table.zig").SymbolTable;
const LinkedList = @import("linked_list.zig").LinkedList;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokenizer: Tokenizer,
    symbols: *SymbolTable,
    state: State,
    lhs: u32,
    rhs: LinkedList(u32),

    const State = enum {
        expect_lhs,
        expect_rhs,
        expect_arrow,
    };

    pub fn init(allocator: std.mem.Allocator, input: [:0]const u8, symbols: *SymbolTable) Parser {
        return .{
            .allocator = allocator,
            .tokenizer = Tokenizer.init(input),
            .symbols = symbols,
            .state = .expect_lhs,
            .lhs = undefined,
            .rhs = LinkedList(u32).init(allocator),
        };
    }

    pub fn next(self: *Parser) !?Production {
        errdefer self.rhs.deinit();

        while (try self.tokenizer.next()) |token| {
            switch (self.state) {
                .expect_lhs => switch (token.tag) {
                    .eof => {
                        return null;
                    },
                    .non_terminal => {
                        self.state = .expect_arrow;
                        self.lhs = try self.symbols.intern(.{
                            .tag = .non_terminal,
                            .label = self.tokenizer.view(token),
                        });
                    },
                    else => {
                        return error.InvalidToken;
                    },
                },

                .expect_rhs => switch (token.tag) {
                    .eof => {
                        break;
                    },
                    .newline => {
                        self.state = .expect_lhs;
                        break;
                    },
                    .delimiter => {
                        break;
                    },
                    .terminal => {
                        const id = try self.symbols.intern(.{
                            .tag = .terminal,
                            .label = self.tokenizer.view(token),
                        });
                        try self.rhs.append(id);
                    },
                    .non_terminal => {
                        const id = try self.symbols.intern(.{
                            .tag = .non_terminal,
                            .label = self.tokenizer.view(token),
                        });
                        try self.rhs.append(id);
                    },
                    else => {
                        return error.InvalidToken;
                    },
                },

                .expect_arrow => switch (token.tag) {
                    .arrow => {
                        self.state = .expect_rhs;
                    },
                    else => {
                        return error.InvalidToken;
                    },
                },
            }
        }

        const ret = Production { .lhs = self.lhs, .rhs = self.rhs };
        self.rhs = LinkedList(u32).init(self.allocator);
        return ret;
    }
};
