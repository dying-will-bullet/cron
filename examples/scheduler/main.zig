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
        const nanos = duration.totalSeconds() * std.time.ns_per_s + duration.nanoseconds;

        // wait next
        std.time.sleep(@intCast(u64, nanos));

        try job1(i + 1);
    }
}
