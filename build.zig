const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "3dtest",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const raylib = b.dependency("raylib", .{ .target = target, .optimize = optimize });

    // debugging shit
    //const dir_path = raylib.path("src").getPath(b);
    //std.debug.print("{u}\n", .{dir_path});

    // without this we cannot find rcamera.h
    // this is a mistake in raylib.build.zig
    exe.addIncludePath(raylib.path("src"));

    exe.linkLibrary(raylib.artifact("raylib"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
