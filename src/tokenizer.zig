const std = @import("std");
const Tokenizer = @This();

buffer: []const u8,
index: usize = 0,
in_flow: usize = 0,

pub const Token = struct {
    id: Id,
    loc: Loc,

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    pub const Id = enum {
        eof,
        new_line,
        doc_start,
        doc_end,
        seq_item_ind,
        map_value_ind,
        flow_map_start,
        flow_map_end,
        flow_seq_start,
        flow_seq_end,
        comma,
        space,
        tab,
        comment,
        alias,
        anchor,
        tag,
        single_quoted,
        double_quoted,
        literal,
        literal_block,
        folded_block,
    };

    pub const Index = enum(u32) {
        _,
    };
};

pub const TokenIterator = struct {
    buffer: []const Token,
    pos: Token.Index = @enumFromInt(0),

    pub fn next(self: *TokenIterator) ?Token {
        const token = self.peek() orelse return null;
        self.pos = @enumFromInt(@intFromEnum(self.pos) + 1);
        return token;
    }

    pub fn peek(self: TokenIterator) ?Token {
        const pos = @intFromEnum(self.pos);
        if (pos >= self.buffer.len) return null;
        return self.buffer[pos];
    }

    pub fn reset(self: *TokenIterator) void {
        self.pos = @enumFromInt(0);
    }

    pub fn seekTo(self: *TokenIterator, pos: Token.Index) void {
        self.pos = pos;
    }

    pub fn seekBy(self: *TokenIterator, offset: isize) void {
        var pos = @intFromEnum(self.pos);
        if (offset < 0) {
            pos -|= @intCast(@abs(offset));
        } else {
            pos +|= @intCast(@as(usize, @bitCast(offset)));
        }
        self.pos = @enumFromInt(pos);
    }
};

fn stringMatchesPattern(comptime pattern: []const u8, slice: []const u8) bool {
    comptime var count: usize = 0;
    inline while (count < pattern.len) : (count += 1) {
        if (count >= slice.len) return false;
        const c = slice[count];
        if (pattern[count] != c) return false;
    }
    return true;
}

fn matchesPattern(self: Tokenizer, comptime pattern: []const u8) bool {
    return stringMatchesPattern(pattern, self.buffer[self.index..]);
}

pub fn next(self: *Tokenizer) Token {
    var result = Token{
        .id = .eof,
        .loc = .{
            .start = self.index,
            .end = undefined,
        },
    };

    var state: enum {
        start,
        new_line,
        space,
        tab,
        comment,
        single_quoted,
        double_quoted,
        literal,
        literal_block,
        folded_block,
    } = .start;

    while (self.index < self.buffer.len) : (self.index += 1) {
        const c = self.buffer[self.index];
        switch (state) {
            .start => switch (c) {
                ' ' => {
                    state = .space;
                },
                '\t' => {
                    state = .tab;
                },
                '\n' => {
                    result.id = .new_line;
                    self.index += 1;
                    break;
                },
                '\r' => {
                    state = .new_line;
                },

                '-' => if (self.matchesPattern("---")) {
                    result.id = .doc_start;
                    self.index += "---".len;
                    break;
                } else if (self.matchesPattern("- ")) {
                    result.id = .seq_item_ind;
                    self.index += "- ".len;
                    break;
                } else if (self.matchesPattern("-\n")) {
                    result.id = .seq_item_ind;
                    self.index += "-".len;
                    break;
                } else {
                    state = .literal;
                },

                '.' => if (self.matchesPattern("...")) {
                    result.id = .doc_end;
                    self.index += "...".len;
                    break;
                } else {
                    state = .literal;
                },

                ',' => {
                    result.id = .comma;
                    self.index += 1;
                    break;
                },
                '#' => {
                    state = .comment;
                },
                '*' => {
                    result.id = .alias;
                    self.index += 1;
                    break;
                },
                '&' => {
                    result.id = .anchor;
                    self.index += 1;
                    break;
                },
                '!' => {
                    result.id = .tag;
                    self.index += 1;
                    break;
                },
                '[' => {
                    result.id = .flow_seq_start;
                    self.index += 1;
                    self.in_flow += 1;
                    break;
                },
                ']' => {
                    result.id = .flow_seq_end;
                    self.index += 1;
                    self.in_flow -|= 1;
                    break;
                },
                ':' => {
                    result.id = .map_value_ind;
                    self.index += 1;
                    break;
                },
                '{' => {
                    result.id = .flow_map_start;
                    self.index += 1;
                    self.in_flow += 1;
                    break;
                },
                '}' => {
                    result.id = .flow_map_end;
                    self.index += 1;
                    self.in_flow -|= 1;
                    break;
                },
                '\'' => {
                    state = .single_quoted;
                },
                '"' => {
                    state = .double_quoted;
                },
                '|' => {
                    result.id = .literal_block;
                    self.index += 1;

                    while (self.index < self.buffer.len) {
                        const ch = self.buffer[self.index];
                        if (ch == '-' or ch == '+' or (ch >= '1' and ch <= '9')) {
                            self.index += 1;
                        } else {
                            break;
                        }
                    }
                    break;
                },
                '>' => {
                    result.id = .folded_block;
                    self.index += 1;

                    while (self.index < self.buffer.len) {
                        const ch = self.buffer[self.index];
                        if (ch == '-' or ch == '+' or (ch >= '1' and ch <= '9')) {
                            self.index += 1;
                        } else {
                            break;
                        }
                    }
                    break;
                },
                else => {
                    state = .literal;
                },
            },

            .comment => switch (c) {
                '\r', '\n' => {
                    result.id = .comment;
                    break;
                },
                else => {},
            },

            .space => switch (c) {
                ' ' => {},
                else => {
                    result.id = .space;
                    break;
                },
            },

            .tab => switch (c) {
                '\t' => {},
                else => {
                    result.id = .tab;
                    break;
                },
            },

            .new_line => switch (c) {
                '\n' => {
                    result.id = .new_line;
                    self.index += 1;
                    break;
                },
                else => {},
            },

            .single_quoted => switch (c) {
                '\'' => if (!self.matchesPattern("''")) {
                    result.id = .single_quoted;
                    self.index += 1;
                    break;
                } else {
                    self.index += "''".len - 1;
                },
                else => {},
            },

            .double_quoted => switch (c) {
                '"' => {
                    const is_escaped = blk: {
                        if (self.index < result.loc.start + 1) break :blk false;
                        var num_backslashes: usize = 0;
                        var check_idx = self.index;
                        while (check_idx > result.loc.start and self.buffer[check_idx - 1] == '\\') {
                            num_backslashes += 1;
                            check_idx -= 1;
                        }
                        break :blk (num_backslashes % 2) == 1;
                    };

                    if (is_escaped) {} else {
                        result.id = .double_quoted;
                        self.index += 1;
                        break;
                    }
                },
                else => {},
            },

            .literal => switch (c) {
                '\r', '\n', ' ', '\'', '"', ']', '}' => {
                    result.id = .literal;
                    break;
                },
                ',', '[', '{' => {
                    result.id = .literal;
                    if (self.in_flow > 0) {
                        break;
                    }
                },
                ':' => {
                    result.id = .literal;
                    if (self.matchesPattern(": ") or self.matchesPattern(":\n") or self.matchesPattern(":\r")) {
                        break;
                    }
                },
                else => {
                    result.id = .literal;
                },
            },

            .literal_block, .folded_block => {
                unreachable;
            },
        }
    }

    if (self.index >= self.buffer.len) {
        switch (state) {
            .literal => {
                result.id = .literal;
            },
            else => {},
        }
    }

    result.loc.end = self.index;

    return result;
}

