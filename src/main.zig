const std = @import("std");

const codes = [_]Code{ .{
    .main = @import("01_all.zig").main,
    .desc = "Uploads all data in one go",
}, .{
    .main = @import("02_memory_limit.zig").main,
    .desc = "Uploads data in small chunks",
}, .{
    .main = @import("03_memory_limit_thread_pool.zig").main,
    .desc = "Uploads data in small chunks in parallel (using a thread pool)",
}, .{
    .main = @import("04_memory_limit_thread_pool2.zig").main,
    .desc = "Same as before but refactored code",
}, .{
    .main = @import("05_memory_limit_thread_pool_error_handling.zig").main,
    .desc = "Uploads data in small chunks in parallel and cancels the upload in case of error",
} };

pub fn main() !void {
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var args_alloc_iter = try std.process.argsWithAllocator(allocator);
    defer args_alloc_iter.deinit();

    _ = args_alloc_iter.skip();

    const argument = args_alloc_iter.next();

    if (argument) |arg| {
        const code_iteration = std.fmt.parseInt(u32, arg, 10) catch |err| {
            std.debug.print("An error occured: {}\n", .{err});
            usage();
            return;
        };

        if (code_iteration <= 0 or code_iteration > codes.len) {
            usage();
        } else {
            const index = code_iteration - 1;
            std.debug.print("Running code : {s}\n-----\n", .{codes[index].desc});
            try codes[index].main();
        }
    } else {
        usage();
    }
}

const Code = struct { desc: []const u8, main: *const fn () anyerror!void };

fn usage() void {
    std.debug.print("Usage: zig build run -- <code>\n", .{});

    inline for (codes, 1..) |code, index| {
        std.debug.print("code = {} -> {s}\n", .{ index, code.desc });
    }
}
