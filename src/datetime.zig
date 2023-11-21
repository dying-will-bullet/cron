const std = @import("std");
const log = std.log;

const datetime = @import("datetime").datetime;
const isDigit = @import("./utils.zig").isDigit;
const Error = @import("./error.zig").Error;

pub const ONE_WEEK: datetime.Datetime.Delta = .{ .days = 7 };
// use the minimum number of days.
pub const ONE_MONTH: datetime.Datetime.Delta = .{ .days = 28 };

/// Convert Month name to num
/// Accept "jan"(smallcase) or "1"
pub fn monthNameToNum(name: []const u8) !u8 {
    // Fast path: Typically, we don't use month names
    // but instead represent themusing decimal numbers.
    if (name.len != 3) {
        if (!isDigit(name)) {
            log.err("InvalidMonth: {s}", .{name});
            return Error.InvalidMonth;
        }
        const num = try std.fmt.parseInt(u8, name, 10);
        if (num > 12 or num < 1) {
            log.err("ValueOutOfRange: value {d} is out of range [{d}, {d}]", .{ num, 1, 12 });
            return Error.ValueOutOfRange;
        }
        return num;
    }

    if (name[0] == 'j') {
        if (std.mem.eql(u8, name[1..], "an")) {
            return 1;
        }
        if (std.mem.eql(u8, name[1..], "un")) {
            return 6;
        }

        if (std.mem.eql(u8, name[1..], "ul")) {
            return 7;
        }
    }

    if (name[0] == 'm') {
        if (std.mem.eql(u8, name[1..], "ar")) {
            return 3;
        }
        if (std.mem.eql(u8, name[1..], "ay")) {
            return 5;
        }
    }

    if (name[0] == 'a') {
        if (std.mem.eql(u8, name[1..], "pr")) {
            return 4;
        }
        if (std.mem.eql(u8, name[1..], "ua")) {
            return 8;
        }
    }

    if (std.mem.eql(u8, name, "feb")) {
        return 2;
    }

    if (std.mem.eql(u8, name, "sep")) {
        return 9;
    }

    if (std.mem.eql(u8, name, "oct")) {
        return 10;
    }

    if (std.mem.eql(u8, name, "nov")) {
        return 11;
    }

    if (std.mem.eql(u8, name, "dec")) {
        return 12;
    }

    log.err("InvalidMonth: {s}", .{name});
    return Error.InvalidMonth;
}

pub fn weekNameToNum(name: []const u8) !u8 {
    if (name.len == 1) {
        if (!isDigit(name)) {
            log.err("InvalidWeek: {s}", .{name});
            return Error.InvalidWeek;
        }

        const num = try std.fmt.parseInt(u8, name, 10);
        if (num > 6) {
            log.err("ValueOutOfRange: value {d} is out of range [{d}, {d}]", .{ num, 0, 6 });
            return Error.ValueOutOfRange;
        }
        return num;
    }

    if (std.mem.eql(u8, name, "sun")) {
        return 0;
    }

    if (std.mem.eql(u8, name, "mon")) {
        return 1;
    }

    if (std.mem.eql(u8, name, "tue")) {
        return 2;
    }

    if (std.mem.eql(u8, name, "wed")) {
        return 3;
    }

    if (std.mem.eql(u8, name, "thu")) {
        return 4;
    }

    if (std.mem.eql(u8, name, "fri")) {
        return 5;
    }

    if (std.mem.eql(u8, name, "sat")) {
        return 6;
    }

    log.err("InvalidWeek: {s}", .{name});
    return Error.InvalidWeek;
}

pub fn getLastDayOfMonth(dt: datetime.Datetime) datetime.Datetime {
    // TODO: Check this logic
    var ndt = dt.shift(.{ .days = 0 });

    if (ndt.date.month == 12) {
        ndt.date.year += 1;
        ndt.date.month = 1;
    } else {
        ndt.date.month += 1;
    }

    ndt.date.day = 1;
    return ndt.shift(.{ .days = -1 });
}

pub fn NextMonth(dt: datetime.Datetime) !datetime.Datetime {
    const month = dt.date.month;

    var ndt = dt.shift(ONE_MONTH);
    while (ndt.date.month == month) {
        ndt = ndt.shiftDays(1);
    }

    ndt.date.day = 1;
    return ndt;
}

pub fn NextYear(dt: datetime.Datetime) !datetime.Datetime {
    const mod = dt.date.year % 4;
    if (mod == 0 and (dt.date.month < 2 or (dt.date.month == 2 and dt.date.day < 29))) {
        return dt.shiftYears(1).shiftDays(1);
    }
    if (mod == 3 and (dt.date.month > 2 or (dt.date.month == 2 and dt.date.day > 29))) {
        return dt.shiftYears(1).shiftDays(1);
    }
    return dt.shiftYears(1);
}

pub fn PrevDay(dt: datetime.Datetime) !datetime.Datetime {
    const tdt = dt.shiftDays(-1);
    var ndt = dt.shiftDays(-1);
    while (tdt.date.month == ndt.date.month) {
        ndt = ndt.shiftDays(-1);
    }
    return ndt;
}

pub fn PrevMonth(dt: datetime.Datetime) !datetime.Datetime {
    var ndt = try dt.copy();

    ndt.date.day = 1;
    ndt = ndt.shiftDays(-1);
    return ndt;
}

pub fn PrevYear(dt: datetime.Datetime) !datetime.Datetime {
    const mod = dt.date.year % 4;
    if (mod == 0 and (dt.date.month > 2 or (dt.date.month == 2 and dt.date.day > 29))) {
        return dt.shiftYears(-1).shiftDays(-1);
    }

    if (mod == 1 and (dt.date.month < 2 or (dt.date.month == 2 and dt.date.day < 29))) {
        return dt.shiftYears(1).shiftDays(1);
    }

    return dt.shiftYears(-1);
}
