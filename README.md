<h1 align="center"> cron ⏳ </h1>

[![CI](https://github.com/dying-will-bullet/cron/actions/workflows/ci.yaml/badge.svg)](https://github.com/dying-will-bullet/cron/actions/workflows/ci.yaml)
![](https://img.shields.io/badge/language-zig-%23ec915c)

**NOTE: Minimum Supported Zig Version is 0.11.**

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
        std.time.sleep(@intCast(u64, nanos));

        try job1(i + 1);
    }
}
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
