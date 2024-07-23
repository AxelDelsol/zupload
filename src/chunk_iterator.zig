const ChunkIterator = @This();

data: []const u8,
chunk_size: usize,
current_chunk_start: usize = 0,

pub fn next(self: *ChunkIterator) ?[]const u8 {
    if (self.current_chunk_start >= self.data.len) {
        return null;
    }

    const endIndex = @min(self.current_chunk_start + self.chunk_size, self.data.len);
    const chunk = self.data[self.current_chunk_start..endIndex];

    self.current_chunk_start = endIndex;

    return chunk;
}
