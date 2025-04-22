const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn LinkedList(comptime T: type) type {
    return struct {
        allocator: Allocator,
        start_ptr: ?*Node,
        last_ptr: ?*Node,
        count: usize,

        const Self = @This();

        const Node = struct {
            item: T,
            next: ?*Node,
        };

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .start_ptr = null,
                .last_ptr = null,
                .count = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            var node_ptr = self.start_ptr;
            while (node_ptr) |node| {
                node_ptr = node.next;
                self.allocator.destroy(node);
            }
            self.* = undefined;
        }

        pub fn clone(self: Self) !Self {
            var ret = init(self.allocator);

            var it = self.iterator();
            while (it.next()) |item| {
                try ret.append(item.*);
            }

            return ret;
        }

        pub fn append(self: *Self, item: T) !void {
            const new_node_ptr = try self.allocator.create(Node);
            new_node_ptr.* = Node { .item = item, .next = null };

            if (self.last_ptr) |last_ptr| {
                last_ptr.next = new_node_ptr;
            } else {
                self.start_ptr = new_node_ptr;
            }

            self.last_ptr = new_node_ptr;
            self.count += 1;
        }

        pub fn head(self: Self) ?T {
            if (self.start_ptr) |start_ptr| {
                return start_ptr.item;
            }
            return null;
        }

        pub fn splitHead(self: *Self) Self {
            std.debug.assert(self.start_ptr != null);

            const ret = Self { 
                .allocator = self.allocator,
                .start_ptr = self.start_ptr.?.next,
                .last_ptr = self.last_ptr,
                .count = self.count - 1,
            };

            self.last_ptr = self.start_ptr;
            self.start_ptr.?.next = null;
            self.count = 1;

            return ret;
        }

        const Iterator = struct {
            current: ?*Node,
            pub fn next(it: *Iterator) ?*T {
                if (it.current) |node| {
                    it.current = node.next;
                    return &node.item;
                }
                return null;
            }
        };

        pub fn iterator(self: Self) Iterator {
            return Iterator { .current = self.start_ptr };
        }
    };
}
