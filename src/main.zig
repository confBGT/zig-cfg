const std = @import("std");
const FSMTokenizer = @import("fsm_tokenizer.zig").FSMTokenizer;

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var fsm = FSMTokenizer.init(allocator);
    defer fsm.deinit();

    const text = "S -> NP 'invalid' | VP | TER";
    const tokens = try fsm.tokenize(text);
    defer allocator.free(tokens);

    for (tokens) |token| {
        std.debug.print("{any}\n", .{token});
    }
}
