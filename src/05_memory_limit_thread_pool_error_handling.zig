const std = @import("std");
const time = std.time;
const Allocator = std.mem.Allocator;
const ChunkIterator = @import("chunk_iterator.zig");

const ParallelUploader = struct {
    chunk_size: usize,
    pool: *std.Thread.Pool,
    allocator: std.mem.Allocator,

    pub fn uploadData(self: *ParallelUploader, data: []const u8) RuntimeError!void {
        var chunk_thread_iterator = ChunkIterator{ .data = data, .chunk_size = self.chunk_size };

        var wg: std.Thread.WaitGroup = .{};

        var errors = std.ArrayList(?UploadError).init(self.allocator);
        defer errors.deinit();

        while (chunk_thread_iterator.next()) |chunk| {
            const error_ret = try errors.addOne();
            error_ret.* = null;
            self.pool.spawnWg(&wg, uploadFn, .{ chunk, error_ret });
        }

        wg.wait();

        for (errors.items) |error_ret| {
            if (error_ret) |err| {
                return err;
            }
        }
    }

    fn uploadFn(data: []const u8, error_ret: *?UploadError) void {
        _ = upload(data) catch |err| {
            std.debug.print("An error occured : {}\n", .{err});
            error_ret.* = err;
        };
    }
};

const UploadError = error{UnkownError};
const RuntimeError = UploadError || Allocator.Error;

fn upload(data: []const u8) UploadError!usize {
    std.debug.print("Uploading {} bytes...\n", .{data.len});

    if (data.len == 55) {
        return UploadError.UnkownError;
    }
    time.sleep(data.len * time.ns_per_ms);

    return data.len;
}

const Options = struct { memory_limit: usize, chunk_size: usize, pool: *std.Thread.Pool, allocator: std.mem.Allocator };

fn uploadMemoryLimitPar(data: []const u8, options: Options) RuntimeError!void {
    var uploader = ParallelUploader{ .chunk_size = options.chunk_size, .pool = options.pool, .allocator = options.allocator };
    var chunk_iterator = ChunkIterator{ .data = data, .chunk_size = options.memory_limit };

    while (chunk_iterator.next()) |chunk| {
        uploader.uploadData(chunk) catch |err| {
            std.debug.print("An error occured during upload: {}\n", .{err});
            return err;
        };
    }
}

pub fn main() !void {
    const data = [_]u8{'a'} ** 10_000;

    const memory_limit = 1000;
    const nb_threads = 16; // use 16 threads to trigger error handling
    const chunk_size = try std.math.divCeil(usize, memory_limit, nb_threads);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator, .n_jobs = nb_threads });
    defer pool.deinit();

    const options = Options{ .memory_limit = memory_limit, .chunk_size = chunk_size, .pool = &pool, .allocator = allocator };

    var timer = try time.Timer.start();

    try uploadMemoryLimitPar(&data, options);

    const elapsed_ns = timer.read();

    std.debug.print("Elapsed time: {}", .{std.fmt.fmtDuration(elapsed_ns)});
}
