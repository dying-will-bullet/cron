// --------------------------------------------------------------------------------
//                                   Public API
// --------------------------------------------------------------------------------

pub const Cron = @import("./cron.zig").Cron;
pub const Error = @import("./error.zig").Error;

// --------------------------------------------------------------------------------
//                                   Testing
// --------------------------------------------------------------------------------

const std = @import("std");
const testing = std.testing;
const datetime = @import("datetime").datetime;

// Format a Datetime to "2023-06-09 00:00:00"
fn formatDatetime(buf: []u8, dt: datetime.Datetime) ![]const u8 {
    return try std.fmt.bufPrint(
        buf,
        "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}",
        .{
            dt.date.year,
            dt.date.month,
            dt.date.day,
            dt.time.hour,
            dt.time.minute,
            dt.time.second,
        },
    );
}

fn expectNextEqual(cron_expr: []const u8, expect_next: []const u8) !void {
    const now = datetime.Datetime.fromTimestamp(1686216330000);

    var cron = Cron.init();
    try cron.parse(cron_expr);

    const next_dt = try cron.next(now);

    var buf: [64]u8 = undefined;

    const res = try formatDatetime(&buf, next_dt);

    try testing.expectEqualStrings(expect_next, res);
}

fn expectPrevEqual(cron_expr: []const u8, expect_prev: []const u8) !void {
    const now = datetime.Datetime.fromTimestamp(1686216330000);

    var cron = Cron.init();
    try cron.parse(cron_expr);

    const prev_dt = try cron.previous(now);

    var buf: [64]u8 = undefined;

    const res = try formatDatetime(&buf, prev_dt);

    try testing.expectEqualStrings(expect_prev, res);
}

test "test normal" {
    try expectNextEqual("*/5 * * * * * *", "2023-06-08 09:25:35");
    try expectNextEqual("0 0 1 1 * 2099", "2099-01-01 00:00:00");

    try expectNextEqual("* * * * *", "2023-06-08 09:26:00");
    try expectNextEqual("0 * * * *", "2023-06-08 10:00:00");
    try expectNextEqual("0 0 * * *", "2023-06-09 00:00:00");
    try expectNextEqual("0 0 1 * *", "2023-07-01 00:00:00");
    try expectNextEqual("5/15 * * * *", "2023-06-08 09:35:00");
    try expectNextEqual("5-51/15 * * * *", "2023-06-08 09:35:00");
    try expectNextEqual("1,8,40 * * * *", "2023-06-08 09:40:00");
    try expectNextEqual("0 0 1 1 *", "2024-01-01 00:00:00");
    try expectNextEqual("0 0 ? * 0-6", "2023-06-09 00:00:00");
    try expectNextEqual("0 0 31 * *", "2023-07-31 00:00:00");
    try expectNextEqual("0,1/2 * * * *", "2023-06-08 09:27:00");
    try expectNextEqual("0,1/2 * * * *", "2023-06-08 09:27:00");
    try expectNextEqual("0,1/2 * * * *", "2023-06-08 09:27:00");
    try expectNextEqual("0-6,50-59/2 * * * *", "2023-06-08 09:50:00");
    try expectNextEqual("0-6,50-59/2 * * * *", "2023-06-08 09:50:00");
    try expectNextEqual("0-6,50-59/2 * * * *", "2023-06-08 09:50:00");
    try expectNextEqual("0-6,50-59/2 * * * *", "2023-06-08 09:50:00");
    try expectNextEqual("0-6,50/2 * * * *", "2023-06-08 09:50:00");
    try expectNextEqual("10,20 15 * * *", "2023-06-08 15:10:00");
    try expectNextEqual("10,20 15 * * *", "2023-06-08 15:10:00");
    try expectNextEqual("10,20 15 * * *", "2023-06-08 15:10:00");
    //
    try expectNextEqual("* 2-5 * * *", "2023-06-09 02:00:00");
    try expectNextEqual("0 0 1 jan-dec *", "2023-07-01 00:00:00");
    try expectNextEqual("0 0 ? * sun-sat", "2023-06-09 00:00:00");
}

test "test last day" {
    std.debug.print("\r\n", .{});
    try expectNextEqual("0 0 L 6 ?", "2023-06-30 00:00:00");
    try expectNextEqual("0 0 1,L 2 ?", "2024-02-01 00:00:00");
    try expectNextEqual("0 0 2,L 2 ?", "2024-02-02 00:00:00");
    try expectNextEqual("0 0 L 2 ?", "2024-02-29 00:00:00");
    try expectNextEqual("59 23 L 12 *", "2023-12-31 23:59:00");
    try expectNextEqual("0 0 ? 2 L1", "2024-02-26 00:00:00");
    try expectNextEqual("0 0 ? 7 L1", "2023-07-31 00:00:00");
    try expectNextEqual("0 0 ? 7 L2", "2023-07-25 00:00:00");
    try expectNextEqual("0 0 ? 7 L3", "2023-07-26 00:00:00");
    try expectNextEqual("0 0 ? 7 L4", "2023-07-27 00:00:00");
    try expectNextEqual("0 0 ? 7 L5", "2023-07-28 00:00:00");
    try expectNextEqual("0 0 ? 7 L6", "2023-07-29 00:00:00");
    try expectNextEqual("0 0 ? 7 L0", "2023-07-30 00:00:00");
    try expectNextEqual("0 0 ? 7 L3-5", "2023-07-26 00:00:00");
    try expectNextEqual("0 0 ? 7 L3-5", "2023-07-26 00:00:00");
    try expectNextEqual("0 0 ? 7 L3-5", "2023-07-26 00:00:00");
    try expectNextEqual("0 0 ? 7 L3-5", "2023-07-26 00:00:00");
    try expectNextEqual("0 0 ? 7 L3-5", "2023-07-26 00:00:00");
    try expectNextEqual("0 0 ? 7 L3-5", "2023-07-26 00:00:00");
    try expectNextEqual("0 0 ? 7 L0-1", "2023-07-30 00:00:00");
    try expectNextEqual("0 0 ? 7 L0-1", "2023-07-30 00:00:00");
    try expectNextEqual("0 0 ? 7 L0-1", "2023-07-30 00:00:00");
    try expectNextEqual("0 0 ? 7 L0-1", "2023-07-30 00:00:00");
    try expectNextEqual("0 0 ? 2 L1", "2024-02-26 00:00:00");
    try expectNextEqual("0 0 ? 2 L0", "2024-02-25 00:00:00");
    try expectNextEqual("0 0 ? 2 L7", "2024-02-25 00:00:00");
    try expectNextEqual("0 0 ? 2 L6", "2024-02-24 00:00:00");
    try expectNextEqual("0 0 ? 2 L5", "2024-02-23 00:00:00");
    try expectNextEqual("0 0 ? 2 L4", "2024-02-29 00:00:00");
    try expectNextEqual("0 0 ? 2 L3", "2024-02-28 00:00:00");
    try expectNextEqual("0 0 ? 6 L6", "2023-06-24 00:00:00");
}

test "test day of week" {
    try expectNextEqual("0 0 ? 7 mon", "2023-07-03 00:00:00");
    try expectNextEqual("0 0 ? 7 mon", "2023-07-03 00:00:00");
    try expectNextEqual("0 0 ? 8 mon-fri", "2023-08-01 00:00:00");
    try expectNextEqual("0 12 * * sat-sun", "2023-06-10 12:00:00");
    try expectNextEqual("0 12 * * sat-sun", "2023-06-10 12:00:00");
    try expectNextEqual("0 12 * * sat-sun", "2023-06-10 12:00:00");
    try expectNextEqual("0 5 * * fri *", "2023-06-09 05:00:00");
    try expectNextEqual("* * * * Fri *", "2023-06-09 00:00:00");
    try expectNextEqual("* * * * Fri *", "2023-06-09 00:00:00");
    try expectNextEqual("* * 13 * Fri *", "2023-10-13 00:00:00");
}

test "test alias" {
    try expectNextEqual("@weekly", "2023-06-11 00:00:00");
    try expectNextEqual("@monthly", "2023-07-01 00:00:00");
    try expectNextEqual("@daily", "2023-06-09 00:00:00");
    try expectNextEqual("@hourly", "2023-06-08 10:00:00");
    try expectNextEqual("@annually", "2024-01-01 00:00:00");
    try expectNextEqual("@yearly", "2024-01-01 00:00:00");
}

test "test real example" {
    // std.debug.print("\r\n", .{});

    // // Forllowing generated by Chat GPT
    try expectNextEqual("0 0 * * *", "2023-06-09 00:00:00");
    try expectNextEqual("0 0 * 8 *", "2023-08-01 00:00:00");
    try expectNextEqual("0 1 * * SUN", "2023-06-11 01:00:00");
    try expectNextEqual("0 1/3 * * SUN", "2023-06-11 01:00:00");
    try expectNextEqual("0 */6 * * SUN", "2023-06-11 00:00:00");
    try expectNextEqual("0 */6 */4 * SUN", "2023-06-25 00:00:00");
    try expectNextEqual("* */6 */4 */3 SUN", "2023-07-09 00:00:00");
    try expectNextEqual("* 3,2 * * MON", "2023-06-12 02:00:00");
    try expectNextEqual("* 3-10 * * THU", "2023-06-08 09:26:00");
    try expectNextEqual("* * 1 2 ?", "2024-02-01 00:00:00");
    try expectNextEqual("0 4 8-14 * *", "2023-06-09 04:00:00");
    try expectNextEqual("0 0 1,15 * 3", "2023-11-01 00:00:00");
    try expectNextEqual("5 0 * 8 *", "2023-08-01 00:05:00");
    try expectNextEqual("15 14 1 * *", "2023-07-01 14:15:00");
    try expectNextEqual("0 22 * * 1-5", "2023-06-08 22:00:00");
    try expectNextEqual("23 0-20/2 * * *", "2023-06-08 10:23:00");
    try expectNextEqual("0 0,12 1 */2 *", "2023-07-01 00:00:00");
    try expectNextEqual("0 0 1 * ?", "2023-07-01 00:00:00");
    try expectNextEqual("30 8 * * 1-5", "2023-06-09 08:30:00");
    try expectNextEqual("0 12 * 1 1,3,5", "2024-01-01 12:00:00");
    try expectNextEqual("0 0 1,15 * ?", "2023-06-15 00:00:00");
    try expectNextEqual("0 0 */2 * ?", "2023-06-09 00:00:00");
    try expectNextEqual("0 0 1 1 ?", "2024-01-01 00:00:00");
    try expectNextEqual("0 0 9-12/2 * ?", "2023-06-09 00:00:00");
}

test "test previous" {
    try expectPrevEqual("*/5 * * * * * *", "2023-06-08 09:25:25");
    try expectPrevEqual("0 0 1 1 * 2013", "2013-01-01 00:00:00");
    try expectPrevEqual("0 0 * * *", "2023-06-08 00:00:00");
    try expectPrevEqual("* * * * *", "2023-06-08 09:25:00");
    try expectPrevEqual("0 * * * *", "2023-06-08 09:00:00");
    try expectPrevEqual("0 0 * * *", "2023-06-08 00:00:00");
    try expectPrevEqual("0 0 1 * *", "2023-06-01 00:00:00");
    try expectPrevEqual("5/15 * * * *", "2023-06-08 09:20:00");
    try expectPrevEqual("5-51/15 * * * *", "2023-06-08 09:20:00");
    try expectPrevEqual("1,8,40 * * * *", "2023-06-08 09:08:00");
    try expectPrevEqual("0 0 1 1 *", "2023-01-01 00:00:00");
    try expectPrevEqual("0 0 ? * 0-6", "2023-06-08 00:00:00");
    try expectPrevEqual("0 0 31 * *", "2023-05-31 00:00:00");
    try expectPrevEqual("0,1/2 * * * *", "2023-06-08 09:25:00");
    try expectPrevEqual("0,1/2 * * * *", "2023-06-08 09:25:00");
    try expectPrevEqual("0,1/2 * * * *", "2023-06-08 09:25:00");
    try expectPrevEqual("0-6,50-59/2 * * * *", "2023-06-08 09:06:00");
    try expectPrevEqual("0-6,50-59/2 * * * *", "2023-06-08 09:06:00");
    try expectPrevEqual("0-6,50-59/2 * * * *", "2023-06-08 09:06:00");
    try expectPrevEqual("0-6,50-59/2 * * * *", "2023-06-08 09:06:00");
    try expectPrevEqual("0-6,50/2 * * * *", "2023-06-08 09:06:00");
    try expectPrevEqual("10,20 15 * * *", "2023-06-07 15:20:00");
    try expectPrevEqual("10,20 15 * * *", "2023-06-07 15:20:00");
    try expectPrevEqual("10,20 15 * * *", "2023-06-07 15:20:00");
    try expectPrevEqual("* 2-5 * * *", "2023-06-08 05:59:00");
    try expectPrevEqual("0 0 1 jan-dec *", "2023-06-01 00:00:00");
    try expectPrevEqual("0 0 ? * sun-sat", "2023-06-08 00:00:00");
}

test "test memory" {
    const now = datetime.Datetime.fromTimestamp(1686216330000);

    var cron = Cron.init();
    try cron.parse("* * * * *");

    var cron2 = Cron.init();
    try cron2.parse("0 0 1,15 * 3");

    const next_dt = try cron.next(now);
    const next_dt2 = try cron2.next(now);

    var buf: [64]u8 = undefined;

    const res = try formatDatetime(&buf, next_dt);
    try testing.expectEqualStrings("2023-06-08 09:26:00", res);

    const res2 = try formatDatetime(&buf, next_dt2);
    try testing.expectEqualStrings("2023-11-01 00:00:00", res2);
}

test "test getLastDayOfMonth" {
    const ext = @import("./datetime.zig");
    const dt = try datetime.Datetime.create(2024, 2, 15, 10, 10, 30, 0, null);
    const ndt = ext.getLastDayOfMonth(dt);

    try testing.expect(ndt.date.month == 2);
    try testing.expect(ndt.date.day == 29);
}
