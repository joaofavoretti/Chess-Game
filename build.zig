const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Core library module
    const core_mod = b.createModule(.{
        // This module is used to build the core library, which is a static library.
        // It will be linked into the executable later.
        .root_source_file = b.path("src/core/core.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Engine library module
    const engine_mod = b.createModule(.{
        // This module is used to build the core library, which is a static library.
        // It will be linked into the executable later.
        .root_source_file = b.path("src/engine/engine.zig"),
        .target = target,
        .optimize = optimize,
    });
    engine_mod.addImport("core", core_mod);

    // Controller library module
    const controller_mod = b.createModule(.{
        // This module is used to build the core library, which is a static library.
        // It will be linked into the executable later.
        .root_source_file = b.path("src/controller/controller.zig"),
        .target = target,
        .optimize = optimize,
    });
    controller_mod.addImport("core", core_mod);
    controller_mod.addImport("engine", engine_mod);

    // View library module
    const view_mod = b.createModule(.{
        // This module is used to build the core library, which is a static library.
        // It will be linked into the executable later.
        .root_source_file = b.path("src/view/view.zig"),
        .target = target,
        .optimize = optimize,
    });
    view_mod.addImport("core", core_mod);
    view_mod.addImport("controller", controller_mod);

    // We will also create a module for our other entry point, 'main.zig'.
    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("core", core_mod);
    exe_mod.addImport("view", view_mod);
    exe_mod.addImport("controller", controller_mod);
    exe_mod.addImport("engine", engine_mod);

    const core = b.addLibrary(.{
        .linkage = .static,
        .name = "core",
        .root_module = core_mod,
    });

    const view = b.addLibrary(.{
        .linkage = .static,
        .name = "view",
        .root_module = view_mod,
    });

    const controller = b.addLibrary(.{
        .linkage = .static,
        .name = "controller",
        .root_module = controller_mod,
    });

    const engine = b.addLibrary(.{
        .linkage = .static,
        .name = "engine",
        .root_module = engine_mod,
    });

    b.installArtifact(core);
    b.installArtifact(engine);
    b.installArtifact(controller);
    b.installArtifact(view);

    // This creates another `std.Build.Step.Compile`, but this one builds an executable
    // rather than a static library.
    const exe = b.addExecutable(.{
        .name = "Chess_Game",
        .root_module = exe_mod,
        .use_llvm = false,
        .use_lld = false,
    });

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    view_mod.addImport("raylib", raylib);
    view_mod.addImport("raygui", raygui);

    exe.linkLibrary(raylib_artifact);
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    const ziglangSet = b.dependency("ziglangSet", .{});
    // const ziglangSet_artifact = ziglangSet.artifact("ziglangSet");
    // exe.linkLibrary(ziglangSet_artifact);

    exe.root_module.addImport("ziglangSet", ziglangSet.module("ziglangSet"));

    exe.linkLibC();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const core_unit_tests = b.addTest(.{
        .root_module = core_mod,
    });
    const run_core_unit_tests = b.addRunArtifact(core_unit_tests);

    const engine_unit_tests = b.addTest(.{
        .root_module = engine_mod,
    });
    const run_engine_unit_tests = b.addRunArtifact(engine_unit_tests);

    const controller_unit_tests = b.addTest(.{
        .root_module = controller_mod,
    });
    const run_controller_unit_tests = b.addRunArtifact(controller_unit_tests);

    const view_unit_tests = b.addTest(.{
        .root_module = view_mod,
    });
    const run_view_unit_tests = b.addRunArtifact(view_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_core_unit_tests.step);
    test_step.dependOn(&run_engine_unit_tests.step);
    test_step.dependOn(&run_controller_unit_tests.step);
    test_step.dependOn(&run_view_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
