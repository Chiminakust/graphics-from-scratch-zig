const std = @import("std");
const Allocator = std.mem.Allocator;

// print debug alias
const print = std.debug.print;

const utils = @import("utils.zig");
const nextCapacity = utils.nextCapacity;
const Pixel = utils.Pixel;
const Color = utils.Color;
const int = utils.int;
const float = utils.float;
const width = utils.width;
const height = utils.height;

const Black = Color {.r = 0, .g = 0, .b = 0};
const White = Color {.r = 0xff, .g = 0xff, .b = 0xff};

//var interp_buffer_mem: [@as(u64, @max(width, height)) * @sizeOf(usize)]u8 = undefined;
const interp_buf_size = nextCapacity(@as(usize, @max(width, height))) * @sizeOf(usize);
var interp_buffer_mem: [interp_buf_size]u8 = undefined;

// Geometry stuff
const Coord2D = struct {
    x: float,
    y: float,

    pub fn swap(first: *Coord2D, second: *Coord2D) void {
        const copy: Coord2D = .{.x = second.x, .y = second.y};
        second.x = first.x;
        second.y = first.y;
        first.x = copy.x;
        first.y = copy.y;
    }
};

// global variables
var gcanvas: [width * height]Pixel = undefined;

fn drawLine(p0: Coord2D, p1: Coord2D, color: Color, canvas: []Pixel, allocator: Allocator) !void {
    var ind0: float = 0;
    var ind1: float = 0;
    var dep0: float = 0;
    var dep1: float = 0;
    var list = std.ArrayList(usize).init(allocator);
    defer list.deinit();

    // line is more horizontal than vertical or vice-versa
    if (@abs(p1.x - p0.x) > @abs(p1.y - p0.y)) {
        // make sure x0 < x1 (draw horizontal)
        if (p0.x < p1.x) {
            ind0 = p0.x;
            ind1 = p1.x;
            dep0 = p0.y;
            dep1 = p1.y;
        } else {
            ind0 = p1.x;
            ind1 = p0.x;
            dep0 = p1.y;
            dep1 = p0.y;
        }

        try interpolate(ind0, dep0, ind1, dep1, &list);

        const start: usize = @intFromFloat(ind0);
        const end: usize = @intFromFloat(ind1);
        for (start..end) |x| {
            utils.put_canvas(canvas, x, list.items[x - start], color);
        }
    } else {
        // make sure x0 < x1 (draw horizontal)
        if (p0.x < p1.x) {
            ind0 = p0.y;
            ind1 = p1.y;
            dep0 = p0.x;
            dep1 = p1.x;
        } else {
            ind0 = p1.y;
            ind1 = p0.y;
            dep0 = p1.x;
            dep1 = p0.x;
        }

        try interpolate(ind0, dep0, ind1, dep1, &list);

        const start: usize = @intFromFloat(ind0);
        const end: usize = @intFromFloat(ind1);
        for (start..end) |y| {
            utils.put_canvas(canvas, list.items[y - start], y, color);
        }
    }
}

fn interpolate(ind0: float, dep0: float, ind1: float, dep1: float, list: *std.ArrayList(usize)) !void {
    // corner case
    if (ind0 == ind1) {
        try list.append(@intFromFloat(dep0));
        return;
    }

    const a = (dep1 - dep0) / (ind1 - ind0);
    var d = dep0;

    const start: usize = @intFromFloat(ind0);
    const end: usize = @intFromFloat(ind1);
    for (start..end) |_| {
        try list.append(@intFromFloat(d));
        d += a;
    }
    print("done loop {} times, cap is {}\n", .{end - start, list.capacity});
}

pub fn main() !void {

    print("canvas is {d} bytes large, w={} h={}\n", .{gcanvas.len, width, height});

    const p0: Coord2D = .{.x = 10, .y = 10};
    const p1: Coord2D = .{.x = 100, .y = 200};
    const p2: Coord2D = .{.x = 50, .y = 230};
    const p3: Coord2D = .{.x = 350, .y = 15};

    // static buffer allocator for interpolation function
    var fba = std.heap.FixedBufferAllocator.init(&interp_buffer_mem);

    try drawLine(
        p0,
        p1,
        White,
        &gcanvas,
        fba.allocator(),
    );

    fba.reset();

    try drawLine(
        p2,
        p3,
        White,
        &gcanvas,
        fba.allocator(),
    );

    try utils.write_canvas(&gcanvas, "rasterizer_test.ppm");
}
