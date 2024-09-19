const std = @import("std");

const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

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

const GameState = @import("state.zig");

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

// why does max behave differently than min
// min atleast is somehwat somewhere idk where th fk this is
pub const BoundingBox = struct {
    // corners of the bb
    min: Vec3,
    max: Vec3,

    /// get centre of bounding box
    pub inline fn center(self: BoundingBox) Vec3 {
        return (self.min + self.max) * @as(Vec3, @splat(0.5));
    }

    // gets index of largest size in bb
    // x:0 y:1 z:2
    // i dont know if this works even rn
    pub fn getLongestSide(self: BoundingBox) usize {
        const size_x = @abs(self.min[0] - self.max[0]);
        const size_y = @abs(self.min[1] - self.max[1]);
        const size_z = @abs(self.min[2] - self.max[2]);
        const big = @max(@max(size_x, size_y), size_z);
        if (big == size_x) {
            return 0;
        }
        if (big == size_y) {
            return 1;
        }
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

    pub fn drawEdges(self: BoundingBox) void {
        const centre = self.center();
        // this is the problem
        // we need to get the size of the thing not use cubesize
        raylib.DrawCubeWiresV(convVec(centre), convVec(self.min - self.max), raylib.PINK);
    }

    // bb is size of the cuve
    // how the fk do we do grow to inc
    fn growToIncCube(self: *BoundingBox, cube: Cube) void {
        self.min = @min(self.min, cube.pos - cubeSize);
        self.max = @max(self.max, cube.pos + cubeSize);
        //self.max = raylib.Vector3Max(self.max, raylib.Vector3Add(convVec(cube.pos), cubeSize));
    }

    pub fn growToInc(self: *BoundingBox, obj: ObjectHandle) void {
        self.growToIncCube(GameState.gameState.getObject(obj).mesh);
    }
};
