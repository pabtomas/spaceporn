const std = @import ("std");

const glfw = @import ("libs/mach-glfw/build.zig");
const vkgen = @import ("libs/vulkan-zig/generator/index.zig");
const zigvulkan = @import ("libs/vulkan-zig/build.zig");

pub fn build (builder: *std.build.Builder) !void
{
  const build_options = builder.addOptions ();
  const EXE = "spacedream";
  const DEV = builder.option (bool, "DEV", "Build " ++ EXE ++ " in dev mode") orelse false;
  const TURBO = builder.option (bool, "TURBO", "Build " ++ EXE ++ " without logging feature") orelse false;

  if (TURBO and DEV)
  {
    std.log.err ("TURBO and DEV can not be used together.", .{});
    std.process.exit (1);
  }

  var LOGDIR: [] const u8 = undefined;

  if (DEV)
  {
    var buffer: [std.fs.MAX_PATH_BYTES] u8 = undefined;
    const cwd = try std.os.getcwd (&buffer);

    var gpa = std.heap.GeneralPurposeAllocator (.{}){};
    defer _ = gpa.deinit ();
    const allocator = gpa.allocator ();

    var log = try std.ArrayList (u8).initCapacity (allocator, cwd.len + 4);
    defer log.deinit ();

    try log.appendSlice (cwd);
    try log.appendSlice ("/log");

    var log_help = try std.ArrayList (u8).initCapacity (allocator, cwd.len + 55);
    defer log_help.deinit ();

    try log_help.appendSlice ("Specify log directory (must be absolute). Default: ");
    try log_help.appendSlice (log.items);

    LOGDIR = builder.option ([] const u8, "LOG", log_help.items) orelse log.items;
    build_options.addOption ([] const u8, "LOGDIR", LOGDIR);

    std.fs.makeDirAbsolute (LOGDIR) catch |err|
    {
      if (err != std.fs.File.OpenError.PathAlreadyExists)
      {
        return err;
      }
    };
  } else if (!TURBO) {
    const default_LOGDIR = "/var/log/" ++ EXE;
    LOGDIR = builder.option ([] const u8, "LOG", "Specify log directory (must be absolute). Default: " ++ default_LOGDIR) orelse default_LOGDIR;
    build_options.addOption ([] const u8, "LOGDIR", LOGDIR);

    std.fs.makeDirAbsolute (LOGDIR) catch |err|
    {
      if (err != std.fs.File.OpenError.PathAlreadyExists)
      {
        return err;
      }
    };
  }

  build_options.addOption ([] const u8, "EXE", EXE);

  if (DEV)
  {
    build_options.addOption (u8, "LOG_LEVEL", 2);
  } else if (TURBO) {
    build_options.addOption (u8, "LOG_LEVEL", 0);
  } else {
    build_options.addOption (u8, "LOG_LEVEL", 1);
  }

  const target = builder.standardTargetOptions (.{});
  const mode = builder.standardOptimizeOption (.{});

  const exe = builder.addExecutable (.{
    .name = EXE,
    .root_source_file = .{ .path = "src/main.zig" },
    .target = target,
    .optimize = mode,
  });

  exe.addOptions ("build_options", build_options);

  // Init a new install artifact step that will copy exe into destination directory
  const install_exe = builder.addInstallArtifact (exe);

  // Install step must be made after install artifact step is made
  builder.getInstallStep ().dependOn (&install_exe.step);

  // vulkan-zig: new step that generates vk.zig (stored in zig-cache) from the provided vulkan registry.
  const gen = vkgen.VkGenerateStep.create (builder, "libs/vulkan-zig/examples/vk.xml");
  exe.addModule ("vulkan", gen.getModule ());

  // mach-glfw
  exe.addModule ("glfw", glfw.module (builder));
  try glfw.link (builder, exe, .{});

  // shader resources, to be compiled using glslc
  const shaders = vkgen.ShaderCompileStep.create (
    builder,
    &[_][] const u8 { "glslc", "--target-env=vulkan1.2" },
    "-o",
  );
  shaders.add ("triangle_vert", "shaders/main.vert", .{});
  shaders.add ("triangle_frag", "shaders/main.frag", .{});
  exe.addModule ("resources", shaders.getModule ());

  // Init a new run artifact step that will run exe (invisible for user)
  const run_cmd = builder.addRunArtifact (exe);

  // Run artifact step must be made after install step is made
  run_cmd.step.dependOn (builder.getInstallStep());

  // Allow to pass arguments from the zig build command line: zig build run -- -o foo.bin foo.asm
  if (builder.args) |args|
  {
    run_cmd.addArgs (args);
  }

  // Init a new step (visible for user)
  const run_step = builder.step ("run", "Run the app");

  // New step must be made after run artifact step is made
  run_step.dependOn (&run_cmd.step);
}
