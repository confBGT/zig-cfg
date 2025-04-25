const std = @import("std");
const Allocator = std.mem.Allocator;
const CFG = @import("grammar.zig").CFG;

const Index = struct {
    start: usize,
    end: usize,
};

const ParseTable = std.AutoHashMap(Index, std.AutoArrayHashMap(u32, usize));

pub fn parse(allocator: Allocator, cnf: *const CFG, sentence: []const []const u8) !?usize {
    var table = ParseTable.init(allocator);
    defer {
        var values = table.valueIterator();
        while (values.next()) |value| value.deinit();
        table.deinit();
    }

    for (sentence, 0..) |word, start| {
        if (cnf.findTerminalId(word)) |terminal_id| {
            var nodes = std.AutoArrayHashMap(u32, usize).init(allocator);

            var filter = cnf.filterRhsIterator(&[_]u32{terminal_id});
            while (filter.next()) |lhs_id| {
                try nodes.put(lhs_id, 0);
            }

            try table.put(.{ .start = start, .end = start + 1 }, nodes);
        } else {
            std.log.err("CYK: Terminal symbol not found in grammar: {string}", .{word});
            return error.UnknownTerminal;
        }
    }

    for (2..sentence.len + 1) |span| {
        for (0..sentence.len - span + 1) |start| {
            for (1..span) |partition| {
                const current_index = Index{ .start = start, .end = start + span };
                const a_index = Index{ .start = start, .end = start + partition };
                const b_index = Index{ .start = start + partition, .end = start + span };

                const table_result = try table.getOrPut(current_index);
                if (!table_result.found_existing) {
                    table_result.value_ptr.* = std.AutoArrayHashMap(u32, usize).init(allocator);
                }

                const a_result = table.get(a_index) orelse continue;
                const b_result = table.get(b_index) orelse continue;

                for (a_result.keys(), a_result.values()) |a_id, a_count| {
                    for (b_result.keys(), b_result.values()) |b_id, b_count| {
                        var filter = cnf.filterRhsIterator(&[_]u32{ a_id, b_id });
                        while (filter.next()) |lhs_id| {
                            var count = a_count + b_count;
                            if (lhs_id < cnf.symbols.len) {
                                count += 1;
                            }

                            const best_so_far = table_result.value_ptr.get(lhs_id)
                                orelse std.math.maxInt(usize);

                            if (count < best_so_far) {
                                try table_result.value_ptr.put(lhs_id, count);
                            }
                        }
                    }
                }
            }
        }
    }

    const result_index = Index{ .start = 0, .end = sentence.len };
    const result = table.get(result_index).?;

    // return result.get(cnf.start);
    return result.get(0);
}
