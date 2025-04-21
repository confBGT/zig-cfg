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

    std.debug.print("------------\n{any}\n", .{grammar});

    var foo = SymbolTable.init(allocator);
    defer foo.deinit();

    _ = try foo.getOrPut(.{ .tag = .terminal, .label = "mariop" });
    _ = try foo.getOrPut(.{ .tag = .terminal, .label = "yoshii" });
    _ = try foo.getOrPut(.{ .tag = .terminal, .label = "noseya" });
    _ = try foo.getOrPut(.{ .tag = .terminal, .label = "popotu" });

    for (foo.map.keys()) |symbol| {
        std.debug.print("{string}\n", .{symbol.label});
    }
}
