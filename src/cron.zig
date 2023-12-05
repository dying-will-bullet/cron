const std = @import("std");
const log = std.log;
const datetime = @import("datetime").datetime;
const ext = @import("./datetime.zig");

const Error = @import("./error.zig").Error;
const isDigit = @import("./utils.zig").isDigit;
const CronExpr = @import("./expr.zig").CronExpr;
const CronField = @import("./expr.zig").CronField;
const FieldTag = @import("./expr.zig").FieldTag;
// TODO: optimize this data structure
const BitSet = std.bit_set.IntegerBitSet(130);

const LEN = 48;

/// A sturct for parsing cron strings and calculating next and previous execution datetimes.
/// Example:
/// ```zig
/// const std = @import("std");
/// const Cron = @import("cron").Cron;
/// const datetime = @import("datetime").datetime;
///
/// fn job1(i: usize) !void {
///     const now = datetime.Datetime.now();
///
///     var buf: [64]u8 = undefined;
///     const dt_str = try now.formatISO8601Buf(&buf, false);
///     std.log.info("{s} {d}th execution", .{ dt_str, i });
/// }
///
/// pub fn main() !void {
///     var c = Cron.init();
///     // At every minute.
///     try c.parse("*/1 * * * *");
///
///     for (0..5) |i| {
///         const now = datetime.Datetime.now();
///
///         // Get the next run time
///         const next_dt = try c.next(now);
///         const duration = next_dt.sub(now);
///         // convert to nanoseconds
///         const nanos = duration.totalSeconds() * std.time.ns_per_s + duration.nanoseconds;
///
///         // wait next
///         std.time.sleep(@intCast(nanos));
///
///         try job1(i + 1);
///     }
/// }
/// ```
pub const Cron = struct {
    buf: [LEN]u8,
    expr: CronExpr,

    const Self = @This();

    /// Initialize cron
    pub fn init() Self {
        return Self{
            .buf = undefined,
            .expr = undefined,
        };
    }

    /// Parse cron expression
    pub fn parse(self: *Self, input: []const u8) !void {
        var buf_: [LEN]u8 = undefined;
        const lower_input = std.ascii.lowerString(&buf_, input);
        const cron_expr = self.convertAlias(lower_input);

        var it = std.mem.split(u8, cron_expr, " ");
        var total_field: u3 = 0;
        while (it.next()) |_| {
            total_field += 1;
        }

        var length: usize = undefined;
        if (total_field == 5) {
            @memcpy(self.buf[0..2], "0 ");
            @memcpy(self.buf[2 .. 2 + cron_expr.len], cron_expr);
            @memcpy(self.buf[cron_expr.len + 2 .. cron_expr.len + 2 + " *".len], " *");
            total_field += 2;
            length = 2 + cron_expr.len + 2;
        } else if (total_field == 6) {
            @memcpy(self.buf[0..2], "0 ");
            @memcpy(self.buf[2 .. 2 + cron_expr.len], cron_expr);
            total_field += 1;
            length = 2 + cron_expr.len;
        } else {
            @memcpy(self.buf[0..cron_expr.len], cron_expr);
            length = cron_expr.len;
        }

        if (total_field != 7) {
            return Error.InvalidLength;
        }

        var i: u4 = 0;
        var fields: [7]CronField = undefined;

        it = std.mem.split(u8, self.buf[0..length], " ");
        while (it.next()) |entry| {
            const tag = try std.meta.intToEnum(FieldTag, i);
            const field = try CronField.init(tag, entry);
            fields[i] = field;
            i += 1;
        }

        self.expr = CronExpr.init(
            fields[0],
            fields[1],
            fields[2],
            fields[3],
            fields[4],
            fields[5],
            fields[6],
        );

        return;
    }

    /// handle crontab alias
    /// @yearly (or @annually) 	Run once a year at midnight of 1 January 	0 0 1 1 *
    /// @monthly 	Run once a month at midnight of the first day of the month 	0 0 1 * *
    /// @weekly 	Run once a week at midnight on Sunday morning 	0 0 * * 0
    /// @daily (or @midnight) 	Run once a day at midnight 	0 0 * * *
    /// @hourly 	Run once an hour at the beginning of the hour 	0 * * * *
    fn convertAlias(self: Self, expr: []const u8) []const u8 {
        _ = self;
        if (std.mem.eql(u8, expr, "@yearly")) {
            return "0 0 1 1 *";
        }

        if (std.mem.eql(u8, expr, "@annually")) {
            return "0 0 1 1 *";
        }

        if (std.mem.eql(u8, expr, "@monthly")) {
            return "0 0 1 * *";
        }

        if (std.mem.eql(u8, expr, "@weekly")) {
            return "0 0 * * 0";
        }

        if (std.mem.eql(u8, expr, "@daily")) {
            return "0 0 * * *";
        }

        if (std.mem.eql(u8, expr, "@midnight")) {
            return "0 0 * * *";
        }

        if (std.mem.eql(u8, expr, "@hourly")) {
            return "0 * * * *";
        }

        return expr;
    }

    fn testMatch(self: Self, idx: u3, dt: datetime.Datetime) !bool {
        if (idx == 0) {
            const attr = dt.time.second;
            return try self.expr.second.testMatch(attr, dt);
        }
        if (idx == 1) {
            const attr = dt.time.minute;
            return try self.expr.minute.testMatch(attr, dt);
        }
        if (idx == 2) {
            const attr = dt.time.hour;
            return try self.expr.hour.testMatch(attr, dt);
        }
        if (idx == 3) {
            const attr = dt.date.day;
            return try self.expr.day.testMatch(attr, dt);
        }
        if (idx == 4) {
            const attr = dt.date.month;
            return try self.expr.month.testMatch(attr, dt);
        }
        if (idx == 5) {
            // Monday ~
            // 0 ~ 6 to 1 ~ 7
            const attr = (dt.date.weekday() + 1) % 7;
            return try self.expr.weekday.testMatch(attr, dt);
        }
        if (idx == 6) {
            const attr = dt.date.year;
            return try self.expr.year.testMatch(attr, dt);
        }

        unreachable;
    }

    /// Calculates and returns the datetime of the next scheduled execution based on the parsed cron schedule and the provided starting datetime.
    pub fn next(self: *Self, now: datetime.Datetime) !datetime.Datetime {
        // reset nanoseconds
        var future = now.shift(.{ .nanoseconds = -@as(i32, @intCast(now.time.nanosecond)) }).shiftSeconds(1);

        var to_test: u3 = 7;
        while (to_test > 0) {
            const idx = to_test - 1;
            if (!try self.testMatch(idx, future)) {
                const old = try future.copy();
                if (idx == 0) {
                    future = future.shiftSeconds(1);
                }
                if (idx == 1) {
                    future = future.shiftMinutes(1);
                }
                if (idx == 2) {
                    future = future.shiftHours(1);
                }
                if (idx == 3) {
                    future = future.shiftDays(1);
                }
                if (idx == 4) {
                    future = try ext.NextMonth(future);
                }
                if (idx == 5) {
                    future = future.shiftDays(1);
                }
                if (idx == 6) {
                    future = try ext.NextYear(future);
                }
                for (0..idx) |i| {
                    if (i == 0) {
                        future.time.second = 0;
                    }
                    if (i == 1) {
                        future.time.minute = 0;
                    }
                    if (i == 2) {
                        future.time.hour = 0;
                    }
                    if (i == 3) {
                        const delta = future.sub(old);
                        if ((delta.totalSeconds() > 60 * 60 * 24)) {
                            future.date.day = 1;
                        }
                    }
                    if (i == 4) {
                        const delta = future.sub(old);
                        if ((delta.totalSeconds() > 60 * 60 * 24)) {
                            future.date.month = 1;
                        }
                    }
                    if (i == 5) {
                        // do nothing
                    }
                }
                to_test = 7;
                continue;
            }

            to_test -= 1;
        }
        return future;
    }

    /// Calculates and returns the datetime of the most recent past scheduled execution based on the parsed cron schedule and the provided starting datetime.
    pub fn previous(self: *Self, now: datetime.Datetime) !datetime.Datetime {
        // reset nanoseconds
        var future = now.shift(.{ .nanoseconds = -@as(i32, @intCast(now.time.nanosecond)) }).shiftSeconds(-1);

        var to_test: u3 = 7;
        while (to_test > 0) {
            const idx = to_test - 1;
            if (!try self.testMatch(idx, future)) {
                const old = try future.copy();
                if (idx == 0) {
                    future = future.shiftSeconds(-1);
                }
                if (idx == 1) {
                    future = future.shiftMinutes(-1);
                }
                if (idx == 2) {
                    future = future.shiftHours(-1);
                }
                if (idx == 3) {
                    if (!std.mem.eql(u8, self.expr.day.text, "l")) {
                        future = future.shiftDays(-1);
                    } else {
                        future = try ext.PrevDay(future);
                    }
                }
                if (idx == 4) {
                    future = try ext.PrevMonth(future);
                }
                if (idx == 5) {
                    future = future.shiftDays(-1);
                }
                if (idx == 6) {
                    future = try ext.PrevYear(future);
                }

                for (0..idx) |i| {
                    if (i == 0) {
                        future.time.second = 59;
                    }
                    if (i == 1) {
                        future.time.minute = 59;
                    }
                    if (i == 2) {
                        future.time.hour = 23;
                    }
                    if (i == 3) {
                        const delta = future.sub(old);
                        if ((delta.totalSeconds() < -60 * 60 * 24)) {
                            const cur = future.date.month;
                            while (future.date.month == cur) {
                                future = future.shiftDays(1);
                            }
                            future = future.shiftDays(-1);
                        }
                    }
                    if (i == 4) {
                        const delta = future.sub(old);
                        if ((delta.totalSeconds() < -60 * 60 * 24)) {
                            future.date.month = 12;
                        }
                    }
                    if (i == 5) {
                        // do nothing
                    }
                }
                to_test = 7;
                continue;
            }

            to_test -= 1;
        }
        return future;
    }
};

// --------------------------------------------------------------------------------
//                                   Testing
// --------------------------------------------------------------------------------

const testing = std.testing;

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
    const dt = try datetime.Datetime.create(2024, 2, 15, 10, 10, 30, 0, null);
    const ndt = ext.getLastDayOfMonth(dt);

    try testing.expect(ndt.date.month == 2);
    try testing.expect(ndt.date.day == 29);
}

test "test next next next" {
    var buf: [64]u8 = undefined;
    const dt = try datetime.Datetime.create(2023, 6, 13, 3, 46, 43, 218000000, null);

    var cron = Cron.init();
    try cron.parse("*/1 * * * *");
    const next_dt = try cron.next(dt);

    var res = try formatDatetime(&buf, next_dt);
    try testing.expectEqualStrings("2023-06-13 03:47:00", res);

    const next_next_dt = try cron.next(next_dt);
    res = try formatDatetime(&buf, next_next_dt);
    try testing.expectEqualStrings("2023-06-13 03:48:00", res);

    const next_next_next_dt = try cron.next(next_next_dt);
    res = try formatDatetime(&buf, next_next_next_dt);
    try testing.expectEqualStrings("2023-06-13 03:49:00", res);
}
