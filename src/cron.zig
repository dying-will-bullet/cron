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

pub const Cron = struct {
    buf: [32]u8,
    expr: CronExpr,

    const Self = @This();

    pub fn init() Self {
        return Self{
            .buf = undefined,
            .expr = undefined,
        };
    }

    pub fn parse(self: *Self, input: []const u8) !void {
        var buf_: [32]u8 = undefined;
        const lower_input = std.ascii.lowerString(&buf_, input);
        const cron_expr = self.convertAlias(lower_input);

        var it = std.mem.split(u8, cron_expr, " ");
        var total_field: u3 = 0;
        while (it.next()) |_| {
            total_field += 1;
        }

        var length: usize = undefined;
        if (total_field == 5) {
            std.mem.copy(u8, self.buf[0..2], "0 ");
            std.mem.copy(u8, self.buf[2..], cron_expr);
            std.mem.copy(u8, self.buf[cron_expr.len + 2 ..], " *");
            total_field += 2;
            length = 2 + cron_expr.len + 2;
        } else if (total_field == 6) {
            std.mem.copy(u8, self.buf[0..2], "0 ");
            std.mem.copy(u8, self.buf[2..], cron_expr);
            total_field += 1;
            length = 2 + cron_expr.len;
        } else {
            std.mem.copy(u8, self.buf[0..], cron_expr);
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

    pub fn next(self: *Self, now: datetime.Datetime) !datetime.Datetime {
        // reset nanoseconds
        var future = now.shift(.{ .nanoseconds = -@intCast(i32, now.time.nanosecond) }).shiftSeconds(1);

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

    pub fn previous(self: *Self, now: datetime.Datetime) !datetime.Datetime {
        // reset nanoseconds
        var future = now.shift(.{ .nanoseconds = -@intCast(i32, now.time.nanosecond) }).shiftSeconds(-1);

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
