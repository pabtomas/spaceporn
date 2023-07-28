const std = @import ("std");

const build = @import ("build_options");

const utils    = @import ("utils.zig");
const exe      = utils.exe;
const log_app  = utils.log_app;
const profile  = utils.profile;
const severity = utils.severity;

pub const options = struct
{
  const Self = @This ();

  const DEFAULT_HELP = false;
  const SHORT_HELP   = "-h";
  const LONG_HELP    = "--help";
  const HELP_FLAGS   = "  " ++ SHORT_HELP ++ ", " ++ LONG_HELP;

  const DEFAULT_VERSION = false;
  const SHORT_VERSION   = "-v";
  const LONG_VERSION    = "--version";
  const VERSION_FLAGS   = "  " ++ SHORT_VERSION ++ ", " ++ LONG_VERSION;

  const DEFAULT_SEED = 0;

  const DEFAULT_WINDOW_WIDTH  = 800;
  const DEFAULT_WINDOW_HEIGHT = 600;

  const DEFAULT_CAMERA_DYNAMIC = false;

  const DEFAULT_CAMERA_PIXEL = 200;
  const CAMERA_PIXEL_MIN     = 100;
  const CAMERA_PIXEL_MAX     = 600;

  const DEFAULT_CAMERA_ZOOM = 1;
  const CAMERA_ZOOM_MIN     = 1;
  const CAMERA_ZOOM_MAX     = 40;

  const DEFAULT_COLORS_SMOOTH = false;

  const DEFAULT_STARS_DYNAMIC = false;

  const MAX_FLAGS_LEN = blk:
                        {
                          var max: usize = 0;
                          inline for (@typeInfo (Self).Struct.decls) |decl|
                          {
                            if (std.mem.endsWith (u8, decl.name, "_FLAGS"))
                            {
                              max = @max (max, @field (Self, decl.name).len);
                            }
                          }
                          break :blk max;
                        };

  const camera_options = struct
  {
    dynamic: bool = DEFAULT_CAMERA_DYNAMIC,
    pixel:   u32  = DEFAULT_CAMERA_PIXEL,
    zoom:    u32  = DEFAULT_CAMERA_ZOOM,
  };

  const colors_options = struct
  {
    smooth: bool = DEFAULT_COLORS_SMOOTH,
  };

  const stars_options = struct
  {
    dynamic: bool = DEFAULT_STARS_DYNAMIC,
  };

  help:    bool                                  = DEFAULT_HELP,
  seed:    u32                                   = DEFAULT_SEED,
  version: bool                                  = DEFAULT_VERSION,
  window:  struct { width: ?u32, height: ?u32, } = .{ .width = DEFAULT_WINDOW_WIDTH, .height = DEFAULT_WINDOW_HEIGHT, },
  camera:  camera_options                        = camera_options {},
  colors:  colors_options                        = colors_options {},
  stars:   stars_options                         = stars_options {},

  const OptionsError = error
  {
    NoExecutableName,
    MissingArgument,
    UnknownOption,
    UnknownArgument,
    ZeroIntegerArgument,
    OverflowArgument,
    Help,
    Version,
  };

  fn usage_help (self: *Self) void
  {
    _ = self;
    std.debug.print ("{s}{s} - Print this help\n", .{ HELP_FLAGS, " " ** (MAX_FLAGS_LEN - HELP_FLAGS.len), });
  }

  fn usage_version (self: *Self) void
  {
    _ = self;
    std.debug.print ("{s}{s} - Report the version\n", .{ VERSION_FLAGS, " " ** (MAX_FLAGS_LEN - VERSION_FLAGS.len), });
  }

  fn usage_seed (self: *Self) void
  {
    _ = self;
  }

  fn usage_window (self: *Self) void
  {
    _ = self;
  }

  fn usage_camera_dynamic (self: *Self) void
  {
    _ = self;
  }

  fn usage_camera_pixel (self: *Self) void
  {
    _ = self;
  }

  fn usage_camera_zoom (self: *Self) void
  {
    _ = self;
  }

  fn usage_camera (self: *Self) void
  {
    inline for (std.meta.fields (@TypeOf (self.camera))) |field|
    {
      @call (.auto, @field (Self, "usage_camera_" ++ field.name), .{ self });
    }
  }

  fn usage_colors_smooth (self: *Self) void
  {
    _ = self;
  }

  fn usage_colors (self: *Self) void
  {
    inline for (std.meta.fields (@TypeOf (self.colors))) |field|
    {
      @call (.auto, @field (Self, "usage_colors_" ++ field.name), .{ self });
    }
  }

  fn usage_stars_dynamic (self: *Self) void
  {
    _ = self;
  }

  fn usage_stars (self: *Self) void
  {
    inline for (std.meta.fields (@TypeOf (self.stars))) |field|
    {
      @call (.auto, @field (Self, "usage_stars_" ++ field.name), .{ self });
    }
  }

  fn usage (self: *Self) void
  {
    std.debug.print ("\nUsage: {s} [OPTION] ...\n\nGenerator for space contemplators\n\nOptions:\n", .{ utils.exe });
    inline for (std.meta.fields (@TypeOf (self.*))) |field|
    {
      @call (.auto, @field (Self, "usage_" ++ field.name), .{ self });
    }
    std.debug.print ("\nThe {s} home page: http://www.github.com/tiawl/spaceporn\nReport {s} bugs to http://www.github.com/tiawl/spaceporn/issues\n\n", .{ utils.exe, utils.exe });
  }

  fn print_version (self: Self) void
  {
    _ = self;
    std.debug.print ("{s} {s}\n", .{ exe, build.VERSION, });
  }

  fn parse (self: *Self, allocator: std.mem.Allocator, opts: *std.ArrayList ([] const u8)) !void
  {
    var index: usize = 0;
    var new_opt_used = false;
    var new_opt: [] const u8 = undefined;

    while (index < opts.items.len)
    {
      // Handle '-abc' the same as '-a -bc' for short-form no-arg options
      if (opts.items [index][0] == '-' and opts.items [index].len > 2
          and (opts.items [index][1] == SHORT_HELP [1]
            or opts.items [index][1] == SHORT_VERSION [1]
              )
         )
      {
        try opts.insert (index + 1, opts.items [index][0..2]);
        new_opt = try std.fmt.allocPrint (allocator, "-{s}", .{ opts.items [index][2..] });
        new_opt_used = true;
        try opts.insert (index + 2, new_opt);
        _ = opts.orderedRemove (index);
        continue;
      }

      // /!\ KEEP THIS FOR POTENTIAL REUSE /!\
      // Handle '-foo' the same as '-f oo' for short-form 1-arg options
      // if (opts.items [index][0] == '-' and opts.items [index].len > 2
      //     and (opts.items [index][1] == SHORT_OUTPUT [1]
      //       or opts.items [index][1] == SHORT_SEED [1]
      //         )
      //    )
      // {
      //   try opts.insert (index + 1, opts.items [index][0..2]);
      //   try opts.insert (index + 2, opts.items [index][2..]);
      //   _ = opts.orderedRemove (index);
      //   continue;
      // }
      // /!\ KEEP THIS FOR POTENTIAL REUSE /!\

      // /!\ KEEP THIS FOR POTENTIAL REUSE /!\
      // Handle '--file=file1' the same as '--file file1' for long-form 1-arg options
      // if (    std.mem.startsWith (u8, opts.items [index], CAMERA_PIXEL ++ "=")
      //      or std.mem.startsWith (u8, opts.items [index], CAMERA_ZOOM ++ "=")
      //    )
      // {
      //   const eq_index = std.mem.indexOf (u8, opts.items [index], "=").?;
      //   try opts.insert (index + 1, opts.items [index][0..eq_index]);
      //   try opts.insert (index + 2, opts.items [index][(eq_index + 1)..]);
      //   _ = opts.orderedRemove (index);
      //   continue;
      // }
      // /!\ KEEP THIS FOR POTENTIAL REUSE /!\

      // help option
      if (std.mem.eql (u8, opts.items [index], SHORT_HELP) or std.mem.eql (u8, opts.items [index], LONG_HELP))
      {
        self.help = true;
      // version option
      } else if (std.mem.eql (u8, opts.items [index], SHORT_VERSION) or std.mem.eql (u8, opts.items [index], LONG_VERSION)) {
        self.version = true;

      // ---------------------------------------------------------------------

      } else {
        try log_app ("unknown option: '{s}'", severity.ERROR, .{ opts.items [index] });
        self.usage ();
        return OptionsError.UnknownOption;
      }

      index += 1;
    }
  }

  fn check (self: Self) !void
  {
    _ = self;
  }

  fn fix_random (self: *Self) void
  {
    self.seed = @intCast (@mod (std.time.milliTimestamp (), @as (i64, @intCast (std.math.maxInt (u32)))));

    self.camera.zoom = @intCast (@mod (std.time.milliTimestamp (), std.math.maxInt (u32)));
    self.camera.zoom = (self.camera.zoom % (CAMERA_ZOOM_MAX - CAMERA_ZOOM_MIN + 1)) + CAMERA_ZOOM_MIN;
  }

  fn show (self: Self) !void
  {
    try log_app ("seed: {d}", severity.INFO, .{ self.seed });
    try log_app ("window: {any}", severity.INFO, .{ self.window });

    try log_app ("camera dynamic: {}", severity.INFO, .{ self.camera.dynamic });
    try log_app ("camera pixel: {d}", severity.INFO, .{ self.camera.pixel });
    try log_app ("zoom: {d}", severity.INFO, .{ self.camera.zoom });

    try log_app ("colors smooth transition: {}", severity.INFO, .{ self.colors.smooth });

    try log_app ("stars dynamic transition: {}", severity.INFO, .{ self.stars.dynamic });
  }

  pub fn init (allocator: std.mem.Allocator) !Self
  {
    var self = Self {};

    var opts_iterator = try std.process.argsWithAllocator (allocator);
    defer opts_iterator.deinit();

    _ = opts_iterator.next () orelse
        {
          return OptionsError.NoExecutableName;
        };

    var opts = std.ArrayList ([] const u8).init (allocator);

    while (opts_iterator.next ()) |opt|
    {
      try opts.append (opt);
    }

    try self.parse (allocator, &opts);
    try self.check ();

    if (self.help)
    {
      self.usage ();
      return OptionsError.Help;
    } else if (self.version) {
      self.print_version ();
      return OptionsError.Version;
    }

    self.fix_random ();
    if (build.LOG_LEVEL > @intFromEnum (profile.TURBO)) try self.show ();

    return self;
  }

  pub fn init2 (allocator: std.mem.Allocator, opts: *std.ArrayList ([] const u8)) !Self
  {
    var self = Self {};

    try self.parse (allocator, opts);
    try self.check ();
    self.fix_random ();
    if (build.LOG_LEVEL > @intFromEnum (profile.TURBO)) try self.show ();

    return self;
  }
};

test "parse CLI args: empty"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  const opts = try options.init (allocator);

  try std.testing.expect (opts.help == options.DEFAULT_HELP);
  try std.testing.expect (opts.version == options.DEFAULT_VERSION);
}

test "parse CLI args: short-help"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  try opts_list.appendSlice (&[_][] const u8 { options.SHORT_HELP, });

  const opts = try options.init2 (allocator, &opts_list);

  try std.testing.expect (opts.help == true);
  try std.testing.expect (opts.version == options.DEFAULT_VERSION);
}

test "parse CLI args: short-help short-version"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  try opts_list.appendSlice (&[_][] const u8 {
                                               options.SHORT_HELP,
                                               options.SHORT_VERSION,
                                             });

  const opts = try options.init2 (allocator, &opts_list);

  try std.testing.expect (opts.help == true);
  try std.testing.expect (opts.version == true);
}

test "parse CLI args: combined short-help short-version"
{
  std.debug.print ("\n", .{});

  var arena = std.heap.ArenaAllocator.init (std.heap.page_allocator);
  defer arena.deinit ();
  var allocator = arena.allocator ();

  var opts_list = std.ArrayList ([] const u8).init (allocator);

  try opts_list.appendSlice (&[_][] const u8 { options.SHORT_HELP ++ options.SHORT_VERSION [1..], });

  const opts = try options.init2 (allocator, &opts_list);

  try std.testing.expect (opts.help == true);
  try std.testing.expect (opts.version == true);
}
