const std = @import("std");
const log = std.log;
const cron = @import("cron");
const datetime = @import("datetime").datetime;

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

fn strToDatetime(buf: []u8) !datetime.Datetime {
    const year = try std.fmt.parseInt(u32, buf[0..4], 10);
    const month = try std.fmt.parseInt(u32, buf[5..7], 10);
    const day = try std.fmt.parseInt(u32, buf[8..10], 10);
    const hour = try std.fmt.parseInt(u32, buf[11..13], 10);
    const minute = try std.fmt.parseInt(u32, buf[14..16], 10);
    const seconds = try std.fmt.parseInt(u32, buf[17..19], 10);
    const dt = try datetime.Datetime.create(year, month, day, hour, minute, seconds, 0, null);
    return dt;
}

fn getNow() !datetime.Datetime {
    var buf: [64]u8 = undefined;
    var file = try std.fs.cwd().openFile("./testdata/now", .{});
    defer file.close();

    var size = try file.readAll(&buf);
    if (size == 0) {
        return error.InvalidSize;
    }

    if (size > 0 and buf[size - 1] == '\n') {
        size -= 1;
    }
    log.info("NOW is {s}", .{buf[0..size]});
    const dt = strToDatetime(&buf);

    return dt;
}

fn fuzzTest(now: datetime.Datetime) !usize {
    var file = try std.fs.cwd().openFile("./testdata/cases", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    var count: usize = 0;
    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (std.mem.indexOf(u8, line, "|")) |i| {
            const cron_expr = line[0..i];
            const expect_dt = line[i + 1 ..];

            var c = cron.Cron.init();
            try c.parse(cron_expr);

            const dt = try c.next(now);
            var dt_buf: [64]u8 = undefined;
            const next_dt = try formatDatetime(&dt_buf, dt);

            if (!std.mem.eql(u8, next_dt, expect_dt)) {
                log.err("ERROR: Expr: '{s}'\t'Expect: '{s}', but got '{s}'", .{ cron_expr, expect_dt, next_dt });
                @panic("Mismatch!!!");
            } else {
                log.info("PASSED: Expr: '{s}'\tExpect: '{s}'", .{ cron_expr, expect_dt });
            }
        } else {
            @panic("Invalid Test data");
        }
        count += 1;
    }

    return count;
}

pub fn main() !void {
    log.info("Fuzzing...", .{});
    const now = try getNow();
    const total = try fuzzTest(now);
    log.info("Success... Total {d}", .{total});
}
