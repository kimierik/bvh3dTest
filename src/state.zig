const std = @import("std");

const bhv = @import("bhv.zig");
const BhvNode = bhv.BhvNode;

const types = @import("types.zig");
const ObjectHandle = types.ObjectHandle;
const Object = types.Object;
const BoundingBox = types.BoundingBox;

pub const GameState = struct {
    const Self = @This();

    bhv: BhvNode,
    objects: std.ArrayList(Object),

    pub fn setDefaults(self: *Self, objects: std.ArrayList(Object)) void {
        self.objects = objects; // autofix
    }

    pub fn constructBhvTree(self: *Self, pool: *std.heap.ArenaAllocator) !void {
        //start distributing object handles to root
        //
        const allocator = pool.allocator();
        for (0..self.objects.items.len) |i| {
            try self.bhv.insert(ObjectHandle{ .pointer = @intCast(i) });
        }
        try self.bhv.divide(allocator, 0);
    }

    pub fn getObject(self: Self, handle: ObjectHandle) Object {
        return self.objects.items[handle.pointer];
    }
};

pub var gameState: *GameState = undefined;
