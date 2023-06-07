const std = @import("std");
const log = std.log;
const datetime = @import("datetime").datetime;
const ext = @import("./datetime.zig");
const Error = @import("./error.zig").Error;
const isDigit = @import("./utils.zig").isDigit;

// TODO: optimise
// 16.25 bytes ?
const BitSet = std.bit_set.IntegerBitSet(130);

const EPOCH = 1970;

/// Cron Field Tag
pub const FieldTag = enum(u4) {
    SECOND_OFFSET = 0,
    MINUTE_OFFSET = 1,
    HOUR_OFFSET = 2,
    DAY_OFFSET = 3,
    MONTH_OFFSET = 4,
    WEEK_OFFSET = 5,
    YEAR_OFFSET = 6,

    const Self = @This();

    /// Convert field tag to human string.
    fn toName(self: Self) []const u8 {
        switch (self) {
            .SECOND_OFFSET => return "second",
            .MINUTE_OFFSET => return "minute",
            .HOUR_OFFSET => return "hour",
            .DAY_OFFSET => return "day",
            .MONTH_OFFSET => return "month",
            .WEEK_OFFSET => return "week",
            .YEAR_OFFSET => return "year",
        }
    }

    /// For boundary checking.
    fn getRange(self: Self) [2]u16 {
        switch (self) {
            .SECOND_OFFSET => return .{ 0, 59 },
            .MINUTE_OFFSET => return .{ 0, 59 },
            .HOUR_OFFSET => return .{ 0, 23 },
            .DAY_OFFSET => return .{ 1, 31 },
            .MONTH_OFFSET => return .{ 1, 12 },
            .WEEK_OFFSET => return .{ 0, 6 },
            .YEAR_OFFSET => return .{ EPOCH, 2099 },
        }
    }
};

// https://en.wikipedia.org/wiki/Cron
//
// # ┌───────────── minute (0 - 59)
// # │ ┌───────────── hour (0 - 23)
// # │ │ ┌───────────── day of the month (1 - 31)
// # │ │ │ ┌───────────── month (1 - 12)
// # │ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday;
// # │ │ │ │ │                                   7 is also Sunday on some systems)
// # │ │ │ │ │
// # │ │ │ │ │
// # * * * * * <command to execut
// I add additional fields "second" "year"
pub const CronExpr = struct {
    second: CronField,
    minute: CronField,
    hour: CronField,
    day: CronField,
    month: CronField,
    weekday: CronField,
    year: CronField,

    const Self = @This();

    pub fn init(
        second: CronField,
        minute: CronField,
        hour: CronField,
        day: CronField,
        month: CronField,
        weekday: CronField,
        year: CronField,
    ) Self {
        return Self{
            .second = second,
            .minute = minute,
            .hour = hour,
            .day = day,
            .month = month,
            .weekday = weekday,
            .year = year,
        };
    }
};

pub const CronField = struct {
    // tag
    tag: FieldTag,
    // original text
    text: []const u8,
    allowed: BitSet,
    end: u16,
    // contains '*' or '?'
    has_wildcard: bool,

    const Self = @This();

    pub fn init(tag: FieldTag, text: []const u8) !Self {
        var allowed = BitSet.initEmpty();
        var end: u16 = undefined;
        var has_wildcard = false;

        var it = std.mem.split(u8, text, ",");
        while (it.next()) |e| {
            if (std.mem.eql(u8, e, "*") or std.mem.eql(u8, e, "?")) {
                has_wildcard = true;
            }

            if (try Self.parse(tag, e, &end)) |al| {
                allowed.setUnion(al);
            }
        }

        return Self{
            .tag = tag,
            .text = text,
            .allowed = allowed,
            .has_wildcard = has_wildcard,
            .end = end,
        };
    }

    fn getValue(tag: FieldTag, text: []const u8, start: u16, end: u16) !u16 {
        if (tag == .MONTH_OFFSET) {
            return try ext.monthNameToNum(text);
        }
        if (tag == .WEEK_OFFSET) {
            return try ext.weekNameToNum(text);
        }
        // others
        if (!isDigit(text)) {
            log.err("InvalidValue: {s} field has invalid value {d} ", .{ tag.toName(), text });
            return Error.InvalidValue;
        }

        // validate
        const num = try std.fmt.parseInt(u16, text, 10);
        if (@intCast(u16, num) < start or @intCast(u16, num) > end) {
            log.err("ValueOutOfRange: value {d} is out of range [{d}, {d}]", .{ num, start, end });
            return Error.ValueOutOfRange;
        }
        return num;
    }

    fn parseValue(tag: FieldTag, text: []const u8, range_start: u16, range_end: u16, increment: ?u8, end_limit: u16) !BitSet {
        var entry = text;

        var set = BitSet.initEmpty();
        var start: u16 = 0;
        var end: u16 = 0;

        if (std.mem.indexOf(u8, entry, "-")) |i| {
            start = try Self.getValue(tag, entry[0..i], range_start, end_limit);
            end = try Self.getValue(tag, entry[i + 1 ..], range_start, end_limit);
            // Allow "sat-sun"
            if (tag == .DAY_OFFSET or tag == .WEEK_OFFSET and end == 0) {
                end = 7;
            }
        } else if (std.mem.eql(u8, entry, "*")) {
            start = range_start;
            end = range_end;
        } else {
            start = try Self.getValue(tag, entry, range_start, end_limit);
            end = range_end;

            if (increment == null) {
                if (tag == .YEAR_OFFSET) {
                    set.set(start - EPOCH);
                } else {
                    set.set(start);
                }
                return set;
            }
        }

        if (start < range_start or start > end_limit) {
            log.err(
                "ValueOutOfRange: {s} field start value {d} is out of range [{d}, {d}]",
                .{ tag.toName(), start, range_start, end_limit },
            );
            return Error.ValueOutOfRange;
        }

        if (end < range_start or end > end_limit) {
            log.err(
                "ValueOutOfRange: {s} field end value {d} is out of range [{d}, {d}]",
                .{ tag.toName(), end, range_start, end_limit },
            );
            return Error.ValueOutOfRange;
        }

        const step = increment orelse 1;
        if (start <= end) {
            var i = start;
            while (i < end + 1) {
                if (tag == .YEAR_OFFSET) {
                    set.set(i - EPOCH);
                } else {
                    set.set(i);
                }
                i += step;
            }

            return set;
        }

        var right = BitSet.initEmpty();

        var first = end + step;
        var i = end;
        while (i < end_limit + 1) {
            if (i > first) {
                first = i;
            }
            if (tag == .YEAR_OFFSET) {
                set.set(i - EPOCH);
            } else {
                set.set(i);
            }
            i += step;
        }

        first = first % end_limit;

        i = first;
        while (i < start + 1) {
            if (tag == .YEAR_OFFSET) {
                set.set(i - EPOCH);
            } else {
                set.set(i);
            }
            i += step;
        }

        return set.unionWith(right);
    }

    fn parse(tag: FieldTag, text: []const u8, actual_end: *u16) !?BitSet {
        // copy and mute this value.
        var entry = text;

        // e.g. minute => 0 ~ 60
        const range = tag.getRange();
        var range_start = range[0];
        var range_end = range[1];

        var end_limit = range_end;
        actual_end.* = range_end;

        if (std.mem.eql(u8, entry, "*")) {
            return null;
        }

        if (std.mem.eql(u8, entry, "?")) {
            if (!(tag == .DAY_OFFSET or tag == .WEEK_OFFSET)) {
                std.log.err("InvalidValue: cannot use ? in {s} field", .{tag.toName()});
                return Error.InvalidValue;
            }
            return null;
        }

        if (std.mem.eql(u8, entry, "l")) {
            if (tag != .DAY_OFFSET) {
                std.log.err("InvalidValue: cannot use L/l except day field", .{});
                return Error.InvalidValue;
            }
            return null;
        } else if (std.mem.startsWith(u8, entry, "l")) {
            if (tag != .WEEK_OFFSET) {
                std.log.err("InvalidValue: cannot use leading L/l except weekday field", .{});
                return Error.InvalidValue;
            }

            if (std.mem.indexOf(u8, entry[1..], "-")) |i| {
                _ = i;
                // TODO: validate
            }
            return null;
        }

        if (tag == .WEEK_OFFSET) {
            end_limit = 7;
        }

        // maybe 0 ~ 60
        var increment: ?u8 = null;
        if (std.mem.indexOf(u8, entry, "/")) |i| {
            increment = try std.fmt.parseInt(u8, entry[i + 1 ..], 10);
            entry = entry[0..i];

            if (increment.? <= 0) {
                std.log.err(
                    "InvalidIncrement: negative increment {d} in {s} field",
                    .{ increment.?, tag.toName() },
                );
                return Error.InvalidIncrement;
            }
            if (increment.? > end_limit) {
                std.log.err(
                    "InvalidIncrement: increment {d} mutst be less than {d} in {s} field",
                    .{ increment.?, end_limit, tag.toName() },
                );
                return Error.InvalidIncrement;
            }
        }

        var set = try Self.parseValue(tag, entry, range_start, range_end, increment, end_limit);
        if (tag == .WEEK_OFFSET and set.isSet(7)) {
            set.unset(7);
            set.set(0);
        }

        return set;
    }

    pub fn testMatch(self: Self, value: u64, dt: datetime.Datetime) !bool {
        if (self.has_wildcard) {
            return true;
        }

        var it = std.mem.split(u8, self.text, ",");

        while (it.next()) |x| {
            if (std.mem.eql(u8, x, "l")) {
                if (value == ext.getLastDayOfMonth(dt).date.day) {
                    return true;
                }
            } else if (std.mem.startsWith(u8, x, "l")) {
                if (dt.date.month == (dt.shift(ext.ONE_WEEK).date.month)) {
                    continue;
                }

                if (isDigit(x[1..])) {
                    var v: u64 = 0;
                    if (!std.mem.eql(u8, x[1..], "7")) {
                        v = try std.fmt.parseInt(u64, x[1..], 10);
                    }

                    if (value == v) {
                        return true;
                    }
                    continue;
                }

                // FIXME:
                const k = std.mem.indexOf(u8, x[1..], "-") orelse x[1..].len - 1;

                const start = try std.fmt.parseInt(u16, x[1 .. k + 1], 10);
                const end = try std.fmt.parseInt(u16, x[k + 1 + 1 ..], 10);
                var allowed = BitSet.initEmpty();
                var j = start;
                while (j < end + 1) {
                    allowed.set(j);
                    j += 1;
                }

                if (allowed.isSet(7)) {
                    allowed.set(0);
                }

                if (allowed.isSet(value)) {
                    return true;
                }
            }
        }

        if (self.tag == .YEAR_OFFSET) {
            return self.allowed.isSet(value - EPOCH);
        }
        return self.allowed.isSet(value);
    }
};
