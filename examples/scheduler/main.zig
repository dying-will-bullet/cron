const std = @import("std");
const Cron = @import("cron").Cron;
const datetime = @import("datetime").datetime;

fn currentDatetime(io: std.Io) datetime.Datetime {
    const timestamp = std.Io.Timestamp.now(io, .real);
    const seconds: f64 = @floatFromInt(timestamp.toSeconds());
    return datetime.Datetime.fromSeconds(seconds);
}

fn job1(i: usize, dt: datetime.Datetime) !void {
    var buf: [64]u8 = undefined;
    const dt_str = try dt.formatISO8601Buf(&buf, false);
    std.log.info("{s} {d}th scheduled execution", .{ dt_str, i });
}

pub fn main(init: std.process.Init) !void {
    var c = Cron.init();
    // At every minute.
    try c.parse("*/1 * * * *");

    var now = currentDatetime(init.io);
    for (0..5) |i| {
        // Get the next run time
        const next_dt = try c.next(now);
        try job1(i + 1, next_dt);
        now = next_dt;
    }
}
