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

        pub fn deinit(self: *Self) void {
            var node_ptr = self.start_ptr;
            while (node_ptr) |node| {
                node_ptr = node.next;
                self.allocator.destroy(node);
            }
            self.* = undefined;
        }


        const Iterator = struct {
            current: ?*Node,

            pub fn next(it: *Iterator) ?T {
                var ret: ?T = null;

                if (it.current) |node| {
                    ret = node.item;
                    it.current = node.next;
                }

                return ret;
            }
        };

        pub fn iterator(self: Self) Iterator {
            return Iterator { .current = self.start_ptr };
        }
    };
}
