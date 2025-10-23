const std = @import("std");
const Tokenizer = @import("zyml").Tokenizer;
const Token = Tokenizer.Token;

fn ensureExpected(source: []const u8, expected: []const Token.Id) !void {
    var tokenizer = Tokenizer{
        .buffer = source,
    };

    var given: std.ArrayListUnmanaged(Token.Id) = .empty;
    defer given.deinit(std.testing.allocator);

    while (true) {
        const token = tokenizer.next();
        try given.append(std.testing.allocator, token.id);
        if (token.id == .eof) break;
    }

    try std.testing.expectEqualSlices(Token.Id, expected, given.items);
}

test "empty doc" {
    try ensureExpected("", &[_]Token.Id{.eof});
}

test "empty doc with explicit markers" {
    try ensureExpected(
        \\---
        \\...
    , &[_]Token.Id{
        .doc_start, .new_line, .doc_end, .eof,
    });
}

test "empty doc with explicit markers and a directive" {
    try ensureExpected(
        \\--- !tbd-v1
        \\...
    , &[_]Token.Id{
        .doc_start,
        .space,
        .tag,
        .literal,
        .new_line,
        .doc_end,
        .eof,
    });
}

test "sequence of values" {
    try ensureExpected(
        \\- 0
        \\- 1
        \\- 2
    , &[_]Token.Id{
        .seq_item_ind,
        .literal,
        .new_line,
        .seq_item_ind,
        .literal,
        .new_line,
        .seq_item_ind,
        .literal,
        .eof,
    });
}

test "sequence of sequences" {
    try ensureExpected(
        \\- [ val1, val2]
        \\- [val3, val4 ]
    , &[_]Token.Id{
        .seq_item_ind,
        .flow_seq_start,
        .space,
        .literal,
        .comma,
        .space,
        .literal,
        .flow_seq_end,
        .new_line,
        .seq_item_ind,
        .flow_seq_start,
        .literal,
        .comma,
        .space,
        .literal,
        .space,
        .flow_seq_end,
        .eof,
    });
}

test "mappings" {
    try ensureExpected(
        \\key1: value1
        \\key2: value2
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .eof,
    });
}

test "inline mapped sequence of values" {
    try ensureExpected(
        \\key :  [ val1, 
        \\          val2 ]
    , &[_]Token.Id{
        .literal,
        .space,
        .map_value_ind,
        .space,
        .flow_seq_start,
        .space,
        .literal,
        .comma,
        .space,
        .new_line,
        .space,
        .literal,
        .space,
        .flow_seq_end,
        .eof,
    });
}

test "part of tbd" {
    try ensureExpected(
        \\--- !tapi-tbd
        \\tbd-version:     4
        \\targets:         [ x86_64-macos ]
        \\
        \\uuids:
        \\  - target:          x86_64-macos
        \\    value:           F86CC732-D5E4-30B5-AA7D-167DF5EC2708
        \\
        \\install-name:    '/usr/lib/libSystem.B.dylib'
        \\...
    , &[_]Token.Id{
        .doc_start,
        .space,
        .tag,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .flow_seq_start,
        .space,
        .literal,
        .space,
        .flow_seq_end,
        .new_line,
        .new_line,
        .literal,
        .map_value_ind,
        .new_line,
        .space,
        .seq_item_ind,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .space,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .single_quoted,
        .new_line,
        .doc_end,
        .eof,
    });
}

test "Unindented list" {
    try ensureExpected(
        \\b:
        \\- foo: 1
        \\c: 1
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .new_line,
        .seq_item_ind,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .eof,
    });
}

test "escape sequences" {
    try ensureExpected(
        \\a: 'here''s an apostrophe'
        \\b: "a newline\nand a\ttab"
        \\c: "\"here\" and there"
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .single_quoted,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .double_quoted,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .double_quoted,
        .eof,
    });
}

test "comments" {
    try ensureExpected(
        \\key: # some comment about the key
        \\# first value
        \\- val1
        \\# second value
        \\- val2
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .comment,
        .new_line,
        .comment,
        .new_line,
        .seq_item_ind,
        .literal,
        .new_line,
        .comment,
        .new_line,
        .seq_item_ind,
        .literal,
        .eof,
    });
}

test "quoted literals" {
    try ensureExpected(
        \\'#000000'
        \\'[000000'
        \\"&someString"
    , &[_]Token.Id{
        .single_quoted,
        .new_line,
        .single_quoted,
        .new_line,
        .double_quoted,
        .eof,
    });
}

test "unquoted literals" {
    try ensureExpected(
        \\key1: helloWorld
        \\key2: hello,world
        \\key3: [hello,world]
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .flow_seq_start,
        .literal,
        .comma,
        .literal,
        .flow_seq_end,
        .eof,
    });
}

test "unquoted literal containing colon" {
    try ensureExpected(
        \\key1: val:ue
        \\key2: val::ue
    , &[_]Token.Id{
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .new_line,
        .literal,
        .map_value_ind,
        .space,
        .literal,
        .eof,
    });
}
