const std = @import("std");
const Grammar = @import("grammar.zig").Grammar;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const grammar_text = @embedFile("grammar.txt");
    var grammar = try Grammar.fromString(allocator, grammar_text);
    defer grammar.deinit();

    try grammar.convertToChomskyNormalForm();

    std.debug.print("{any}", .{grammar});

    // this tabled is indexed by (span - 1, start).
    // if using a hash map, then (span, start) is fine.
    const Info = struct { span: usize, start: usize };
    var dp = std.AutoHashMap(Info, std.AutoArrayHashMap(u32, void)).init(allocator);
    defer {
        var it = dp.valueIterator();
        while (it.next()) |value| {
            value.deinit();
        }
        dp.deinit();
    }

    const sentence = [_][]const u8{
        "C", "Rn", "Si", "Rn", "Ca", "P", "Ti", "Mg", "Y", "Ca", "P", "Ti", "Rn", "F", "Ar", "Si", "Th", "F", "Ar", "Ca", "Si", "Th", "Si", "Th", "P", "B", "Ca", "Ca", "Si", "Rn", "Si", "Rn", "Ti", "Ti", "Mg", "Ar", "P", "B", "Ca", "P", "Mg", "Y", "P", "Ti", "Rn", "F", "Ar", "F", "Ar", "Ca", "Si", "Rn", "B", "P", "Mg", "Ar", "P", "Rn", "Ca", "P", "Ti", "Rn", "F", "Ar", "Ca", "Si", "Th", "Ca", "Ca", "F", "Ar", "P", "B", "Ca", "Ca", "P", "Ti", "Ti", "Rn", "F", "Ar", "Ca", "Si", "Rn", "Si", "Al", "Y", "Si", "Th", "Rn", "F", "Ar", "Ar", "Ca", "Si", "Rn", "B", "F", "Ar", "Ca", "Ca", "Si", "Rn", "Si", "Th", "Ca", "Ca", "Ca", "F", "Y", "Ca", "P", "Ti", "B", "Ca", "Si", "Th", "Ca", "Si", "Th", "P", "Mg", "Ar", "Si", "Rn", "Ca", "P", "B", "F", "Y", "Ca", "Ca", "F", "Ar", "Ca", "Ca", "Ca", "Ca", "Si", "Th", "Ca", "Si", "Rn", "P", "Rn", "F", "Ar", "P", "B", "Si", "Th", "P", "Rn", "F", "Ar", "Si", "Rn", "Mg", "Ar", "Ca", "F", "Y", "F", "Ar", "Ca", "Si", "Rn", "Si", "Al", "Ar", "Ti", "Ti", "Ti", "Ti", "Ti", "Ti", "Ti", "Rn", "P", "Mg", "Ar", "P", "Ti", "Ti", "Ti", "B", "Si", "Rn", "Si", "Al", "Ar", "Ti", "Ti", "Rn", "P", "Mg", "Ar", "Ca", "F", "Y", "B", "P", "B", "P", "Ti", "Rn", "Si", "Rn", "Mg", "Ar", "Si", "Th", "Ca", "F", "Ar", "Ca", "Si", "Th", "F", "Ar", "P", "Rn", "F", "Ar", "Ca", "Si", "Rn", "Ti", "B", "Si", "Th", "Si", "Rn", "Si", "Al", "Y", "Ca", "F", "Ar", "P", "Rn", "F", "Ar", "Si", "Th", "Ca", "F", "Ar", "Ca", "Ca", "Si", "Th", "Ca", "Ca", "Ca", "Si", "Rn", "P", "Rn", "Ca", "F", "Ar", "F", "Y", "P", "Mg", "Ar", "Ca", "P", "B", "Ca", "P", "B", "Si", "Rn", "F", "Y", "P", "B", "Ca", "F", "Ar", "Ca", "Si", "Al"
    };

    // const sentence = [_][]const u8{
    //     "she",
    //     "eats",
    //     "a",
    //     "fish",
    //     "with",
    //     "a",
    //     "fork",
    // };

    for (sentence, 0..) |word, i| {
        const key = Info { .span = 0, .start = i };
        const result = try dp.getOrPut(key);
        if (!result.found_existing) {
            result.value_ptr.* = std.AutoArrayHashMap(u32, void).init(allocator);
        }
        const terminal_id = grammar.findTerminalId(word);
        var it = grammar.filterRhsIterator(&[_]u32{ terminal_id.? });
        while (it.next()) |lhs_id| {
            try result.value_ptr.put(lhs_id, {});
        }
    }

    var span: usize = 1;
    while (span <= sentence.len) : (span += 1) {
        var start: usize = 0;
        while (start <= sentence.len - span) : (start += 1) {
            var partition: usize = 1;
            while (partition < span) : (partition += 1) {
                const current = Info { .span = span, .start = start };

                const lhs = Info { .span = partition - 1, .start = start };
                const rhs = Info { .span = span - partition - 1, .start = start + partition };

                const lhs_result = dp.get(lhs);
                const rhs_result = dp.get(rhs);

                if (lhs_result == null or rhs_result == null) {
                    continue;
                }

                const current_result = try dp.getOrPut(current);
                if (!current_result.found_existing) {
                    current_result.value_ptr.* = std.AutoArrayHashMap(u32, void).init(allocator);
                }

                for (lhs_result.?.keys()) |lhs_id| {
                    for (rhs_result.?.keys()) |rhs_id| {
                        var it = grammar.filterRhsIterator(&[_]u32{ lhs_id, rhs_id });
                        while (it.next()) |filter_lhs| {
                            try current_result.value_ptr.put(filter_lhs, {});
                        }
                    }
                }
            }
        }
    }

    const result = dp.get(.{ .span = sentence.len - 1, .start = 0 });
    std.debug.print("{any}\n", .{result.?.keys()});
}
