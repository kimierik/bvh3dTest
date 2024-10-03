const std = @import("std");

pub const raylib = @cImport({
    @cDefine("SUPPORT_CAMERA_SYSTEM", "1");
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rcamera.h");
});

const rc = raylib;

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

    //
    //box1 = (x:(xmin1,xmax1),y:(ymin1,ymax1),z:(zmin1,zmax1))
    //box2 = (x:(xmin2,xmax2),y:(ymin2,ymax2),z:(zmin2,zmax2))
    //isOverlapping3D(box1,box2) =
    //(box1.max.x >= box2.min.x and box2.max.x >= box1.min.x) and
    //                            (box1.max.y >= box2.min.y and box2.max.y >= box1.min.y)and
    //:width                           (box1.max.z >= box2.min.z and box2.max.z >= box1.min.z)
    pub fn intersects(self: BoundingBox, other: BoundingBox) bool {
        // should work???
        return (self.max[0] >= other.min[0] and other.max[0] >= self.min[0]) and
            (self.max[1] >= other.min[1] and other.max[1] >= self.min[1]) and
            (self.max[2] >= other.min[2] and other.max[2] >= self.min[2]);
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

// player entity
pub const Entity = struct {
    const Self = @This();

    pos: Vec3,
    rotation: Vec3,
    velocity: Vec3,
    acceleration: Vec3,

    bb: BoundingBox,
    size: Vec3,

    //
    pub fn init(pos: Vec3, size: Vec3) Self {
        return Self{
            .pos = pos,
            .rotation = @splat(0),
            .size = size,
            .velocity = @splat(0),
            .acceleration = @splat(0),
            .bb = BoundingBox.init(), // ?
        };
    }

    /// updates bb to move with position
    pub fn updateBB(self: *Self) void {
        self.bb.min = self.pos - self.size;
        self.bb.max = self.pos + self.size;
    }

    fn getUpdatedBB(self: Self, offset: Vec3) BoundingBox {
        return .{
            .min = self.pos + offset - self.size,
            .max = self.pos + offset + self.size,
        };
    }

    pub fn handleMovement(self: *Self, arena: *std.heap.ArenaAllocator, camera: *raylib.Camera) void {
        const movement_speed: Vec3 = @splat(2);

        const forwardVec = convRVec(rc.GetCameraForward(camera));
        const sidewayVec = convRVec(rc.GetCameraRight(camera));
        // movement vector
        var mvec: Vec3 = @splat(0);

        const allocator = arena.allocator();

        // currenlyt no momentum
        self.velocity = @splat(0);
        self.acceleration = @splat(0);

        if (raylib.IsKeyDown(raylib.KEY_W)) {
            mvec += forwardVec * movement_speed;
        }

        if (raylib.IsKeyDown(raylib.KEY_S)) {
            mvec += forwardVec * -movement_speed;
        }

        if (raylib.IsKeyDown(raylib.KEY_A)) {
            mvec += sidewayVec * -movement_speed;
        }

        if (raylib.IsKeyDown(raylib.KEY_D)) {
            mvec += sidewayVec * movement_speed;
        }

        self.acceleration += mvec;

        self.velocity += self.acceleration * @as(Vec3, @splat(raylib.GetFrameTime()));

        const ubb = self.getUpdatedBB(self.velocity);
        const objsL = GameState.gameState.bhv.queryBB(ubb, allocator);

        if (objsL) |objs| {
            for (objs.items) |handle| {
                const ob = GameState.gameState.getObject(handle);
                // if ob intersect with the self bb then we collided and we should not do move
                if (ob.bb.intersects(ubb)) {
                    // we have collided with the thing
                    // currently stop all movement
                    self.velocity = @splat(0);
                    return;
                }
            }
        }
        // move
        self.pos += self.velocity;
        camera.target = raylib.Vector3Add(camera.target, convVec(self.velocity));
        self.updateBB();
    }
};
