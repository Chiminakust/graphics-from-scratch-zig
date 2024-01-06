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
const Green = Color {.r = 0, .g = 0xff, .b = 0};

// interpolating a single shaded triangle could potentially take 3*2*width*height elements
const interp_buf_size = nextCapacity(@as(usize, @max(width, height))) * @sizeOf(usize) * 6;
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

const Triangle = struct {
    p0: Coord2D,
    p1: Coord2D,
    p2: Coord2D,

    /// sort by increasing value in Y axis, modifies the triangle
    pub fn sortY(self: *Triangle) void {
        if (self.p1.y < self.p0.y) {
            Coord2D.swap(&self.p1, &self.p0);
        }
        if (self.p2.y < self.p0.y) {
            Coord2D.swap(&self.p2, &self.p0);
        }
        if (self.p2.y < self.p1.y) {
            Coord2D.swap(&self.p2, &self.p1);
        }
    }
};

const ShadedTriangle = struct {
    triangle: Triangle,
    h0: float,
    h1: float,
    h2: float,
};

// global variables
var canvas: utils.Canvas = .{
    .width = width,
    .height = height,
    .pixels = undefined,
};

fn drawLine(p0: Coord2D, p1: Coord2D, color: Color, allocator: Allocator) !void {
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

        try interpolate(usize, ind0, dep0, ind1, dep1, &list);

        const start: usize = @intFromFloat(ind0);
        const end: usize = @intFromFloat(ind1);
        for (start..end) |x| {
            canvas.put(x, list.items[x - start], color);
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

        try interpolate(usize, ind0, dep0, ind1, dep1, &list);

        const start: usize = @intFromFloat(ind0);
        const end: usize = @intFromFloat(ind1);
        for (start..end) |y| {
            canvas.put(list.items[y - start], y, color);
        }
    }
}

fn interpolate(comptime T: type, ind0: float, dep0: float, ind1: float, dep1: float, list: *std.ArrayList(T)) !void {
    if (T == float) {
        return interpolate_float(ind0, dep0, ind1, dep1, list);
    } else {
        return interpolate_usize(ind0, dep0, ind1, dep1, list);
    }
}

fn interpolate_float(ind0: float, dep0: float, ind1: float, dep1: float, list: *std.ArrayList(float)) !void {
    // corner case
    if (ind0 == ind1) {
        try list.append(dep0);
        return;
    }

    const a = (dep1 - dep0) / (ind1 - ind0);
    var d = dep0;

    const start: usize = @intFromFloat(ind0);
    const end: usize = @intFromFloat(ind1);
    for (start..end) |_| {
        try list.append(d);
        d += a;
    }
}

fn interpolate_usize(ind0: float, dep0: float, ind1: float, dep1: float, list: *std.ArrayList(usize)) !void {
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
}

pub fn drawWireTriangle(triangle: Triangle, color: Color, allocator: Allocator) !void {
    try drawLine(triangle.p0, triangle.p1, color, allocator);
    try drawLine(triangle.p1, triangle.p2, color, allocator);
    try drawLine(triangle.p2, triangle.p0, color, allocator);
}

pub fn drawFillTriangle(triangle: *Triangle, color: Color, allocator: Allocator) !void {
    // sort vertices
    triangle.sortY();

    // compute X coords of edges
    var x01 = std.ArrayList(usize).init(allocator);
    defer x01.deinit();
    var x12 = std.ArrayList(usize).init(allocator);
    defer x12.deinit();
    var x02 = std.ArrayList(usize).init(allocator);
    defer x02.deinit();

    try interpolate(usize, triangle.p0.y, triangle.p0.x, triangle.p1.y, triangle.p1.x, &x01);
    try interpolate(usize, triangle.p1.y, triangle.p1.x, triangle.p2.y, triangle.p2.x, &x12);
    try interpolate(usize, triangle.p0.y, triangle.p0.x, triangle.p2.y, triangle.p2.x, &x02);

    // concatenate short sides
    try x01.appendSlice(x12.items);

    // determine which is left and which is right
    const middle = x01.items.len / 2;
    var x_left = x01.items;
    var x_right = x02.items;
    if (x02.items[middle] < x01.items[middle]) {
        x_left = x02.items;
        x_right = x01.items;
    }

    // draw horizontal segments to fill the triangle
    const y_start: usize = @intFromFloat(triangle.p0.y);
    const y_end: usize = @intFromFloat(triangle.p2.y);
    for (y_start..y_end) |y| {
        const x_start = x_left[y - y_start];
        const x_end = x_right[y - y_start];
        for (x_start..x_end) |x| {
            canvas.put(x, y, color);
        }
    }
}

pub fn drawShadedTriangle(shaded_triangle: *ShadedTriangle, color: Color, allocator: Allocator) !void {
    var triangle = &shaded_triangle.triangle;

    // sort vertices
    triangle.sortY();

    // compute X coords of edges
    var x01 = std.ArrayList(usize).init(allocator);
    defer x01.deinit();
    var x12 = std.ArrayList(usize).init(allocator);
    defer x12.deinit();
    var x02 = std.ArrayList(usize).init(allocator);
    defer x02.deinit();
    var h01 = std.ArrayList(float).init(allocator);
    defer h01.deinit();
    var h12 = std.ArrayList(float).init(allocator);
    defer h12.deinit();
    var h02 = std.ArrayList(float).init(allocator);
    defer h02.deinit();

    try interpolate(usize, triangle.p0.y, triangle.p0.x, triangle.p1.y, triangle.p1.x, &x01);
    try interpolate(usize, triangle.p1.y, triangle.p1.x, triangle.p2.y, triangle.p2.x, &x12);
    try interpolate(usize, triangle.p0.y, triangle.p0.x, triangle.p2.y, triangle.p2.x, &x02);

    try interpolate(float, triangle.p0.y, shaded_triangle.h0, triangle.p1.y, shaded_triangle.h1, &h01);
    try interpolate(float, triangle.p1.y, shaded_triangle.h1, triangle.p2.y, shaded_triangle.h2, &h12);
    try interpolate(float, triangle.p0.y, shaded_triangle.h0, triangle.p2.y, shaded_triangle.h2, &h02);

    // concatenate short sides
    try x01.appendSlice(x12.items);
    try h01.appendSlice(h12.items);

    // determine which is left and which is right
    const middle = x01.items.len / 2;
    var x_left = x01.items;
    var x_right = x02.items;
    var h_left = h01.items;
    var h_right = h02.items;

    if (x02.items[middle] < x01.items[middle]) {
        x_left = x02.items;
        x_right = x01.items;
        h_left = h02.items;
        h_right = h01.items;
    }

    // draw horizontal segments to fill the triangle
    const y_start: usize = @intFromFloat(triangle.p0.y);
    const y_end: usize = @intFromFloat(triangle.p2.y);
    for (y_start..y_end) |y| {
        const x_start = x_left[y - y_start];
        const x_end = x_right[y - y_start];
        var h_segment = std.ArrayList(float).init(allocator);
        defer h_segment.deinit();

        try interpolate(
            float,
            @floatFromInt(x_start),
            h_left[y - y_start],
            @floatFromInt(x_end),
            h_right[y - y_start],
            &h_segment
        );
        for (x_start..x_end) |x| {
            canvas.put(x, y, color.apply_light(h_segment.items[x - x_start]));
        }
    }
}

pub fn main() !void {

    print("canvas is {d} bytes large, w={} h={}\n", .{canvas.pixels.len, width, height});

    const p0: Coord2D = .{.x = 10, .y = 10};
    const p1: Coord2D = .{.x = 350, .y = 50};
    const p2: Coord2D = .{.x = 50, .y = 230};
    //const p3: Coord2D = .{.x = 350, .y = 15};
    var t0: ShadedTriangle = .{
        .triangle = .{
            .p0=p0, .p1=p1, .p2=p2,
        },
        .h0 = 1,
        .h1 = 0.5,
        .h2 = 0,
    };


    // static buffer allocator for interpolation function
    var fba = std.heap.FixedBufferAllocator.init(&interp_buffer_mem);

    try drawWireTriangle(
        t0.triangle,
        White,
        fba.allocator(),
    );

    try drawShadedTriangle(
        &t0,
        Green,
        fba.allocator(),
    );

    try utils.write_canvas(&canvas.pixels, "rasterizer_test.ppm");
}
