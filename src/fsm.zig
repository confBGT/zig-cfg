const std = @import("std");
const Allocator = std.mem.Allocator;

const FSM = struct {
    allocator: Allocator,

    state: State,
    token: ?Token,
    tokens: std.ArrayList(Token),

    const Self = @This();

    const FnType = *const fn (*Self, []const u8) Allocator.Error!void;

    const State = enum {
        start,
        parse_arrow,
        parse_terminal,
        parse_non_terminal,
    };

    const TokenType = enum {
        arrow,
        terminal,
        delimiter,
        non_terminal,
    };

    const Token = union(TokenType) {
        arrow: []const u8,
        terminal: []const u8,
        delimiter: []const u8,
        non_terminal: []const u8,

        pub fn format(
            self: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            const tag = @tagName(self);

            const symbol = switch (self) {
                .arrow => |s| s,
                .terminal => |s| s,
                .delimiter => |s| s,
                .non_terminal => |s| s,
            };

            return writer.print("Token {{ {string}: {string} }}", .{tag, symbol});
        }
    };

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .state = State.start,
            .token = null,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
        self.* = undefined;
    }

    // transition to _start_ state, add the current token to the list, and
    // invalidate the current token
    pub fn reset(self: *Self) !void {
        try self.tokens.append(self.token.?);

        self.token = null;
        self.state = .start;
    }

    pub fn parseStart(self: *Self, slice: []const u8) !void {
        switch (slice[0]) {
            // end
            0 => {},
            // start of arrow
            '-' => {
                self.token = Token { .arrow = slice[0..1] };
                self.state = .parse_arrow;
            },
            // delimiter
            '|' => {
                self.token = Token { .delimiter = slice[0..1] };
                try self.reset();
            },
            // start of terminal
            '\'', '\"' => {
                self.state = State.parse_terminal;
                self.token = Token { .terminal = slice[0..1] };
            },
            // start of non terminal
            '0'...'9', 'a'...'z', 'A'...'Z' => {
                self.state = State.parse_non_terminal;
                self.token = Token { .non_terminal = slice[0..1] };
            },
            // skip whitespace
            ' ', '\t' => {},
            // any other character is illegal
            else => |c| {
                std.debug.print("Illegal character '{c}' ({d})\n", .{ c, c });
                std.posix.exit(1);
            },
        }
    }

    pub fn parseArrow(self: *Self, slice: []const u8) !void {
        switch (slice[0]) {
            // only allowed character after '-'
            '>' => {
                self.token.?.arrow.len += 1;
                try self.reset();
            },
            else => |c| {
                std.debug.print("Illegal character '{c}' ({d})\n", .{c, c});
                std.posix.exit(1);
            }
        }
    }

    pub fn parseTerminal(self: *Self, slice: []const u8) !void {
        switch (slice[0]) {
            // end of terminal
            '\'', '\"' => {
                self.token.?.terminal.len += 1;
                try self.reset();
            },
            else => |c| {
                // any _printable_ character can be part of a terminal
                if (std.ascii.isPrint(c)) {
                    self.token.?.terminal.len += 1;
                    // any other character is illegal
                } else {
                    std.debug.print("Illegal character '{c}' ({d})\n", .{ c, c });
                    std.posix.exit(1);
                }
            },
        }
    }

    pub fn parseNonTerminal(self: *Self, slice: []const u8) !void {
        switch (slice[0]) {
            // end of non terminal is marked by whitespace or a null character
            0, ' ', '\t' => {
                try self.reset();
            },
            // only alphanumerics can be part of a non terminal
            '0'...'9', 'a'...'z', 'A'...'Z' => {
                self.token.?.non_terminal.len += 1;
            },
            // any other character is illegal
            else => |c| {
                std.debug.print("Illegal character '{c}' ({d})\n", .{ c, c });
                std.posix.exit(1);
            },
        }
    }

    pub fn tokenize(self: *Self, input: []const u8) ![]Token {
        const lut = [_]FnType{
            parseStart,
            parseArrow,
            parseTerminal,
            parseNonTerminal,
        };

        for (0..input.len) |i| {
            const index = @intFromEnum(self.state);
            try lut[index](self, input[i..]);
        }

        const index = @intFromEnum(self.state);
        try lut[index](self, &[_]u8{ 0 });

        return self.tokens.toOwnedSlice();
    }
};

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .{};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var fsm = FSM.init(allocator);
    defer fsm.deinit();

    const text = "S -> NP | VP | TER";
    const tokens = try fsm.tokenize(text);
    defer allocator.free(tokens);

    for (tokens) |token| {
        std.debug.print("{any}\n", .{token});
    }
}
