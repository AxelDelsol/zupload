const std = @import("std");
const time = std.time;
const Allocator = std.mem.Allocator;
const ChunkIterator = @import("chunk_iterator.zig");

const ParallelUploader = struct {
    chunk_size: usize,
    pool: *std.Thread.Pool,

    pub fn uploadData(self: *ParallelUploader, data: []const u8) void {
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

const Options = struct { memory_limit: usize, chunk_size: usize, pool: *std.Thread.Pool };

fn uploadMemoryLimitPar(data: []const u8, options: Options) void {
    var uploader = ParallelUploader{ .chunk_size = options.chunk_size, .pool = options.pool };
    var chunk_iterator = ChunkIterator{ .data = data, .chunk_size = options.memory_limit };

    while (chunk_iterator.next()) |chunk| uploader.uploadData(chunk);
}

pub fn main() !void {
    const data = [_]u8{'a'} ** 10_000;

    const memory_limit = 1000;
    const nb_threads = 16;
    const chunk_size = try std.math.divCeil(usize, memory_limit, nb_threads);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator, .n_jobs = nb_threads });
    defer pool.deinit();

    var timer = try time.Timer.start();

    uploadMemoryLimitPar(&data, .{ .memory_limit = memory_limit, .chunk_size = chunk_size, .pool = &pool });

    const elapsed_ns = timer.read();

    std.debug.print("Elapsed time: {}", .{std.fmt.fmtDuration(elapsed_ns)});
}
