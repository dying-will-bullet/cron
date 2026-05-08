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

fn strToDatetime(buf: []const u8) !datetime.Datetime {
    const year = try std.fmt.parseInt(u32, buf[0..4], 10);
    const month = try std.fmt.parseInt(u32, buf[5..7], 10);
    const day = try std.fmt.parseInt(u32, buf[8..10], 10);
    const hour = try std.fmt.parseInt(u32, buf[11..13], 10);
    const minute = try std.fmt.parseInt(u32, buf[14..16], 10);
    const seconds = try std.fmt.parseInt(u32, buf[17..19], 10);
    const dt = try datetime.Datetime.create(year, month, day, hour, minute, seconds, 0, null);
    return dt;
}

fn getNow(io: std.Io, allocator: std.mem.Allocator) !datetime.Datetime {
    const contents = try std.Io.Dir.cwd().readFileAlloc(io, "./fuzz/testdata/now", allocator, .limited(1024));
    defer allocator.free(contents);

    const line = std.mem.trimEnd(u8, contents, "\r\n");
    if (line.len == 0) {
        return error.InvalidSize;
    }
    log.info("NOW is {s}", .{line});
    const dt = try strToDatetime(line);

    return dt;
}

fn fuzzTest(io: std.Io, allocator: std.mem.Allocator, now: datetime.Datetime) !usize {
    const contents = try std.Io.Dir.cwd().readFileAlloc(io, "./fuzz/testdata/cases", allocator, .limited(1024 * 1024));
    defer allocator.free(contents);

    var count: usize = 0;
    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trimEnd(u8, raw_line, "\r");
        if (line.len == 0) continue;

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

pub fn main(init: std.process.Init) !void {
    log.info("Fuzzing...", .{});
    const now = try getNow(init.io, init.gpa);
    const total = try fuzzTest(init.io, init.gpa, now);
    log.info("Success... Total {d}", .{total});
}
