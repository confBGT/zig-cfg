const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_compile = b.addTest(.{
        .name = "cfg",
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_run = b.addRunArtifact(test_compile);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_run.step);
}
