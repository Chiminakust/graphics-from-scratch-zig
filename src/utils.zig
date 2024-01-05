
const std = @import("std");

// typedef
pub const float = f32;
pub const int = i64;

// canvas dimensions
pub const width: int = 372;
pub const height: int = 240;

pub const Pixel = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn apply_light(self: Pixel, intensity: float) Pixel {
        const valid_intensity = std.math.clamp(intensity, 0, 1);
        return Pixel{
            .r = @intFromFloat(@as(float, @floatFromInt(self.r)) * valid_intensity),
            .g = @intFromFloat(@as(float, @floatFromInt(self.g)) * valid_intensity),
            .b = @intFromFloat(@as(float, @floatFromInt(self.b)) * valid_intensity),
        };
    }

    pub fn add(self: Pixel, other: Pixel) Pixel {
        return .{
            .r = self.r +| other.r,
            .g = self.g +| other.g,
            .b = self.b +| other.b,
        };
    }
};

// type alias for colors
pub const Color = Pixel;

pub const Canvas = struct {
    width: usize,
    height: usize,
    pixels: [width * height]Pixel,

    pub fn put(self: *Canvas, x: usize, y: usize, color: Color) void {
        self.pixels[x + (y * width)].r = color.r;
        self.pixels[x + (y * width)].g = color.g;
        self.pixels[x + (y * width)].b = color.b;
    }
};

pub fn write_canvas(canvas: []Pixel, path: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();

    const writer = file.writer();

    // P3 means RGB, and 255 is the max value for each color
    try writer.print("P3\n{} {}\n255\n", .{ width, height });

    for (canvas) |pixel| {
        try writer.print("{} {} {}\n", .{ pixel.r, pixel.g, pixel.b });
    }
}

/// Stolen/modified straight from the array_list.zig source code. This is useful
/// for determining the size of a fixedBufferAllocator's buffer.
/// Otherwise, if only the exact amount of bytes is allocated, you
/// still get an out-of-memory error because it checks to allocate more.
pub fn nextCapacity(minimum: usize) usize {
    var new: usize = 0;
    while (true) {
        new +|= new / 2 + 8;
        if (new >= minimum) {
            return new;
        }
    }
}
