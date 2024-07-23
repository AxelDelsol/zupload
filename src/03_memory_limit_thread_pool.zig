const std = @import("std");
const time = std.time;
const Allocator = std.mem.Allocator;
const ChunkIterator = @import("chunk_iterator.zig");

const ParallelUploader = struct {
    chunk_size: usize,
    pool: *std.Thread.Pool,
    allocator: Allocator,

    pub fn init(allocator: Allocator, chunk_size: usize, nb_threads: u32) !ParallelUploader {
        var pool = try allocator.create(std.Thread.Pool);
        try pool.init(.{ .allocator = allocator, .n_jobs = nb_threads });
        return .{ .chunk_size = chunk_size, .pool = pool, .allocator = allocator };
    }

    pub fn deinit(self: *ParallelUploader) void {
        self.pool.deinit();
        self.allocator.destroy(self.pool);
    }

    pub fn uploadData(self: *ParallelUploader, data: []const u8) !void {
        var chunk_thread_iterator = ChunkIterator{ .data = data, .chunk_size = self.chunk_size };

        var wg: std.Thread.WaitGroup = .{};
        defer wg.wait();

        while (chunk_thread_iterator.next()) |chunk| {
            self.pool.spawnWg(&wg, upload, .{chunk});
        }
    }
};

fn upload(data: []const u8) void {
    std.debug.print("Uploading {} bytes...\n", .{data.len});
    time.sleep(data.len * time.ns_per_ms);
}

fn uploadMemoryLimitPar(data: []const u8, allocator: Allocator, memory_limit: usize, nb_threads: u32) !void {
    const chunk_size = try std.math.divCeil(usize, memory_limit, nb_threads);

    var uploader = try ParallelUploader.init(allocator, chunk_size, nb_threads);
    defer uploader.deinit();

    var chunk_iterator = ChunkIterator{ .data = data, .chunk_size = memory_limit };
    while (chunk_iterator.next()) |chunk| {
        try uploader.uploadData(chunk);
    }
}

pub fn main() !void {
    const data = [_]u8{'a'} ** 10_000;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // var logging = std.heap.loggingAllocator(gpa.allocator());
    const allocator = gpa.allocator();
    const memory_limit = 1000;
    const nb_threads = 16;

    var timer = try time.Timer.start();

    try uploadMemoryLimitPar(&data, allocator, memory_limit, nb_threads);

    const elapsed_ns = timer.read();

    std.debug.print("Elapsed time: {}", .{std.fmt.fmtDuration(elapsed_ns)});
}
