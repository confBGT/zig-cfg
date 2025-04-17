const std = @import("std");
const Allocator = std.mem.Allocator;

/// A finite state machine (FSM) for tokenizing grammar rules. Initialize with
/// `init`.
/// _TODO: Use an iterator to avoid unnecessary allocations._
pub const FSMTokenizer = struct {
    allocator: Allocator,
    state: State,
    token: ?Token,
    tokens: std.ArrayList(Token),

    const lut = [_]FnType{
        parseStart,
        parseArrow,
        parseTerminal,
        parseNonTerminal,
    };

    const Self = @This();

    const FnType = *const fn (*Self, []const u8) Error!void;

    const Error = error {
        InvalidCharacter,
    } || Allocator.Error;

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
            .state = .start,
            .token = null,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.tokens.deinit();
        self.* = undefined;
    }

    pub fn tokenize(self: *Self, input: []const u8) ![]Token {
        for (0..input.len) |i| {
            const index = @intFromEnum(self.state);
            try lut[index](self, input[i..]);
        }

        try self.finalize();
        return self.tokens.toOwnedSlice();
    }

    /// Emits the current token and sets the FSM state to `start`.
    fn emitTokenAndReset(self: *Self) !void {
        try self.tokens.append(self.token.?);
        self.token = null;
        self.state = .start;
    }

    /// Completes the tokenization process by emitting any pending tokens and
    /// resetting the FSM state.
    fn finalize(self: *Self) !void {
        switch (self.state) {
            .start => {},
            .parse_arrow, .parse_terminal, .parse_non_terminal => {
                return self.emitTokenAndReset();
            },
        }
    }

    fn parseStart(self: *Self, slice: []const u8) !void {
        switch (slice[0]) {
            // start of arrow
            '-' => {
                self.token = Token { .arrow = slice[0..1] };
                self.state = .parse_arrow;
            },
            // delimiter
            '|' => {
                self.token = Token { .delimiter = slice[0..1] };
                try self.emitTokenAndReset();
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
                return Error.InvalidCharacter;
            },
        }
    }

    fn parseArrow(self: *Self, slice: []const u8) !void {
        switch (slice[0]) {
            // only allowed character after '-'
            '>' => {
                self.token.?.arrow.len += 1;
                try self.emitTokenAndReset();
            },
            else => |c| {
                std.debug.print("Illegal character '{c}' ({d})\n", .{c, c});
                return Error.InvalidCharacter;
            }
        }
    }

    fn parseTerminal(self: *Self, slice: []const u8) !void {
        switch (slice[0]) {
            // end of terminal
            '\'', '\"' => {
                self.token.?.terminal.len += 1;
                try self.emitTokenAndReset();
            },
            else => |c| {
                // any _printable_ character can be part of a terminal
                if (std.ascii.isPrint(c)) {
                    self.token.?.terminal.len += 1;
                } else { // any other character is illegal
                    std.debug.print("Illegal character '{c}' ({d})\n", .{ c, c });
                    return Error.InvalidCharacter;
                }
            },
        }
    }

    fn parseNonTerminal(self: *Self, slice: []const u8) !void {
        switch (slice[0]) {
            // a non terminal can be directly followed by a delimiter
            '|' => {
                try self.emitTokenAndReset();
                self.token = Token { .delimiter = slice[0..1] };
                try self.emitTokenAndReset();
            },
            // end of non terminal is marked by whitespace
            ' ', '\t' => {
                try self.emitTokenAndReset();
            },
            // only alphanumerics can be part of a non terminal
            '0'...'9', 'a'...'z', 'A'...'Z' => {
                self.token.?.non_terminal.len += 1;
            },
            // any other character is illegal
            else => |c| {
                std.debug.print("Illegal character '{c}' ({d})\n", .{ c, c });
                return Error.InvalidCharacter;
            },
        }
    }
};
