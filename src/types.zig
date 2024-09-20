const std = @import("std");

pub const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const GameState = @import("state.zig");

const rGenerator = std.rand.DefaultPrng;
var rnd = rGenerator.init(0);
const rand = rnd.random();

pub const Vec3 = @Vector(3, f32);

pub fn printVec(v: Vec3) void {
    std.debug.print("x:{any} y{any} z{any}", .{ v[0], v[1], v[2] });
}

inline fn convVec(v: Vec3) raylib.Vector3 {
    return .{
        .x = v[0],
        .y = v[1],
        .z = v[2],
    };
}

inline fn convRVec(v: raylib.Vector3) Vec3 {
    return .{
        v.x,
        v.y,
        v.z,
    };
}

const minpos = -32.0;
const maxpos = 32.0;

pub fn getRandomLocation() Vec3 {
    return .{
        rand.float(f32) * (maxpos - minpos) + minpos,
        rand.float(f32) * (maxpos - minpos) + minpos,
        rand.float(f32) * (maxpos - minpos) + minpos,
    };
}

pub const cubeSize: Vec3 = .{ 5, 5, 5 };

const Cube = struct {
    pos: Vec3,
};

// would be any mesh but now this is only cube
pub const Object = struct {
    // this should prob be enum if multiple things
    mesh: Cube,
    bb: BoundingBox,

    // position is centre
    pub fn make(pos: Vec3) Object {
        var returnObj: Object = undefined;
        returnObj.mesh = .{
            .pos = pos,
        };
        returnObj.bb.setInit();

        //std.debug.print("min:{any} max:{any}\n", .{ std.math.floatMin(f32), std.math.floatMax(f32) });
        returnObj.bb.growToIncCube(returnObj.mesh);
        return returnObj;
    }
};

// DOD principle
// dont have pointers or data in struct that we might delet later
pub const ObjectHandle = struct {
    pointer: u16,
};

pub const BoundingBox = struct {
    // corners of the bb
    min: Vec3,
    max: Vec3,

    /// get centre of bounding box
    pub inline fn center(self: BoundingBox) Vec3 {
        return (self.min + self.max) * @as(Vec3, @splat(0.5));
    }
    pub inline fn getSize(self: BoundingBox) Vec3 {
        return self.min - self.max;
    }

    // gets index of largest size in bb
    // x:0 y:1 z:2
    pub fn getLongestSide(self: BoundingBox) usize {
        const sized = self.getSize();
        const size_x = @abs(sized[0]);
        const size_y = @abs(sized[1]);
        const size_z = @abs(sized[2]);

        const big = @max(@max(size_x, size_y), size_z);

        if (big == size_x) {
            return 0;
        }

        if (big == size_y) {
            return 1;
        }

        if (big == size_z) {
            return 2;
        }

        // just in case
        return 2;
    }

    /// inits bounding box from -inf to + inf
    pub fn init() BoundingBox {
        return .{
            .min = @splat(std.math.floatMax(f32)),
            .max = @splat(-std.math.floatMax(f32)),
        };
    }

    /// set values to default
    pub fn setInit(self: *BoundingBox) void {
        self.min = @splat(std.math.floatMax(f32));
        self.max = @splat(-std.math.floatMax(f32));
    }

    pub fn drawEdges(self: BoundingBox, c: raylib.Color) void {
        const centre = self.center();
        raylib.DrawCubeWiresV(convVec(centre), convVec(self.min - self.max), c);
    }

    fn growToIncCube(self: *BoundingBox, cube: Cube) void {
        self.min = @min(self.min, cube.pos - cubeSize / @as(Vec3, @splat(2)));
        self.max = @max(self.max, cube.pos + cubeSize / @as(Vec3, @splat(2)));
    }

    pub fn growToInc(self: *BoundingBox, obj: ObjectHandle) void {
        self.growToIncCube(GameState.gameState.getObject(obj).mesh);
    }
};
