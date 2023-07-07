const std = @import ("std");

const context_vk   = @import ("vk/context.zig").context_vk;
const context_glfw = @import ("glfw/context.zig").context_glfw;

const build   = @import ("build_options");
const LOG_DIR = build.LOG_DIR;

const utils    = @import ("utils.zig");
const log_app  = utils.log_app;
const log_file = utils.log_file;
const profile  = utils.profile;
const severity = utils.severity;

const opts = @import ("options.zig").options;

pub const context = struct
{
  glfw: context_glfw = undefined,
  vk:   context_vk   = undefined,

  const Self = @This ();

  fn init_logfile () !void
  {
    if (build.LOG_LEVEL > @intFromEnum (profile.TURBO) and build.LOG_DIR.len > 0)
    {
      var dir = std.fs.cwd ().openDir (LOG_DIR, .{}) catch |err|
      {
        if (err == std.fs.File.OpenError.FileNotFound)
        {
          try log_app ("{s} does not exist, impossible to log execution.", severity.ERROR, .{ LOG_DIR });
        }
        return err;
      };

      defer dir.close ();

      const file = std.fs.cwd ().openFile (log_file, .{}) catch |open_err| blk:
      {
        if (open_err != std.fs.File.OpenError.FileNotFound)
        {
          try log_app ("failed to open log file", severity.ERROR, .{});
          return open_err;
        } else {
          const cfile = std.fs.cwd ().createFile (log_file, .{}) catch |create_err|
          {
            try log_app ("failed to create log file", severity.ERROR, .{});
            return create_err;
          };
          break :blk cfile;
        }
      };

      defer file.close ();
    }
    try log_app ("log file init OK", severity.DEBUG, .{});
  }

  pub fn init (allocator: std.mem.Allocator, options: opts) !Self
  {
    try init_logfile ();

    var self = Self {};

    self.glfw = try context_glfw.init (options);

    self.vk = try context_vk.init_instance (&self.glfw.extensions, self.glfw.instance_proc_addr, allocator);

    var wrapper = self.vk.get_surface ();
    try self.glfw.init_surface (wrapper.instance, &wrapper.surface, wrapper.success);
    self.vk.set_surface (&wrapper.surface);

    const framebuffer = self.glfw.get_framebuffer_size ();
    try self.vk.init (.{ .width = framebuffer.width, .height = framebuffer.height, }, allocator);

    try log_app ("init OK", severity.DEBUG, .{});
    return self;
  }

  pub fn loop (self: *Self, options: opts) !void
  {
    var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
    var allocator = arena.allocator ();

    while (self.glfw.looping ())
    {
      try self.glfw.loop ();
      const framebuffer = self.glfw.get_framebuffer_size ();
      try self.vk.loop (.{ .resized = framebuffer.resized, .width = framebuffer.width, .height = framebuffer.height, }, &arena, &allocator, options);
    }
    try log_app ("loop OK", severity.DEBUG, .{});
  }

  pub fn cleanup (self: Self) !void
  {
    try self.vk.cleanup ();
    try self.glfw.cleanup ();
    try log_app ("cleanup OK", severity.DEBUG, .{});
  }
};
