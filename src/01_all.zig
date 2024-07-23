const std = @import("std");
const time = std.time;

pub fn upload(data: []const u8) void {
    std.debug.print("Uploading {} bytes... ", .{data.len});
    time.sleep(data.len * time.ns_per_ms);
    std.debug.print("Done\n", .{});
}

pub fn main() !void {
    const data = [_]u8{'a'} ** 1000;

    var timer = try time.Timer.start();

    upload(&data);

    const elapsed_ns = timer.read();

    std.debug.print("Elapsed time: {}", .{std.fmt.fmtDuration(elapsed_ns)});
}
