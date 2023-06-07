const std = @import("std");

/// Returns true if the given string is a digit
pub fn isDigit(s: []const u8) bool {
    for (s) |c| {
        if (!std.ascii.isDigit(c)) {
            return false;
        }
    }
    return true;
}
