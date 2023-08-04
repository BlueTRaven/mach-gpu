const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const gpu_dawn = @import("mach_gpu_dawn");
    const gpu = Sdk(.{
        .gpu_dawn = gpu_dawn,
    });

    const gpu_dawn_options = gpu_dawn.Options{
        .from_source = b.option(bool, "dawn-from-source", "Build Dawn from source") orelse false,
        .debug = b.option(bool, "dawn-debug", "Use a debug build of Dawn") orelse false,
    };

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&(try gpu.testStep(b, optimize, target, .{ .gpu_dawn_options = gpu_dawn_options })).step);

    const example = b.addExecutable(.{
        .name = "gpu-hello-triangle",
        .root_source_file = .{ .path = "examples/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    example.addModule("gpu", gpu.module(b));
    try gpu.link(b, example, .{ .gpu_dawn_options = gpu_dawn_options });
    glfwLink(b, example);
    b.installArtifact(example);

    const example_run_cmd = b.addRunArtifact(example);
    example_run_cmd.step.dependOn(b.getInstallStep());
    const example_run_step = b.step("run-example", "Run the example");
    example_run_step.dependOn(&example_run_cmd.step);
}

fn glfwLink(b: *std.Build, step: *std.build.CompileStep) void {
    const glfw_dep = b.dependency("mach_glfw", .{
        .target = step.target,
        .optimize = step.optimize,
    });
    step.linkLibrary(glfw_dep.artifact("mach-glfw"));
    step.addModule("glfw", glfw_dep.module("mach-glfw"));

    // TODO(build-system): Zig package manager currently can't handle transitive deps like this, so we need to use
    // these explicitly here:
    @import("glfw").addPaths(step);
    if (step.target.toTarget().isDarwin()) @import("xcode_frameworks").addPaths(b, step);
    step.linkLibrary(b.dependency("vulkan_headers", .{
        .target = step.target,
        .optimize = step.optimize,
    }).artifact("vulkan-headers"));
    step.linkLibrary(b.dependency("x11_headers", .{
        .target = step.target,
        .optimize = step.optimize,
    }).artifact("x11-headers"));
    step.linkLibrary(b.dependency("wayland_headers", .{
        .target = step.target,
        .optimize = step.optimize,
    }).artifact("wayland-headers"));
}

pub fn Sdk(comptime deps: anytype) type {
    return struct {
        pub fn testStep(b: *std.Build, optimize: std.builtin.OptimizeMode, target: std.zig.CrossTarget, options: Options) !*std.build.RunStep {
            const main_tests = b.addTest(.{
                .name = "gpu-tests",
                .root_source_file = .{ .path = sdkPath("/src/main.zig") },
                .target = target,
                .optimize = optimize,
            });
            try link(b, main_tests, options);
            b.installArtifact(main_tests);
            return b.addRunArtifact(main_tests);
        }

        pub const Options = struct {
            gpu_dawn_options: deps.gpu_dawn.Options = .{},
        };

        var _module: ?*std.build.Module = null;

        pub fn module(b: *std.Build) *std.build.Module {
            if (_module) |m| return m;
            _module = b.createModule(.{
                .source_file = .{ .path = sdkPath("/src/main.zig") },
            });
            return _module.?;
        }

        pub fn link(b: *std.Build, step: *std.build.CompileStep, options: Options) !void {
            if (step.target.toTarget().cpu.arch != .wasm32) {
                try deps.gpu_dawn.link(b, step, options.gpu_dawn_options);
                step.addCSourceFile(.{ .file = .{ .path = sdkPath("/src/mach_dawn.cpp") }, .flags = &.{"-std=c++17"} });
                step.addIncludePath(.{ .path = sdkPath("/src") });
            }
        }

        fn sdkPath(comptime suffix: []const u8) []const u8 {
            if (suffix[0] != '/') @compileError("suffix must be an absolute path");
            return comptime blk: {
                const root_dir = std.fs.path.dirname(@src().file) orelse ".";
                break :blk root_dir ++ suffix;
            };
        }
    };
}
