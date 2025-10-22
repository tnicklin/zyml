const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("zyml", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const decoder_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/decoder_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zyml", .module = mod },
            },
        }),
    });

    const fuzz_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/fuzz_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zyml", .module = mod },
            },
        }),
    });

    const struct_marshal_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/struct_marshal_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zyml", .module = mod },
            },
        }),
    });

    const go_style_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/go_style_test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zyml", .module = mod },
            },
        }),
    });

    const main_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/test-zyml.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zyml", .module = mod },
            },
        }),
    });

    const spec_tests = [_][]const u8{
        "test/spec_blocks_test.zig",
        "test/spec_collections_test.zig",
        "test/spec_comments_test.zig",
        "test/spec_documents_test.zig",
        "test/spec_edge_cases_test.zig",
        "test/spec_flow_test.zig",
        "test/spec_null_test.zig",
        "test/spec_numeric_test.zig",
        "test/spec_scalars_test.zig",
        "test/spec_strings_test.zig",
    };

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&b.addRunArtifact(decoder_tests).step);
    test_step.dependOn(&b.addRunArtifact(fuzz_tests).step);
    test_step.dependOn(&b.addRunArtifact(struct_marshal_tests).step);
    test_step.dependOn(&b.addRunArtifact(go_style_tests).step);
    test_step.dependOn(&b.addRunArtifact(main_tests).step);

    for (spec_tests) |test_file| {
        const spec_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_file),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zyml", .module = mod },
                },
            }),
        });
        test_step.dependOn(&b.addRunArtifact(spec_test).step);
    }

    const decoder_test_step = b.step("test-decoder", "Run decoder tests");
    decoder_test_step.dependOn(&b.addRunArtifact(decoder_tests).step);

    const fuzz_test_step = b.step("test-fuzz", "Run fuzz tests");
    fuzz_test_step.dependOn(&b.addRunArtifact(fuzz_tests).step);

    const struct_marshal_test_step = b.step("test-struct-marshal", "Run struct marshal tests");
    struct_marshal_test_step.dependOn(&b.addRunArtifact(struct_marshal_tests).step);

    const go_style_test_step = b.step("test-go-style", "Run Go-style zero value tests");
    go_style_test_step.dependOn(&b.addRunArtifact(go_style_tests).step);

    const spec_test_step = b.step("test-spec", "Run spec tests");
    spec_test_step.dependOn(&b.addRunArtifact(main_tests).step);
    for (spec_tests) |test_file| {
        const spec_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_file),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zyml", .module = mod },
                },
            }),
        });
        spec_test_step.dependOn(&b.addRunArtifact(spec_test).step);
    }
}
