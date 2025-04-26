const std = @import("std");
const CYK = @import("cyk.zig");
const CFG = @import("grammar.zig").CFG;

test "Short grammar" {
    const contents = @embedFile("./examples/short-grammar.txt");
    const sentence = [_][]const u8{ "a", "very", "heavy", "orange", "book" };

    var cfg = try CFG.fromString(std.testing.allocator, contents);
    defer cfg.deinit();

    try cfg.convertToChomskyNormalForm();
    try cfg.calculateIndexes();

    const sd = try CYK.shortest_derivation(std.testing.allocator, &cfg, &sentence);
    try std.testing.expect(sd != null);
}

test "Long grammar" {
    const contents = @embedFile("./examples/long-grammar.txt");
    const sentence = [_][]const u8{ "C", "Rn", "Si", "Rn", "Ca", "P", "Ti", "Mg", "Y", "Ca", "P", "Ti", "Rn", "F", "Ar", "Si", "Th", "F", "Ar", "Ca", "Si", "Th", "Si", "Th", "P", "B", "Ca", "Ca", "Si", "Rn", "Si", "Rn", "Ti", "Ti", "Mg", "Ar", "P", "B", "Ca", "P", "Mg", "Y", "P", "Ti", "Rn", "F", "Ar", "F", "Ar", "Ca", "Si", "Rn", "B", "P", "Mg", "Ar", "P", "Rn", "Ca", "P", "Ti", "Rn", "F", "Ar", "Ca", "Si", "Th", "Ca", "Ca", "F", "Ar", "P", "B", "Ca", "Ca", "P", "Ti", "Ti", "Rn", "F", "Ar", "Ca", "Si", "Rn", "Si", "Al", "Y", "Si", "Th", "Rn", "F", "Ar", "Ar", "Ca", "Si", "Rn", "B", "F", "Ar", "Ca", "Ca", "Si", "Rn", "Si", "Th", "Ca", "Ca", "Ca", "F", "Y", "Ca", "P", "Ti", "B", "Ca", "Si", "Th", "Ca", "Si", "Th", "P", "Mg", "Ar", "Si", "Rn", "Ca", "P", "B", "F", "Y", "Ca", "Ca", "F", "Ar", "Ca", "Ca", "Ca", "Ca", "Si", "Th", "Ca", "Si", "Rn", "P", "Rn", "F", "Ar", "P", "B", "Si", "Th", "P", "Rn", "F", "Ar", "Si", "Rn", "Mg", "Ar", "Ca", "F", "Y", "F", "Ar", "Ca", "Si", "Rn", "Si", "Al", "Ar", "Ti", "Ti", "Ti", "Ti", "Ti", "Ti", "Ti", "Rn", "P", "Mg", "Ar", "P", "Ti", "Ti", "Ti", "B", "Si", "Rn", "Si", "Al", "Ar", "Ti", "Ti", "Rn", "P", "Mg", "Ar", "Ca", "F", "Y", "B", "P", "B", "P", "Ti", "Rn", "Si", "Rn", "Mg", "Ar", "Si", "Th", "Ca", "F", "Ar", "Ca", "Si", "Th", "F", "Ar", "P", "Rn", "F", "Ar", "Ca", "Si", "Rn", "Ti", "B", "Si", "Th", "Si", "Rn", "Si", "Al", "Y", "Ca", "F", "Ar", "P", "Rn", "F", "Ar", "Si", "Th", "Ca", "F", "Ar", "Ca", "Ca", "Si", "Th", "Ca", "Ca", "Ca", "Si", "Rn", "P", "Rn", "Ca", "F", "Ar", "F", "Y", "P", "Mg", "Ar", "Ca", "P", "B", "Ca", "P", "B", "Si", "Rn", "F", "Y", "P", "B", "Ca", "F", "Ar", "Ca", "Si", "Al" };

    var cfg = try CFG.fromString(std.testing.allocator, contents);
    defer cfg.deinit();

    try cfg.convertToChomskyNormalForm();
    try cfg.calculateIndexes();

    const sd = try CYK.shortest_derivation(std.testing.allocator, &cfg, &sentence);
    try std.testing.expect(sd != null);
}
