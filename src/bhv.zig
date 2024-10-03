const std = @import("std");
const types = @import("types.zig");

const state = @import("state.zig");

// maximum depth of nodes
const MAX_DEPTH = 4;

fn printNTimes(char: u8, n: usize) void {
    for (0..n) |_| {
        std.debug.print("{c}", .{char});
    }
}

// debug functgio
fn colorFromDepth(d: u16) types.raylib.Color {
    return switch (d) {
        0 => types.raylib.PINK,
        1 => types.raylib.BLUE,
        2 => types.raylib.YELLOW,
        3 => types.raylib.PURPLE,
        else => types.raylib.BLACK,
    };
}

// its actually bvh not bhv lol
//
pub const BhvNode = struct {
    handles: std.ArrayList(types.ObjectHandle),

    bb: types.BoundingBox,

    is_divided: bool,
    left: *BhvNode,
    right: *BhvNode,

    pub fn draw(self: BhvNode, d: u16) void {
        self.bb.drawEdges(colorFromDepth(d));
        if (self.is_divided) {
            self.left.draw(d + 1);
            self.right.draw(d + 1);
        }
    }

    pub fn prettyPrint(self: BhvNode, depth: u16) void {
        printNTimes('\t', depth);
        std.debug.print("node min: ", .{});
        types.printVec(self.bb.min);
        std.debug.print("\n", .{});

        printNTimes('\t', depth);
        std.debug.print("node max: ", .{});
        types.printVec(self.bb.max);
        std.debug.print("\n", .{});

        printNTimes('\t', depth);
        std.debug.print("bb size: ", .{});
        types.printVec(self.bb.getSize());
        std.debug.print("\n", .{});

        if (!self.is_divided) {
            return;
        }

        printNTimes('\t', depth);
        std.debug.print("left: \n", .{});
        printNTimes('\t', depth);
        self.left.prettyPrint(depth + 1);

        printNTimes('\t', depth);
        std.debug.print("right: \n", .{});
        printNTimes('\t', depth);
        self.right.prettyPrint(depth + 1);
    }

    // when inserting make the smallest bb that encapsulated all obs
    // the bb of this node should grow to include whatever object is given
    pub fn insert(self: *BhvNode, obj: types.ObjectHandle) !void {
        try self.handles.append(obj);
        self.bb.growToInc(obj);
    }

    pub fn queryBB(self: BhvNode, bb: types.BoundingBox, allocator: std.mem.Allocator) ?std.ArrayList(types.ObjectHandle) {
        // if this does not intersect we just return
        if (!self.bb.intersects(bb)) {
            return null;
        }

        // we are inside and is last node... return all handles
        if (!self.is_divided) {
            return self.handles;
        }

        // we are inside but we have children
        // so get items from children

        var list = std.ArrayList(types.ObjectHandle).init(allocator);
        const l = self.left.queryBB(bb, allocator);
        const r = self.right.queryBB(bb, allocator);

        if (r) |items| {
            for (items.items) |item| {
                list.append(item) catch unreachable;
            }
        }

        if (l) |items| {
            for (items.items) |item| {
                list.append(item) catch unreachable;
            }
        }

        return list;
    }

    // make children..
    pub fn divide(self: *BhvNode, allocator: std.mem.Allocator, depth: u8) !void {
        if (depth >= MAX_DEPTH)
            return;

        self.left = try allocator.create(BhvNode);
        self.left.init(allocator);
        self.right = try allocator.create(BhvNode);
        self.right.init(allocator);

        for (self.handles.items) |item| {
            const ob = state.gameState.getObject(item);

            const axis = self.bb.getLongestSide();

            if (ob.bb.center()[axis] < self.bb.center()[axis]) {
                try self.left.insert(item);
            } else {
                try self.right.insert(item);
            }
        }

        self.is_divided = true;
        try self.left.divide(allocator, depth + 1);
        try self.right.divide(allocator, depth + 1);
    }
    pub fn init(self: *BhvNode, allocator: std.mem.Allocator) void {
        self.handles = std.ArrayList(types.ObjectHandle).init(allocator);
        self.bb.setInit();
        self.is_divided = false;
    }
};
