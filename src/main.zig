const std = @import("std");
const Grammar = @import("grammar.zig").Grammar;
const Tokenizer = @import("tokenizer.zig").Tokenizer;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    // const text = @embedFile("grammar.txt");
    const text = "S -> P\nE ->";
    std.debug.print("Grammar file:\n{string}", .{text});

    var grammar = try Grammar.fromString(allocator, text);
    defer grammar.deinit();
    std.debug.print("------------\n{any}\n", .{grammar});
}
