const std = @import("std");

pub fn main() !void {
    std.debug.print("Running zyml specification tests...\n", .{});
    std.debug.print("Use 'zig build test-zyml' to run the full test suite\n", .{});
}

test {
    _ = @import("tokenizer_test.zig");
    _ = @import("parser_test.zig");

    _ = @import("spec_scalars_test.zig");
    _ = @import("spec_collections_test.zig");
    _ = @import("spec_flow_test.zig");
    _ = @import("spec_blocks_test.zig");
    _ = @import("spec_documents_test.zig");
    _ = @import("spec_comments_test.zig");
    _ = @import("spec_edge_cases_test.zig");
    _ = @import("spec_null_test.zig");
    _ = @import("spec_numeric_test.zig");
    _ = @import("spec_strings_test.zig");
}
