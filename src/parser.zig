const std = @import("std");
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Production = @import("grammar.zig").Production;

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

        state: switch (self.state) {
            .expect_lhs => {
                const token = try self.tokenizer.next() orelse return null;
                switch (token.tag) {
                    .non_terminal => {
                        self.lhs = self.tokenizer.view(token);
                        continue :state .expect_arrow;
                    },
                    else => {
                        return error.InvalidToken;
                    },
                }
            },

            .expect_rhs => {
                const token = try self.tokenizer.next() orelse return null;
                switch (token.tag) {
                    .eof => {},
                    .delimiter => {
                        self.state = .expect_rhs;
                    },
                    .newline => {
                        self.state = .expect_lhs;
                    },
                    .terminal, .non_terminal => {
                        try self.rhs.append(self.tokenizer.view(token));
                        continue :state .expect_rhs;
                    },
                    else => {
                        return error.InvalidToken;
                    },
                }
            },

            .expect_arrow => {
                const token = try self.tokenizer.next() orelse return null;
                switch (token.tag) {
                    .arrow => {
                        continue :state .expect_rhs;
                    },
                    else => {
                        return error.InvalidToken;
                    },
                }
            },
        }

        return .{
            .lhs = self.lhs,
            .rhs = try self.rhs.toOwnedSlice(),
        };
    }
};
