const std = @import("std");

const Allocator = std.mem.Allocator;
const ErrorBundle = std.zig.ErrorBundle;
const LineCol = Tree.LineCol;
const List = Tree.List;
const Map = Tree.Map;
const Node = Tree.Node;
const Tokenizer = @import("tokenizer.zig");
const Token = Tokenizer.Token;
const TokenIterator = Tokenizer.TokenIterator;
const TokenWithLineCol = Tree.TokenWithLineCol;
const Tree = @import("tree.zig");
const String = Tree.String;
const Parser = @This();
const Yaml = @import("yaml.zig");

source: []const u8,
tokens: std.MultiArrayList(TokenWithLineCol) = .empty,
token_it: TokenIterator = undefined,
docs: std.ArrayListUnmanaged(Node.Index) = .empty,
nodes: std.MultiArrayList(Node) = .empty,
extra: std.ArrayListUnmanaged(u32) = .empty,
string_bytes: std.ArrayListUnmanaged(u8) = .empty,
errors: ErrorBundle.Wip,

pub fn init(gpa: Allocator, source: []const u8) Allocator.Error!Parser {
    var self: Parser = .{ .source = source, .errors = undefined };
    try self.errors.init(gpa);
    return self;
}

pub fn deinit(self: *Parser, gpa: Allocator) void {
    self.tokens.deinit(gpa);
    self.docs.deinit(gpa);
    self.nodes.deinit(gpa);
    self.extra.deinit(gpa);
    self.string_bytes.deinit(gpa);
    self.errors.deinit();
    self.* = undefined;
}

pub fn parse(self: *Parser, gpa: Allocator) ParseError!void {
    var tokenizer = Tokenizer{ .buffer = self.source };
    var line: u32 = 0;
    var prev_line_last_col: u32 = 0;

    while (true) {
        const tok = tokenizer.next();
        const tok_index = try self.tokens.addOne(gpa);

        self.tokens.set(tok_index, .{
            .token = tok,
            .line_col = .{
                .line = line,
                .col = @intCast(tok.loc.start - prev_line_last_col),
            },
        });

        switch (tok.id) {
            .eof => break,
            .new_line => {
                line += 1;
                prev_line_last_col = @intCast(tok.loc.end);
            },
            else => {},
        }
    }

    self.token_it = .{ .buffer = self.tokens.items(.token) };

    self.eatCommentsAndSpace(&.{});

    while (true) {
        self.eatCommentsAndSpace(&.{});
        const tok = self.token_it.next() orelse break;

        switch (tok.id) {
            .eof => break,
            else => {
                self.token_it.seekBy(-1);
                const node_index = try self.doc(gpa);
                try self.docs.append(gpa, node_index);
            },
        }
    }
}

pub fn toOwnedTree(self: *Parser, gpa: Allocator) Allocator.Error!Tree {
    return .{
        .source = self.source,
        .tokens = self.tokens.toOwnedSlice(),
        .docs = try self.docs.toOwnedSlice(gpa),
        .nodes = self.nodes.toOwnedSlice(),
        .extra = try self.extra.toOwnedSlice(gpa),
        .string_bytes = try self.string_bytes.toOwnedSlice(gpa),
    };
}

fn addString(self: *Parser, gpa: Allocator, string: []const u8) Allocator.Error!String {
    const index: u32 = @intCast(self.string_bytes.items.len);
    try self.string_bytes.ensureUnusedCapacity(gpa, string.len);
    self.string_bytes.appendSliceAssumeCapacity(string);
    return .{ .index = @enumFromInt(index), .len = @intCast(string.len) };
}

fn addExtra(self: *Parser, gpa: Allocator, extra: anytype) Allocator.Error!u32 {
    const fields = std.meta.fields(@TypeOf(extra));
    try self.extra.ensureUnusedCapacity(gpa, fields.len);
    return self.addExtraAssumeCapacity(extra);
}

fn addExtraAssumeCapacity(self: *Parser, extra: anytype) u32 {
    const result: u32 = @intCast(self.extra.items.len);
    self.extra.appendSliceAssumeCapacity(&payloadToExtraItems(extra));
    return result;
}

fn payloadToExtraItems(data: anytype) [@typeInfo(@TypeOf(data)).@"struct".fields.len]u32 {
    const fields = @typeInfo(@TypeOf(data)).@"struct".fields;
    var result: [fields.len]u32 = undefined;
    inline for (&result, fields) |*val, field| {
        val.* = switch (field.type) {
            u32 => @field(data, field.name),
            i32 => @bitCast(@field(data, field.name)),
            Node.Index, Node.OptionalIndex, Token.Index => @intFromEnum(@field(data, field.name)),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
    }
    return result;
}

fn value(self: *Parser, gpa: Allocator) ParseError!Node.OptionalIndex {
    self.eatCommentsAndSpace(&.{});

    const pos = self.token_it.pos;
    const tok = self.token_it.next() orelse return error.UnexpectedEof;

    switch (tok.id) {
        .literal => if (self.eatToken(.map_value_ind, &.{ .new_line, .comment })) |_| {
            self.token_it.seekTo(pos);
            return self.map(gpa);
        } else {
            self.token_it.seekTo(pos);
            return self.leafValue(gpa);
        },
        .single_quoted, .double_quoted => {
            self.token_it.seekBy(-1);
            return self.leafValue(gpa);
        },
        .literal_block, .folded_block => {
            self.token_it.seekBy(-1);
            return self.blockScalar(gpa);
        },
        .seq_item_ind => {
            self.token_it.seekBy(-1);
            return self.list(gpa);
        },
        .flow_seq_start => {
            self.token_it.seekBy(-1);
            return self.listBracketed(gpa);
        },
        .flow_map_start => {
            self.token_it.seekBy(-1);
            return self.mapBracketed(gpa);
        },
        else => return .none,
    }
}

fn doc(self: *Parser, gpa: Allocator) ParseError!Node.Index {
    const node_index = try self.nodes.addOne(gpa);
    const node_start = self.token_it.pos;

    const header: union(enum) {
        directive: Token.Index,
        explicit,
        implicit,
    } = if (self.eatToken(.doc_start, &.{})) |doc_pos| explicit: {
        if (self.getCol(doc_pos) > 0) return error.MalformedYaml;
        if (self.eatToken(.tag, &.{ .new_line, .comment })) |_| {
            break :explicit .{ .directive = try self.expectToken(.literal, &.{ .new_line, .comment }) };
        }
        break :explicit .explicit;
    } else .implicit;
    const directive = switch (header) {
        .directive => |index| index,
        else => null,
    };
    const is_explicit = switch (header) {
        .directive, .explicit => true,
        .implicit => false,
    };

    const value_index = try self.value(gpa);
    if (value_index == .none) {
        self.token_it.seekBy(-1);
    }

    const node_end: Token.Index = footer: {
        if (self.eatToken(.doc_end, &.{})) |pos| {
            if (!is_explicit) {
                self.token_it.seekBy(-1);
                return self.fail(gpa, self.token_it.pos, "missing explicit document open marker '---'", .{});
            }
            if (self.getCol(pos) > 0) return error.MalformedYaml;
            break :footer pos;
        }
        if (self.eatToken(.doc_start, &.{})) |pos| {
            if (!is_explicit) return error.UnexpectedToken;
            if (self.getCol(pos) > 0) return error.MalformedYaml;
            self.token_it.seekBy(-1);
            break :footer @enumFromInt(@intFromEnum(pos) - 1);
        }
        if (self.eatToken(.eof, &.{})) |pos| {
            break :footer @enumFromInt(@intFromEnum(pos) - 1);
        }

        return self.fail(gpa, self.token_it.pos, "expected end of document", .{});
    };

    self.nodes.set(node_index, .{
        .tag = if (directive == null) .doc else .doc_with_directive,
        .scope = .{
            .start = node_start,
            .end = node_end,
        },
        .data = if (directive == null) .{
            .maybe_node = value_index,
        } else .{
            .doc_with_directive = .{
                .maybe_node = value_index,
                .directive = directive.?,
            },
        },
    });

    return @enumFromInt(node_index);
}

fn map(self: *Parser, gpa: Allocator) ParseError!Node.OptionalIndex {
    const node_index = try self.nodes.addOne(gpa);
    const node_start = self.token_it.pos;

    var entries: std.ArrayListUnmanaged(Map.Entry) = .empty;
    defer entries.deinit(gpa);

    const col = self.getCol(node_start);

    while (true) {
        self.eatCommentsAndSpace(&.{});

        const key_pos = self.token_it.pos;

        const next_tok = self.token_it.peek() orelse break;

        if (next_tok.id == .doc_start or next_tok.id == .doc_end or next_tok.id == .eof) {
            break;
        }

        if (self.getCol(key_pos) < col) break;

        const key = self.token_it.next() orelse break;
        switch (key.id) {
            .literal => {},
            .flow_map_end, .new_line => {
                self.token_it.seekBy(-1);
                break;
            },
            else => return self.fail(gpa, key_pos, "unexpected token for 'key': {}", .{key}),
        }

        _ = self.expectToken(.map_value_ind, &.{ .new_line, .comment }) catch
            return self.fail(gpa, self.token_it.pos, "expected map separator ':'", .{});

        const value_index = try self.value(gpa);

        if (value_index.unwrap()) |v| {
            const value_start = self.nodes.items(.scope)[@intFromEnum(v)].start;
            if (self.getCol(value_start) < self.getCol(key_pos)) {
                return error.MalformedYaml;
            }
            if (self.nodes.items(.tag)[@intFromEnum(v)] == .value) {
                if (self.getCol(value_start) == self.getCol(key_pos)) {
                    return self.fail(gpa, value_start, "'value' in map should have more indentation than the 'key'", .{});
                }
            }
        }

        try entries.append(gpa, .{
            .key = key_pos,
            .maybe_node = value_index,
        });
    }

    const node_end: Token.Index = @enumFromInt(@intFromEnum(self.token_it.pos) - 1);

    const scope: Node.Scope = .{
        .start = node_start,
        .end = node_end,
    };

    if (entries.items.len == 1) {
        const entry = entries.items[0];

        self.nodes.set(node_index, .{
            .tag = .map_single,
            .scope = scope,
            .data = .{ .map = .{
                .key = entry.key,
                .maybe_node = entry.maybe_node,
            } },
        });
    } else {
        try self.extra.ensureUnusedCapacity(gpa, entries.items.len * 2 + 1);
        const extra_index: u32 = @intCast(self.extra.items.len);

        _ = self.addExtraAssumeCapacity(Map{ .map_len = @intCast(entries.items.len) });

        for (entries.items) |entry| {
            _ = self.addExtraAssumeCapacity(entry);
        }

        self.nodes.set(node_index, .{
            .tag = .map_many,
            .scope = scope,
            .data = .{ .extra = @enumFromInt(extra_index) },
        });
    }

    return @as(Node.Index, @enumFromInt(node_index)).toOptional();
}

fn list(self: *Parser, gpa: Allocator) ParseError!Node.OptionalIndex {
    const node_index: Node.Index = @enumFromInt(try self.nodes.addOne(gpa));
    const node_start = self.token_it.pos;

    var values: std.ArrayListUnmanaged(List.Entry) = .empty;
    defer values.deinit(gpa);

    const first_col = self.getCol(node_start);

    while (true) {
        self.eatCommentsAndSpace(&.{});

        const pos = self.eatToken(.seq_item_ind, &.{}) orelse {
            break;
        };
        const cur_col = self.getCol(pos);
        if (cur_col < first_col) {
            self.token_it.seekBy(-1);
            break;
        }

        const value_index = try self.value(gpa);
        if (value_index == .none) return error.MalformedYaml;

        try values.append(gpa, .{ .node = value_index.unwrap().? });
    }

    const node_end: Token.Index = @enumFromInt(@intFromEnum(self.token_it.pos) - 1);

    try self.encodeList(gpa, node_index, values.items, .{
        .start = node_start,
        .end = node_end,
    });

    return node_index.toOptional();
}

fn listBracketed(self: *Parser, gpa: Allocator) ParseError!Node.OptionalIndex {
    const node_index: Node.Index = @enumFromInt(try self.nodes.addOne(gpa));
    const node_start = self.token_it.pos;

    var values: std.ArrayListUnmanaged(List.Entry) = .empty;
    defer values.deinit(gpa);

    _ = try self.expectToken(.flow_seq_start, &.{});

    const node_end: Token.Index = while (true) {
        self.eatCommentsAndSpace(&.{.comment});

        if (self.eatToken(.flow_seq_end, &.{.comment})) |pos|
            break pos;

        _ = self.eatToken(.comma, &.{.comment});

        const value_index = try self.value(gpa);
        if (value_index == .none) return error.MalformedYaml;

        try values.append(gpa, .{ .node = value_index.unwrap().? });
    };

    try self.encodeList(gpa, node_index, values.items, .{
        .start = node_start,
        .end = node_end,
    });

    return node_index.toOptional();
}

fn mapBracketed(self: *Parser, gpa: Allocator) ParseError!Node.OptionalIndex {
    const node_index: Node.Index = @enumFromInt(try self.nodes.addOne(gpa));
    const node_start = self.token_it.pos;

    var entries: std.ArrayListUnmanaged(Map.Entry) = .empty;
    defer entries.deinit(gpa);

    _ = try self.expectToken(.flow_map_start, &.{});

    const node_end: Token.Index = while (true) {
        self.eatCommentsAndSpace(&.{.comment});

        if (self.eatToken(.flow_map_end, &.{.comment})) |pos|
            break pos;

        _ = self.eatToken(.comma, &.{.comment});

        self.eatCommentsAndSpace(&.{.comment});
        if (self.token_it.peek()) |peek_tok| {
            if (peek_tok.id == .flow_map_end) {
                continue;
            }
        }

        const key_start = self.token_it.pos;
        const key_tok = self.token_it.next() orelse return error.UnexpectedEof;

        if (key_tok.id != .literal and key_tok.id != .single_quoted and key_tok.id != .double_quoted) {
            return self.fail(gpa, key_start, "expected key in flow mapping", .{});
        }

        _ = try self.expectToken(.map_value_ind, &.{ .space, .comment });

        const value_index = try self.value(gpa);

        try entries.append(gpa, .{
            .key = key_start,
            .maybe_node = value_index,
        });
    };

    const scope: Node.Scope = .{
        .start = node_start,
        .end = node_end,
    };

    if (entries.items.len == 1) {
        const entry = entries.items[0];

        self.nodes.set(@intFromEnum(node_index), .{
            .tag = .map_single,
            .scope = scope,
            .data = .{ .map = .{
                .key = entry.key,
                .maybe_node = entry.maybe_node,
            } },
        });
    } else {
        try self.extra.ensureUnusedCapacity(gpa, entries.items.len * 2 + 1);
        const extra_index: u32 = @intCast(self.extra.items.len);

        _ = self.addExtraAssumeCapacity(Map{ .map_len = @intCast(entries.items.len) });

        for (entries.items) |entry| {
            _ = self.addExtraAssumeCapacity(entry);
        }

        self.nodes.set(@intFromEnum(node_index), .{
            .tag = .map_many,
            .scope = scope,
            .data = .{ .extra = @enumFromInt(extra_index) },
        });
    }

    return node_index.toOptional();
}

fn encodeList(
    self: *Parser,
    gpa: Allocator,
    node_index: Node.Index,
    values: []const List.Entry,
    node_scope: Node.Scope,
) Allocator.Error!void {
    const index = @intFromEnum(node_index);
    switch (values.len) {
        0 => {
            self.nodes.set(index, .{
                .tag = .list_empty,
                .scope = node_scope,
                .data = undefined,
            });
        },
        1 => {
            self.nodes.set(index, .{
                .tag = .list_one,
                .scope = node_scope,
                .data = .{ .node = values[0].node },
            });
        },
        2 => {
            self.nodes.set(index, .{
                .tag = .list_two,
                .scope = node_scope,
                .data = .{ .list = .{
                    .el1 = values[0].node,
                    .el2 = values[1].node,
                } },
            });
        },
        else => {
            try self.extra.ensureUnusedCapacity(gpa, values.len + 1);
            const extra_index: u32 = @intCast(self.extra.items.len);

            _ = self.addExtraAssumeCapacity(List{ .list_len = @intCast(values.len) });

            for (values) |entry| {
                _ = self.addExtraAssumeCapacity(entry);
            }

            self.nodes.set(index, .{
                .tag = .list_many,
                .scope = node_scope,
                .data = .{ .extra = @enumFromInt(extra_index) },
            });
        },
    }
}

fn leafValue(self: *Parser, gpa: Allocator) ParseError!Node.OptionalIndex {
    const node_index: Node.Index = @enumFromInt(try self.nodes.addOne(gpa));
    const node_start = self.token_it.pos;

    while (self.token_it.next()) |tok| {
        switch (tok.id) {
            .single_quoted => {
                const node_end: Token.Index = @enumFromInt(@intFromEnum(self.token_it.pos) - 1);
                const raw = self.rawString(node_start, node_end);

                const string = try self.parseSingleQuoted(gpa, raw);

                self.nodes.set(@intFromEnum(node_index), .{
                    .tag = .string_value,
                    .scope = .{
                        .start = node_start,
                        .end = node_end,
                    },
                    .data = .{ .string = string },
                });

                return node_index.toOptional();
            },
            .double_quoted => {
                const node_end: Token.Index = @enumFromInt(@intFromEnum(self.token_it.pos) - 1);
                const raw = self.rawString(node_start, node_end);

                const string = try self.parseDoubleQuoted(gpa, raw);

                self.nodes.set(@intFromEnum(node_index), .{
                    .tag = .string_value,
                    .scope = .{
                        .start = node_start,
                        .end = node_end,
                    },
                    .data = .{ .string = string },
                });

                return node_index.toOptional();
            },
            .literal => {},
            .space => {
                const trailing = @intFromEnum(self.token_it.pos) - 2;

                const saved_pos = self.token_it.pos;
                var has_newline = false;
                while (self.token_it.peek()) |peek_tok| {
                    if (peek_tok.id == .new_line) {
                        has_newline = true;
                        break;
                    } else if (peek_tok.id == .space or peek_tok.id == .comment) {
                        _ = self.token_it.next();
                    } else {
                        break;
                    }
                }
                self.token_it.seekTo(saved_pos);

                if (has_newline) {
                    const node_end: Token.Index = @enumFromInt(trailing);
                    self.nodes.set(@intFromEnum(node_index), .{
                        .tag = .value,
                        .scope = .{
                            .start = node_start,
                            .end = node_end,
                        },
                        .data = undefined,
                    });
                    return node_index.toOptional();
                }

                self.eatCommentsAndSpace(&.{});
                if (self.token_it.peek()) |peek| {
                    if (peek.id != .literal) {
                        const node_end: Token.Index = @enumFromInt(trailing);

                        self.nodes.set(@intFromEnum(node_index), .{
                            .tag = .value,
                            .scope = .{
                                .start = node_start,
                                .end = node_end,
                            },
                            .data = undefined,
                        });
                        return node_index.toOptional();
                    }
                }
            },
            else => {
                self.token_it.seekBy(-1);
                const node_end: Token.Index = @enumFromInt(@intFromEnum(self.token_it.pos) - 1);

                self.nodes.set(@intFromEnum(node_index), .{
                    .tag = .value,
                    .scope = .{
                        .start = node_start,
                        .end = node_end,
                    },
                    .data = undefined,
                });
                return node_index.toOptional();
            },
        }
    }

    return error.MalformedYaml;
}

const ChompingIndicator = enum { clip, strip, keep };

fn blockScalar(self: *Parser, gpa: Allocator) ParseError!Node.OptionalIndex {
    const node_index: Node.Index = @enumFromInt(try self.nodes.addOne(gpa));
    const node_start = self.token_it.pos;

    const indicator_tok = self.token_it.next() orelse return error.UnexpectedEof;
    const is_literal = indicator_tok.id == .literal_block;

    var chomping: ChompingIndicator = .clip;
    var explicit_indent: ?usize = null;

    const token_loc = self.tokens.items(.token)[@intFromEnum(self.token_it.pos) - 1].loc;
    var check_pos = token_loc.start + 1;

    var has_indicators = false;
    while (check_pos < self.source.len) {
        const ch = self.source[check_pos];
        switch (ch) {
            '-' => {
                chomping = .strip;
                check_pos += 1;
                has_indicators = true;
            },
            '+' => {
                chomping = .keep;
                check_pos += 1;
                has_indicators = true;
            },
            '1'...'9' => {
                explicit_indent = ch - '0';
                check_pos += 1;
                has_indicators = true;
            },
            ' ', '\t', '#', '\r', '\n' => break,
            else => break,
        }
    }

    while (self.token_it.peek()) |tok| {
        if (tok.id == .space or tok.id == .comment) {
            _ = self.token_it.next();
        } else {
            break;
        }
    }

    const newline_tok = self.token_it.next() orelse return error.UnexpectedEof;
    if (newline_tok.id != .new_line) return error.UnexpectedToken;

    var content_lines: std.ArrayListUnmanaged([]const u8) = .empty;
    defer content_lines.deinit(gpa);

    var block_indent: ?usize = null;
    var line_start_pos: ?Token.Index = null;

    while (true) {
        line_start_pos = self.token_it.pos;

        while (self.token_it.peek()) |tok| {
            if (tok.id == .space) {
                _ = self.token_it.next();
            } else {
                break;
            }
        }

        const line_indent = self.getCol(self.token_it.pos);

        const next_tok = self.token_it.peek();
        if (next_tok == null) break;

        if (next_tok.?.id == .new_line) {
            try content_lines.append(gpa, "");
            _ = self.token_it.next();
            continue;
        }

        if (next_tok.?.id == .doc_start or next_tok.?.id == .doc_end or next_tok.?.id == .eof) {
            break;
        }

        if (block_indent == null) {
            if (explicit_indent) |indent| {
                block_indent = indent;
                if (line_indent != indent) {
                    return error.MalformedYaml;
                }
            } else {
                if (line_indent == 0) {
                    self.token_it.seekTo(line_start_pos.?);
                    break;
                }
                block_indent = line_indent;
            }
        }

        if (line_indent < block_indent.?) {
            self.token_it.seekTo(line_start_pos.?);
            break;
        }

        const line_tok_start = self.token_it.pos;
        var line_tok_end = line_tok_start;

        while (self.token_it.peek()) |tok| {
            if (tok.id == .new_line or tok.id == .eof) {
                break;
            }
            line_tok_end = self.token_it.pos;
            _ = self.token_it.next();
        }

        if (@intFromEnum(line_tok_end) >= @intFromEnum(line_tok_start)) {
            const start_loc = self.tokens.items(.token)[@intFromEnum(line_tok_start)].loc.start;
            const end_loc = self.tokens.items(.token)[@intFromEnum(line_tok_end)].loc.end;
            const line_content = self.source[start_loc..end_loc];
            try content_lines.append(gpa, line_content);
        } else {
            try content_lines.append(gpa, "");
        }

        if (self.token_it.peek()) |tok| {
            if (tok.id == .new_line) {
                _ = self.token_it.next();
            } else {
                break;
            }
        } else {
            break;
        }
    }

    const node_end: Token.Index = @enumFromInt(@intFromEnum(self.token_it.pos));

    var final_lines = content_lines.items;
    switch (chomping) {
        .clip => {
            while (final_lines.len > 0 and final_lines[final_lines.len - 1].len == 0) {
                final_lines = final_lines[0 .. final_lines.len - 1];
            }
        },
        .strip => {
            while (final_lines.len > 0 and final_lines[final_lines.len - 1].len == 0) {
                final_lines = final_lines[0 .. final_lines.len - 1];
            }
        },
        .keep => {},
    }

    const processed = if (is_literal)
        try self.processLiteralBlock(gpa, final_lines, chomping)
    else
        try self.processFoldedBlock(gpa, final_lines, chomping);

    self.nodes.set(@intFromEnum(node_index), .{
        .tag = .string_value,
        .scope = .{
            .start = node_start,
            .end = node_end,
        },
        .data = .{ .string = processed },
    });

    return node_index.toOptional();
}

fn processLiteralBlock(self: *Parser, gpa: Allocator, lines: []const []const u8, chomping: ChompingIndicator) Allocator.Error!String {
    if (lines.len == 0) {
        const index: u32 = @intCast(self.string_bytes.items.len);
        return .{ .index = @enumFromInt(index), .len = 0 };
    }

    var total_len: usize = 0;
    for (lines, 0..) |line, i| {
        total_len += line.len;
        if (i < lines.len - 1) {
            total_len += 1;
        } else {
            if (chomping != .strip) total_len += 1;
        }
    }

    const index: u32 = @intCast(self.string_bytes.items.len);
    try self.string_bytes.ensureUnusedCapacity(gpa, total_len);

    for (lines, 0..) |line, i| {
        self.string_bytes.appendSliceAssumeCapacity(line);
        if (i < lines.len - 1) {
            self.string_bytes.appendAssumeCapacity('\n');
        } else {
            if (chomping != .strip) {
                self.string_bytes.appendAssumeCapacity('\n');
            }
        }
    }

    return .{ .index = @enumFromInt(index), .len = @intCast(total_len) };
}

fn processFoldedBlock(self: *Parser, gpa: Allocator, lines: []const []const u8, chomping: ChompingIndicator) Allocator.Error!String {
    if (lines.len == 0) {
        const index: u32 = @intCast(self.string_bytes.items.len);
        return .{ .index = @enumFromInt(index), .len = 0 };
    }

    var total_len: usize = 0;
    for (lines, 0..) |line, i| {
        total_len += line.len;
        if (i < lines.len - 1) {
            if (line.len == 0 or (i + 1 < lines.len and lines[i + 1].len == 0)) {
                total_len += 1;
            } else {
                total_len += 1;
            }
        } else {
            if (chomping != .strip) total_len += 1;
        }
    }

    const index: u32 = @intCast(self.string_bytes.items.len);
    try self.string_bytes.ensureUnusedCapacity(gpa, total_len);

    for (lines, 0..) |line, i| {
        self.string_bytes.appendSliceAssumeCapacity(line);
        if (i < lines.len - 1) {
            if (line.len == 0 or (i + 1 < lines.len and lines[i + 1].len == 0)) {
                self.string_bytes.appendAssumeCapacity('\n');
            } else {
                self.string_bytes.appendAssumeCapacity(' ');
            }
        } else {
            if (chomping != .strip) {
                self.string_bytes.appendAssumeCapacity('\n');
            }
        }
    }

    return .{ .index = @enumFromInt(index), .len = @intCast(total_len) };
}

fn eatCommentsAndSpace(self: *Parser, comptime exclusions: []const Token.Id) void {
    outer: while (self.token_it.next()) |tok| {
        switch (tok.id) {
            .comment, .space, .new_line => |space| {
                inline for (exclusions) |excl| {
                    if (excl == space) {
                        self.token_it.seekBy(-1);
                        break :outer;
                    }
                } else continue;
            },
            else => {
                self.token_it.seekBy(-1);
                break;
            },
        }
    }
}

fn eatToken(self: *Parser, id: Token.Id, comptime exclusions: []const Token.Id) ?Token.Index {
    self.eatCommentsAndSpace(exclusions);
    const pos = self.token_it.pos;
    const tok = self.token_it.next() orelse return null;
    if (tok.id == id) {
        return pos;
    } else {
        self.token_it.seekBy(-1);
        return null;
    }
}

fn expectToken(self: *Parser, id: Token.Id, comptime exclusions: []const Token.Id) ParseError!Token.Index {
    return self.eatToken(id, exclusions) orelse error.UnexpectedToken;
}

fn getLine(self: *Parser, index: Token.Index) usize {
    const idx = @intFromEnum(index);
    if (idx >= self.tokens.len) return 0;
    return self.tokens.items(.line_col)[idx].line;
}

fn getCol(self: *Parser, index: Token.Index) usize {
    const idx = @intFromEnum(index);
    if (idx >= self.tokens.len) return 0;
    return self.tokens.items(.line_col)[idx].col;
}

fn parseSingleQuoted(self: *Parser, gpa: Allocator, raw: []const u8) ParseError!String {
    const raw_no_quotes = raw[1 .. raw.len - 1];

    try self.string_bytes.ensureUnusedCapacity(gpa, raw_no_quotes.len);
    var string: String = .{
        .index = @enumFromInt(@as(u32, @intCast(self.string_bytes.items.len))),
        .len = 0,
    };

    var state: enum {
        start,
        escape,
    } = .start;

    var index: usize = 0;

    while (index < raw_no_quotes.len) : (index += 1) {
        const c = raw_no_quotes[index];
        switch (state) {
            .start => switch (c) {
                '\'' => {
                    state = .escape;
                },
                else => {
                    self.string_bytes.appendAssumeCapacity(c);
                    string.len += 1;
                },
            },
            .escape => switch (c) {
                '\'' => {
                    state = .start;
                    self.string_bytes.appendAssumeCapacity(c);
                    string.len += 1;
                },
                else => return error.InvalidEscapeSequence,
            },
        }
    }

    return string;
}

fn parseDoubleQuoted(self: *Parser, gpa: Allocator, raw: []const u8) ParseError!String {
    const raw_no_quotes = raw[1 .. raw.len - 1];

    try self.string_bytes.ensureUnusedCapacity(gpa, raw_no_quotes.len);
    var string: String = .{
        .index = @enumFromInt(@as(u32, @intCast(self.string_bytes.items.len))),
        .len = 0,
    };

    var state: enum {
        start,
        escape,
    } = .start;

    var index: usize = 0;

    while (index < raw_no_quotes.len) : (index += 1) {
        const c = raw_no_quotes[index];
        switch (state) {
            .start => switch (c) {
                '\\' => {
                    state = .escape;
                },
                else => {
                    self.string_bytes.appendAssumeCapacity(c);
                    string.len += 1;
                },
            },
            .escape => switch (c) {
                'n' => {
                    state = .start;
                    self.string_bytes.appendAssumeCapacity('\n');
                    string.len += 1;
                },
                't' => {
                    state = .start;
                    self.string_bytes.appendAssumeCapacity('\t');
                    string.len += 1;
                },
                '"' => {
                    state = .start;
                    self.string_bytes.appendAssumeCapacity('"');
                    string.len += 1;
                },
                else => return error.InvalidEscapeSequence,
            },
        }
    }

    return string;
}

fn rawString(self: Parser, start: Token.Index, end: Token.Index) []const u8 {
    const start_token = self.token(start);
    const end_token = self.token(end);
    const start_pos = start_token.loc.start;
    const end_pos = end_token.loc.end;
    if (start_pos > self.source.len or end_pos > self.source.len or start_pos > end_pos) {
        return "";
    }
    return self.source[start_pos..end_pos];
}

fn token(self: Parser, index: Token.Index) Token {
    const idx = @intFromEnum(index);
    if (idx >= self.tokens.len) {
        return Token{
            .id = .eof,
            .loc = .{
                .start = if (self.source.len > 0) self.source.len else 0,
                .end = if (self.source.len > 0) self.source.len else 0,
            },
        };
    }
    return self.tokens.items(.token)[idx];
}

fn fail(self: *Parser, gpa: Allocator, token_index: Token.Index, comptime format: []const u8, args: anytype) ParseError {
    const idx = @intFromEnum(token_index);
    const line_col = if (idx < self.tokens.len)
        self.tokens.items(.line_col)[idx]
    else
        Tree.LineCol{ .line = 0, .col = 0 };

    const msg = try std.fmt.allocPrint(gpa, format, args);
    defer gpa.free(msg);
    const line_info = getLineInfo(self.source, line_col);
    try self.errors.addRootErrorMessage(.{
        .msg = try self.errors.addString(msg),
        .src_loc = try self.errors.addSourceLocation(.{
            .src_path = try self.errors.addString("(memory)"),
            .line = line_col.line,
            .column = line_col.col,
            .span_start = line_info.span_start,
            .span_main = line_info.span_main,
            .span_end = line_info.span_end,
            .source_line = try self.errors.addString(line_info.line),
        }),
        .notes_len = 0,
    });
    return error.ParseFailure;
}

fn getLineInfo(source: []const u8, line_col: LineCol) struct {
    line: []const u8,
    span_start: u32,
    span_main: u32,
    span_end: u32,
} {
    const line = line: {
        var it = std.mem.splitScalar(u8, source, '\n');
        var line_count: usize = 0;
        const line = while (it.next()) |line| {
            defer line_count += 1;
            if (line_count == line_col.line) break line;
        } else return .{
            .line = &.{},
            .span_start = 0,
            .span_main = 0,
            .span_end = 0,
        };
        break :line line;
    };

    const span_start: u32 = span_start: {
        const trimmed = std.mem.trimLeft(u8, line, " ");
        break :span_start @intCast(std.mem.indexOf(u8, line, trimmed).?);
    };

    const span_end: u32 = @intCast(std.mem.trimRight(u8, line, " \r\n").len);

    return .{
        .line = line,
        .span_start = span_start,
        .span_main = line_col.col,
        .span_end = span_end,
    };
}

pub const ParseError = error{
    InvalidEscapeSequence,
    MalformedYaml,
    NestedDocuments,
    UnexpectedEof,
    UnexpectedToken,
    ParseFailure,
} || Allocator.Error;

// ============================================================================
// Tests
// ============================================================================

