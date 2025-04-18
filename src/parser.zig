const std = @import("std");
const Token = @import("tokenizer.zig").Token;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Production = @import("grammar.zig").Production;
const SymbolTable = @import("symbol_table.zig").SymbolTable;

const Production = struct {
    lhs: u64,
    rhs: []u64,
};

const P = struct {
    allocator: std.mem.Allocator,
    tokenizer: Tokenizer,
    state: State,
    lhs: u64,
    rhs: std.ArrayList(u64),

    const Self = @This();

    const State = enum {
        expect_lhs,
        expect_rhs,
        expect_arrow,
    };

    pub fn init(allocator: std.mem.Allocator, input: [:0]const u8) Self {
        return .{
            .allocator = allocator,
            .symbol_table = SymbolTable.init(allocator),
            .tokenizer = Tokenizer.init(input),
            .state = State.start,
            .lhs = undefined,
            .rhs = std.ArrayList(u64).init(allocator),
        };
    }

    pub fn initA(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .symbol_table = SymbolTable.init(allocator),
            .tokenizer = undefined,
            .state = State.start,
            .lhs = undefined,
            .rhs = std.ArrayList(u64).init(allocator),
        };
    }

    pub fn parseInput(self: *Self, input: [:0]const u8) void {
        self.tokenizer = Tokenizer.init(input);

        var foos = std.ArrayList(Foo).init(self.allocator);
        while (try self.next()) |foo| {
            try foos.append(foo);
        }

        return .{
            .foos = foos,
            .symbol_table = self.symbol_table,
        };
    }

    pub fn deinit(self: *Self) void {
        self.rhs.deinit();
        self.* = undefined;
    }

    pub fn next(self: *Self) !?Foo {
        errdefer self.rhs.deinit();

        while (try self.tokenizer.next()) |token| {
            switch (self.state) {
                .expect_lhs => switch (token.tag) {
                    .eof => {
                        return null;
                    },
                    .non_terminal => {
                        const symbol = self.tokenizer.view(token);
                        const id = self.symbol_table.getOrPut(symbol);
                        self.lhs = id;
                        self.state = .expect_arrow;
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
                    .terminal, .non_terminal => {
                        const symbol = self.tokenizer.view(token);
                        const id = self.symbol_table.getOrPut(symbol);
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

        return .{
            .lhs = self.lhs,
            .rhs = try self.rhs.toOwnedSlice(),
        };
    }
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokenizer: Tokenizer,
    state: State,
    lhs: []const u8,
    rhs: std.ArrayList([]const u8),

    const Self = @This();

    const State = enum {
        expect_lhs,
        expect_rhs,
        expect_arrow,
    };

    pub fn init(allocator: std.mem.Allocator, input: [:0]const u8) Self {
        return .{
            .allocator = allocator,
            .tokenizer = Tokenizer.init(input),
            .state = .expect_lhs,
            .lhs = undefined,
            .rhs = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn next(self: *Self) !?Production {
        errdefer self.rhs.deinit();

        while (try self.tokenizer.next()) |token| {
            switch (self.state) {
                .expect_lhs => switch (token.tag) {
                    .eof => {
                        return null;
                    },
                    .non_terminal => {
                        self.lhs = self.tokenizer.view(token);
                        self.state = .expect_arrow;
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
                    .terminal, .non_terminal => {
                        try self.rhs.append(self.tokenizer.view(token));
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

        return .{
            .lhs = self.lhs,
            .rhs = try self.rhs.toOwnedSlice(),
        };
    }
};
