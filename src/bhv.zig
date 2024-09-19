const std = @import("std");
const types = @import("types.zig");

const state = @import("state.zig");

// maximum depth of nodes
const MAX_DEPTH = 2;

// its actually bvh not bhv lol
//
fn printNTimes(char: u8, n: usize) void {
    for (0..n) |_| {
        std.debug.print("{c}", .{char});
    }
}

pub const BhvNode = struct {
    handles: std.ArrayList(types.ObjectHandle),

    bb: types.BoundingBox,

    is_divided: bool,
    left: *BhvNode,
    right: *BhvNode,

    pub fn draw(self: BhvNode) void {
        self.bb.drawEdges();
        if (self.is_divided) {
            self.left.bb.drawEdges();
            self.right.bb.drawEdges();
        }
    }

    // i dont know how to print prett
    pub fn prettyPrint(self: BhvNode, depth: u16) void {
        //:
        std.debug.print("node min: ", .{});
        types.printVec(self.bb.min);
        std.debug.print("\n", .{});

        printNTimes('\t', depth);
        std.debug.print("node max: ", .{});
        types.printVec(self.bb.max);
        std.debug.print("\n", .{});
        printNTimes('\t', depth);

        if (!self.is_divided) {
            return;
        }

        std.debug.print("left: \n", .{});
        printNTimes('\t', depth);
        self.left.prettyPrint(depth + 1);

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

            if (ob.bb.center()[axis] >= self.bb.center()[axis]) {
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
