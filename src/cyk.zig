const std = @import("std");
const Allocator = std.mem.Allocator;
const CFG = @import("grammar.zig").CFG;

pub fn shortest_derivation(allocator: Allocator, cnf: *const CFG, sentence: []const []const u8) !?u32 {
    const table = try allocator.alloc(std.AutoHashMap(u32, u32), sentence.len * sentence.len);
    defer {
        for (0..sentence.len) |i| {
            for (0..i + 1) |j| {
                table[j + i * sentence.len].deinit();
            }
        }
        allocator.free(table);
    }

    for (0..sentence.len) |i| {
        for (0..i + 1) |j| {
            table[j + i * sentence.len] = std.AutoHashMap(u32, u32).init(allocator);
        }
    }

    for (sentence, 0..) |word, start| {
        if (cnf.findSymbolId(word, .terminal)) |terminal_id| {
            var nodes = std.AutoHashMap(u32, u32).init(allocator);

            const possible = cnf.rhs_index.get(terminal_id).?;

            for (possible.items) |prod| {
                if (prod.rhs.count == 1) {
                    try nodes.put(prod.lhs, 0);
                }
            }

            table[start + start * sentence.len] = nodes;
        } else {
            return error.UnknownToken;
        }
    }

    for (2..sentence.len + 1) |span| {
        for (0..sentence.len - span + 1) |start| {
            for (1..span) |partition| {
                const current = start + (start + span - 1) * sentence.len;
                const a_index = start + (start + partition - 1) * sentence.len;
                const b_index = start + partition + (start + span - 1) * sentence.len;

                const a_result = table[a_index];
                const b_result = table[b_index];

                var a_it = a_result.iterator();
                while (a_it.next()) |a| {
                    var b_it = b_result.iterator();
                    while (b_it.next()) |b| {
                        const possible = cnf.rhs_index.get(a.key_ptr.*) orelse continue;
                        const prev = a.value_ptr.* + b.value_ptr.*;

                        for (possible.items) |prod| {
                            if (prod.rhs.last_ptr.?.item == b.key_ptr.*) {
                                const count = if (prod.lhs < cnf.symbols.len) prev + 1 else prev;
                                try table[current].put(prod.lhs, count);
                            }
                        }
                    }
                }
            }
        }
    }

    var result = table[(sentence.len - 1) * sentence.len];
    return result.get(0);
}
