const std = @import("std");
const Allocator = std.mem.Allocator;
const Yaml = @import("yaml.zig");

pub const Decoder = struct {
    allocator: Allocator,
    arena: std.heap.ArenaAllocator,

    pub fn init(allocator: Allocator) Decoder {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),
        };
    }

    pub fn deinit(self: *Decoder) void {
        self.arena.deinit();
    }

    pub fn decode(self: *Decoder, comptime T: type, reader: anytype) !T {
        var content = std.ArrayList(u8).init(self.allocator);
        defer content.deinit();

        try reader.readAllArrayList(&content, std.math.maxInt(usize));

        return try self.decodeFromSlice(T, content.items);
    }

    pub fn decodeFromSlice(self: *Decoder, comptime T: type, source: []const u8) !T {
        var yaml = Yaml{ .source = source };
        defer yaml.deinit(self.allocator);

        try yaml.load(self.allocator);

        return try yaml.parse(self.arena.allocator(), T);
    }

    pub fn decodeFromFile(self: *Decoder, comptime T: type, path: []const u8) !T {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf: [4096]u8 = undefined;
        return try self.decode(T, file.reader(&buf));
    }

    pub fn decodeAll(self: *Decoder, comptime T: type, reader: anytype) ![]T {
        var content = std.ArrayList(u8).init(self.allocator);
        defer content.deinit();

        try reader.readAllArrayList(&content, std.math.maxInt(usize));

        return try self.decodeAllFromSlice(T, content.items);
    }

    pub fn decodeAllFromSlice(self: *Decoder, comptime T: type, source: []const u8) ![]T {
        var yaml = Yaml{ .source = source };
        defer yaml.deinit(self.allocator);

        try yaml.load(self.allocator);

        return try yaml.parse(self.arena.allocator(), []T);
    }
};

pub fn decode(allocator: Allocator, comptime T: type, source: []const u8) !struct { value: T, arena: std.heap.ArenaAllocator } {
    var decoder = Decoder.init(allocator);
    errdefer decoder.deinit();

    const value = try decoder.decodeFromSlice(T, source);

    return .{ .value = value, .arena = decoder.arena };
}

pub fn decodeFromFile(allocator: Allocator, comptime T: type, path: []const u8) !struct { value: T, arena: std.heap.ArenaAllocator } {
    var decoder = Decoder.init(allocator);
    errdefer decoder.deinit();

    const value = try decoder.decodeFromFile(T, path);

    return .{ .value = value, .arena = decoder.arena };
}

pub fn decodeFromReader(allocator: Allocator, comptime T: type, reader: anytype) !struct { value: T, arena: std.heap.ArenaAllocator } {
    var decoder = Decoder.init(allocator);
    errdefer decoder.deinit();

    const value = try decoder.decode(T, reader);

    return .{ .value = value, .arena = decoder.arena };
}
