const std = @import("std");

const raylib = @cImport({
    @cInclude("raylib.h");
});

const bhv = @import("bhv.zig");
const BhvNode = bhv.BhvNode;

const types = @import("types.zig");
const ObjectHandle = types.ObjectHandle;
const Object = types.Object;
const BoundingBox = types.BoundingBox;
const Vec3 = types.Vec3;

const GameState = @import("state.zig");

const WINDOW_W = 1000;
const WINDOW_H = 800;

const NUM_OF_OBJ = 5;

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

// something is wrong
// it seems like we are not splitting as much as we should be
// i do not know if it splits but the rect is equal to the parent
// i need to fix this

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpallocator = gpa.allocator();

    GameState.gameState = try gpallocator.create(GameState.GameState);

    GameState.gameState.setDefaults(std.ArrayList(Object).init(gpallocator));

    for (0..NUM_OF_OBJ) |_| {
        try GameState.gameState.objects.append(Object.make(types.getRandomLocation()));
    }

    //
    var bvhPool = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    GameState.gameState.bhv.init(bvhPool.allocator());
    try GameState.gameState.constructBhvTree(&bvhPool);

    raylib.SetConfigFlags(raylib.FLAG_MSAA_4X_HINT);
    raylib.InitWindow(WINDOW_W, WINDOW_H, "game window");
    defer raylib.CloseWindow();

    var camera: raylib.Camera = .{
        .position = raylib.Vector3{ .x = 0.0, .y = 2.0, .z = 4.0 },
        .target = raylib.Vector3{ .x = 0.0, .y = 2.0, .z = 0.0 },
        .up = raylib.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 90.0,
        .projection = raylib.CAMERA_PERSPECTIVE,
    };

    const camMode = raylib.CAMERA_FIRST_PERSON;

    raylib.DisableCursor();
    //raylib.SetTargetFPS(60);
    //
    ////GameState.gameState.bhv.prettyPrint(0);

    while (!raylib.WindowShouldClose()) {
        raylib.UpdateCamera(&camera, camMode);

        raylib.BeginDrawing();
        defer raylib.EndDrawing();
        raylib.ClearBackground(raylib.WHITE);

        {
            raylib.BeginMode3D(camera);
            defer raylib.EndMode3D();
            //
            raylib.DrawPlane(
                raylib.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 },
                raylib.Vector2{ .x = 32.0, .y = 32.0 },
                raylib.BLACK,
            );
            for (GameState.gameState.objects.items) |obj| {
                raylib.DrawCube(convVec(obj.mesh.pos), types.cubeSize[0], types.cubeSize[0], types.cubeSize[0], raylib.GREEN);
                //obj.bb.drawEdges();
            }
            GameState.gameState.bhv.draw();
        }
        //

        var bffr: [10]u8 = [_]u8{0} ** 10;
        _ = try std.fmt.bufPrint(&bffr, "FPS {d}", .{raylib.GetFPS()});
        raylib.DrawText(&bffr, 15, 15, 20, raylib.GREEN);
    }
}
