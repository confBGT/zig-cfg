const std = @import("std");
const Grammar = @import("grammar.zig").Grammar;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const SymbolTable = @import("symbol_table.zig").SymbolTable;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const text = @embedFile("grammar.txt");
    std.debug.print("Grammar file:\n{string}", .{text});

    var grammar = try Grammar.fromString(allocator, text);
    defer grammar.deinit();

    try grammar.convertToChomskyNormalForm();

    std.debug.print("------------\n{any}\n", .{grammar});
}
