const std = @import("std");
const Allocator = std.mem.Allocator;

const Token = struct {
    symbol: []const u8,
    terminal: bool,

    const Self = @This();

    pub fn fromString(string: []const u8) !Self {
        const trimmed = std.mem.trim(u8, string, " \t");

        if (trimmed.len == 0) {
            std.log.err("Symbol must be non-empty string\n", .{});
            return error.ParseError;
        }

        const last = trimmed.len - 1;
        if ((trimmed[0] == '\'' and trimmed[last] == '\'') or (trimmed[0] == '\"' and trimmed[last] == '\"')) {
            return .{
                .symbol = trimmed[1..last],
                .terminal = true,
            };
        }

        for (trimmed) |c| {
            if (!std.ascii.isAlphanumeric(c)) {
                std.log.err("Non-terminal symbol must be alphanumeric", .{});
                return error.ParseError;
            }
        }

        return .{
            .symbol = trimmed,
            .terminal = false,
        };
    }
};

const Production = struct {
    lhs: Token,
    rhs: std.ArrayList(Token),

    const Self = @This();

    fn fromString(allocator: Allocator, string: []const u8) !Self {
        const delimiter = " -> ";

        const pos = std.mem.indexOfPos(u8, string, 0, delimiter) orelse {
            std.log.err("Invalid production: arrow ( -> ) not found", .{});
            return error.ParseError;
        };

        const lhs = try Token.fromString(string[0..pos]);
        if (lhs.terminal) {
            std.log.err("lhs cannot be a terminal", .{});
            return error.ParseError;
        }

        var rhs = std.ArrayList(Token).init(allocator);
        var rhs_it = std.mem.tokenizeScalar(u8, string[pos + delimiter.len ..], '|');
        while (rhs_it.next()) |rhs_string| {
            const token = try Token.fromString(rhs_string);
            try rhs.append(token);
        }

        return .{ .lhs = lhs, .rhs = rhs };
    }
};

const Grammar = struct {
    start: ?*Production,
    productions: std.ArrayList(Production),

    const Self = @This();

    fn fromString(allocator: Allocator, string: []const u8) !Self {
        var productions = std.ArrayList(Production).init(allocator);

        var line_it = std.mem.tokenizeScalar(u8, string, '\n');
        while (line_it.next()) |line| {
            const prod = try Production.fromString(allocator, line);
            try productions.append(prod);
        }

        return .{
            .start = null,
            .productions = productions,
        };
    }

    fn deinit(self: *Self) void {
        for (self.productions.items) |*prod| {
            prod.rhs.deinit();
        }

        self.productions.deinit();
        self.* = undefined;
    }

    pub fn format(
        self: Self,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        // try writer.print("Grammar with {d} productions (start = {any})\n", .{self.productions.items.len, self.start});
        for (self.productions.items) |prod| {
            for (prod.rhs.items) |rhs| {
                try writer.print("<{string}> -> <{string}>\n", .{ prod.lhs.symbol, rhs.symbol });
            }
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const text = "S -> NP | DP";
    var grammar = try Grammar.fromString(allocator, text);
    defer grammar.deinit();

    std.debug.print("{any}", .{grammar});
}
