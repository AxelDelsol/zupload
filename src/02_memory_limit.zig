const std = @import("std");
const time = std.time;
const ChunkIterator = @import("chunk_iterator.zig");

fn upload(data: []const u8) void {
    std.debug.print("Uploading {} bytes... ", .{data.len});
    time.sleep(data.len * time.ns_per_ms);
    std.debug.print("Done\n", .{});
}

fn uploadmemory_limit(data: []const u8, memory_limit: usize) void {
    var chunk_iterator = ChunkIterator{ .data = data, .chunk_size = memory_limit };

    while (chunk_iterator.next()) |chunk| {
        upload(chunk);
    }
}

pub fn main() !void {
    const data = [_]u8{'a'} ** 1000;
    const memory_limit = 100;

    var timer = try time.Timer.start();

    uploadmemory_limit(&data, memory_limit);

    const elapsed_ns = timer.read();

    std.debug.print("Elapsed time: {}", .{std.fmt.fmtDuration(elapsed_ns)});
}
