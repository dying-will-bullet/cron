<h1 align="center"> cron ⏳ </h1>

[![CI](https://github.com/dying-will-bullet/cron/actions/workflows/ci.yaml/badge.svg)](https://github.com/dying-will-bullet/cron/actions/workflows/ci.yaml)
![](https://img.shields.io/badge/language-zig-%23ec915c)

**NOTE: Minimum Supported Zig Version is 0.12.**

This library aims to provide a way to parse crontab schedule entries and determine the next execution time.

## Supported format

| Field Name   | Mandatory | Allowed Values  | Default Value | Allowed Special Characters |
| ------------ | --------- | --------------- | ------------- | -------------------------- |
| Seconds      | No        | 0-59            | 0             | \* / , -                   |
| Minutes      | Yes       | 0-59            | N/A           | \* / , -                   |
| Hours        | Yes       | 0-23            | N/A           | \* / , -                   |
| Day of month | Yes       | 1-31            | N/A           | \* / , - ? L               |
| Month        | Yes       | 1-12 or JAN-DEC | N/A           | \* / , -                   |
| Day of week  | Yes       | 0-6 or SUN-SAT  | N/A           | \* / , - ? L               |
| Year         | No        | 1970-2099       | \*            | \* / , -                   |

_W and # symbols are **not** supported._

If your cron entry has 5 values, minutes-day of week are used, default seconds is and default year is appended.
If your cron entry has 6 values, minutes-year are used, and default seconds are prepended.
As such, only 5-7 value crontab entries are accepted (and mangled to 7 values, as necessary).

This library also supports the convenient aliases:

- @yearly
- @annually
- @monthly
- @weekly
- @daily
- @hourly

To learn more about cron, visit [crontab.guru](https://crontab.guru/).

## Examples

The following example demonstrates how to use cron to build a simple scheduler.

```zig
const std = @import("std");
const Cron = @import("cron").Cron;
const datetime = @import("datetime").datetime;

fn job1(i: usize) !void {
    const now = datetime.Datetime.now();

    var buf: [64]u8 = undefined;
    const dt_str = try now.formatISO8601Buf(&buf, false);
    std.log.info("{s} {d}th execution", .{ dt_str, i });
}

pub fn main() !void {
    var c = Cron.init();
    // At every minute.
    try c.parse("*/1 * * * *");

    for (0..5) |i| {
        const now = datetime.Datetime.now();

        // Get the next run time
        const next_dt = try c.next(now);
        const duration = next_dt.sub(now);
        // convert to nanoseconds
        const nanos = duration.totalSeconds() * std.time.ns_per_s + duration.nanoseconds;

        // wait next
        std.time.sleep(@intCast(nanos));

        try job1(i + 1);
    }
}
```

## Installation

Because `cron` needs to be used together with `datetime`, you need to add both of the following dependencies in `build.zig.zon`:

```
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
       .cron = .{
           .url = "https://github.com/dying-will-bullet/cron/archive/refs/tags/v0.2.0.tar.gz",
           .hash = "1220f3f1e6659f434657452f4727889a2424c1b78ac88775bd1f036858a1e974ad41",
       },
       .datetime = .{
            .url = "git+https://github.com/frmdstryr/zig-datetime?ref=master#4d0e84cd8844c0672e0cbe247a3130750c9e0f27",
            .hash = "datetime-0.8.0-cJNXzJSJAQB5RKwPglxoEq875GmehZoLjuAlKzvWp4_O",
        },
    },
}
```

Add them in `build.zig`:

```diff
diff --git a/build.zig b/build.zig
index 60fb4c2..0255ef3 100644
--- a/build.zig
+++ b/build.zig
@@ -15,6 +15,9 @@ pub fn build(b: *std.Build) void {
     // set a preferred release mode, allowing the user to decide how to optimize.
     const optimize = b.standardOptimizeOption(.{});

+    const opts = .{ .target = target, .optimize = optimize };
+    const cron_module = b.dependency("cron", opts).module("cron");
+    const datetime_module = b.dependency("datetime", opts).module("zig-datetime");
+
     const exe = b.addExecutable(.{
         .name = "m",
         // In this case the main source file is merely a path, however, in more
@@ -23,6 +26,7 @@ pub fn build(b: *std.Build) void {
         .target = target,
         .optimize = optimize,
     });
+    exe.addModule("cron", cron_module);
+    exe.addModule("datetime", datetime_module);


     // This declares intent for the executable to be installed into the
     // standard location when the user invokes the "install" step (the default
```

## API

### `parse(input: []const u8) !void`

- Params:
  - `input`: The cron string to parse.
- Returns: void.

### `next(now: datetime.Datetime) !datetime.Datetime`

- Params:
  - `now`: It will use this datetime as the starting for calculations.
- Returns: next execution datetime.

### `previous(now: datetime.Datetime) !datetime.Datetime`

- Params:
  - `now`: It will use this datetime as the starting for calculations.
- Returns: previous execution datetime.

## LICENSE

MIT License Copyright (c) 2023, Hanaasagi
