const std = @import("std");

const Token = struct {
    tag: Tag,
    start: usize,
    end: usize,

    const Self = @This();

    const Tag = enum {
        eof,
        arrow,
        newline,
        terminal,
        delimiter,
        non_terminal,
    };
};

/// A finite state machine for tokenizing grammar rules. Initialize with `init`.
pub const Tokenizer = struct {
    index: usize,
    buffer: [:0]const u8,

    const Self = @This();

    const State = enum {
        start,
        arrow,
        newline,
        terminal,
        non_terminal,
    };

    pub fn init(buffer: [:0]const u8) Self {
        return .{
            .index = 0,
            .buffer = buffer,
        };
    }

    pub fn dump(self: Self, token: Token) void {
        var token_view = self.view(token);

        for (token_view) |c| {
            if (!std.ascii.isPrint(c)) {
                token_view = "N/A";
                break;
            }
        }

        const tag_name = @tagName(token.tag);
        std.debug.print("Token {{ {string}: {string} }}\n", .{tag_name, token_view});
    }

    pub fn view(self: Self, token: Token) []const u8 {
        return self.buffer[token.start..token.end];
    }

    pub fn next(self: *Self) !?Token {
        if (self.index > self.buffer.len) {
            return null;
        }

        var token = Token {
            .tag = undefined,
            .start = self.index,
            .end = undefined,
        };

        state: switch (State.start) {
            .start => switch(self.buffer[self.index]) {
                0 => {
                    self.index += 1;
                    token.tag = .eof;
                },
                '\n', '\r' => {
                    self.index += 1;
                    token.tag = .newline;
                    continue :state .newline;
                },
                // skip whitespace
                ' ', '\t' => {
                    self.index += 1;
                    token.start = self.index;
                    continue :state .start;
                },
                // start of arrow
                '-' => {
                    self.index += 1;
                    token.tag = .arrow;
                    continue :state .arrow;
                },
                // delimiter
                '|' => {
                    self.index += 1;
                    token.tag = .delimiter;
                },
                // start of terminal
                '\'', '\"' => {
                    self.index += 1;
                    token.tag = .terminal;
                    continue :state .terminal;
                },
                // start of non terminal
                '0' ... '9', 'a' ... 'z', 'A' ... 'Z' => {
                    self.index += 1;
                    token.tag = .non_terminal;
                    continue :state .non_terminal;
                },
                // invalid character
                else => |c| {
                    std.log.err("Invalid character (State: start) '{c}' ({d})", .{c, c});
                    return error.InvalidCharacter;
                },
            },

            .arrow => switch(self.buffer[self.index]) {
                '>' => {
                    self.index += 1;
                },
                else => |c| {
                    std.log.err("Invalid character '{c}' ({d})", .{c, c});
                    return error.InvalidCharacter;
                }
            },

            .newline => switch(self.buffer[self.index]) {
                '\n', '\r' => {
                    self.index += 1;
                },
                else => {}
            },

            .terminal => switch(self.buffer[self.index]) {
                '\'', '\"' => {
                    self.index += 1;
                },
                else => |c| {
                    if (std.ascii.isPrint(c)) {
                        self.index += 1;
                        continue :state .terminal;
                    } else {
                        std.log.err("Invalid character '{c}' ({d})", .{c, c});
                        return error.InvalidCharacter;
                    }
                }
            },

            .non_terminal => switch(self.buffer[self.index]) {
                '0' ... '9', 'a' ... 'z', 'A' ... 'Z' => {
                    self.index += 1;
                    continue :state .non_terminal;
                },
                else => {},
            },
        }

        token.end = self.index;
        return token;
    }
};
