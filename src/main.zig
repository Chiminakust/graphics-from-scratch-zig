const std = @import("std");
const inf = std.math.inf(float);
//const sqrt = std.math.sqrt;
const pow = std.math.pow;

// typedef
const float = f32;
const int = i64;

// canvas dimensions
const width: int = 512;
const height: int = 512;

// viewport consts
const Vw: float = 1.0;
const Vh: float = 1.0;
const d: float = 1.0;

const epsilon: float = 0.1;
const recurse_max = 5;

// geometry stuff
const Coord3D = struct {
    x: float,
    y: float,
    z: float,

    pub fn new(x: float, y: float, z: float) Coord3D {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Coord3D, other: Coord3D) Coord3D {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Coord3D, other: Coord3D) Coord3D {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn scale(self: Coord3D, scalar: float) Coord3D {
        return Coord3D{ .x = scalar * self.x, .y = scalar * self.y, .z = scalar * self.z };
    }

    pub fn normalize(self: Coord3D) Coord3D {
        return self.scale(1 / self.length());
    }

    pub fn dot(self: Coord3D, other: Coord3D) float {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn length(self: Coord3D) float {
        return @sqrt(self.dot(self));
    }

    pub fn reverse(self: Coord3D) Coord3D {
        return self.scale(-1);
    }
};

// type alias for the same thing
const Vec3D = Coord3D;

// Intersection represents an object and the distance to that object from a point
const SphereIntersection = struct {
    sphere: ?Sphere,
    t: float,
};

const Sphere = struct {
    radius: float,
    center: Coord3D,
    color: Color,
    specular: ?float,
    reflective: float,
};

const Scene = struct {
    spheres: [4]Sphere,
    lights: [3]LightSource,
};

const scene = Scene{
    .spheres = .{
        Sphere{
            .radius = 1,
            .center = .{ .x = 0, .y = 1, .z = 3 },
            .color = .{ .r = 255, .g = 0, .b = 0 },
            .specular = 500,
            .reflective = 0.2,
        },
        Sphere{
            .radius = 1,
            .center = .{ .x = -2, .y = 0, .z = 4 },
            .color = .{ .r = 0, .g = 255, .b = 0 },
            .specular = 10,
            .reflective = 0.4,
        },
        Sphere{
            .radius = 1,
            .center = .{ .x = 2, .y = 0, .z = 4 },
            .color = .{ .r = 0, .g = 0, .b = 255 },
            .specular = 500,
            .reflective = 0.3,
        },
        Sphere{
            .radius = 5000,
            .center = .{ .x = 0, .y = 5001, .z = 10 },
            .color = .{ .r = 255, .g = 255, .b = 0 },
            .specular = 1000,
            .reflective = 0.5,
        },
    },
    .lights = .{
        LightSource.newAmbient(0.2),
        LightSource.newPoint(0.6, Coord3D.new(2, -1, 0)),
        LightSource.newPoint(0.2, Vec3D.new(1, -4, 4)),
    },
};

const Pixel = struct {
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
const Color = Pixel;
const BG_COLOR = Pixel{
    .r = 255,
    .g = 255,
    .b = 255,
};

// light stuff
const LightType = enum {
    ambient,
    directional,
    point,
};

const LightSource = struct {
    light_type: LightType,
    intensity: float,
    position: Coord3D,
    direction: Coord3D,

    pub fn newAmbient(intensity: float) LightSource {
        return LightSource{
            .light_type = LightType.ambient,
            .intensity = intensity,
            .position = Coord3D.new(0, 0, 0),
            .direction = Vec3D.new(0, 0, 0),
        };
    }

    pub fn newDirectional(intensity: float, direction: Vec3D) LightSource {
        return LightSource{
            .light_type = LightType.directional,
            .intensity = intensity,
            .position = Coord3D.new(0, 0, 0),
            .direction = direction,
        };
    }

    pub fn newPoint(intensity: float, position: Vec3D) LightSource {
        return LightSource{
            .light_type = LightType.point,
            .intensity = intensity,
            .position = position,
            .direction = Coord3D.new(0, 0, 0),
        };
    }
};

var canvas: [width * height]Pixel = undefined;

pub fn put_canvas(x: usize, y: usize, color: Color) void {
    canvas[x + (y * width)].r = color.r;
    canvas[x + (y * width)].g = color.g;
    canvas[x + (y * width)].b = color.b;
}

pub fn write_canvas(path: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();

    const writer = file.writer();

    // P3 means RGB, and 255 is the max value for each color
    try writer.print("P3\n{} {}\n255\n", .{ width, height });

    for (canvas) |pixel| {
        try writer.print("{} {} {}\n", .{ pixel.r, pixel.g, pixel.b });
    }
}

pub fn canvas_to_viewport(cx: int, cy: int) Coord3D {
    return Coord3D.new(@as(float, @floatFromInt(cx)) * (Vw / width), @as(float, @floatFromInt(cy)) * (Vh / height), d);
}

pub fn trace_ray(origin: Coord3D, D: Vec3D, t_min: float, t_max: float, recursion: int) Pixel {
    const intersection = closest_intersection(origin, D, t_min, t_max);
    if (intersection.sphere) |sphere| {
        // initial lighting
        const P = origin.add(D.scale(intersection.t));
        var N = P.sub(sphere.center);
        N = N.normalize();
        const color = sphere.color.apply_light(compute_lighting(P, N, D.reverse(), sphere.specular));

        // check for reflections
        if (sphere.reflective <= 0 or recursion <= 0) {
            return color;
        }

        // compute reflected color
        const R = reflect_ray(D.reverse(), N);
        const reflected_color = trace_ray(P, R, epsilon, inf, recursion - 1);
        return color.apply_light(1 - sphere.reflective).add(reflected_color.apply_light(sphere.reflective));
    } else {
        return BG_COLOR;
    }
}

pub fn closest_intersection(origin: Coord3D, D: Vec3D, t_min: float, t_max:float) SphereIntersection {
    var intersection: SphereIntersection = .{.sphere = null, .t = inf};

    for (scene.spheres) |sphere| {
        const tuple = intersect_ray_sphere(origin, D, sphere);
        const t1 = tuple[0];
        const t2 = tuple[1];

        if (((t_min <= t1) and (t1 <= t_max)) and t1 < intersection.t) {
            intersection.t = t1;
            intersection.sphere = sphere;
        }

        if (((t_min <= t2) and (t2 <= t_max)) and t2 < intersection.t) {
            intersection.t = t2;
            intersection.sphere = sphere;
        }
    }

    return intersection;
}

pub fn intersect_ray_sphere(origin: Coord3D, D: Vec3D, sphere: Sphere) [2]float {
    const r = sphere.radius;
    const co = origin.sub(sphere.center);

    const a = D.dot(D);
    const b = 2 * co.dot(D);
    const c = co.dot(co) - (r * r);

    const discriminant = (b * b) - (4 * a * c);
    if (discriminant < 0) {
        return .{ inf, inf };
    }

    return .{
        (-b + @sqrt(discriminant)) / (2 * a),
        (-b - @sqrt(discriminant)) / (2 * a),
    };
}

pub fn compute_lighting(P: Coord3D, N: Vec3D, V: Vec3D, specular: ?float) float {
    var i: float = 0;
    var t_max: float = 0;

    for (scene.lights) |light| {
        if (light.light_type == LightType.ambient) {
            i += light.intensity;
        } else {
            var L: Vec3D = Vec3D{ .x = 0, .y = 0, .z = 0 };

            if (light.light_type == LightType.point) {
                L = light.position.sub(P);
                t_max = 1;
            } else if (light.light_type == LightType.directional) {
                L = light.direction;
                t_max = inf;
            } else {
                // unhandled light type
                continue;
            }

            // shadow check
            const intersection = closest_intersection(P, L, epsilon, t_max);
            if (intersection.sphere) |_| {
                continue;
            }

            // diffuse reflection
            const n_dot_l = N.dot(L);
            if (n_dot_l > 0) {
                i += light.intensity * n_dot_l / (N.length() * L.length());
            }

            // specular reflection
            if (specular) |s| {
                const R = reflect_ray(L, N);
                const r_dot_v = R.dot(V);

                if (r_dot_v > 0) {
                    i += light.intensity * pow(float, r_dot_v / (R.length() * V.length()), s);
                }
            }
        }
    }

    return i;
}

pub fn reflect_ray(L: Vec3D, N: Vec3D) Vec3D {
    // 2 * N * dot(N, L) - L
    return N.scale(2 * N.dot(L)).sub(L);
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("canvas is {d} bytes large\n", .{canvas.len});
    const ORIGIN = Coord3D.new(0, 0, 0);

    for (0..width) |x| {
        for (0..height) |y| {
            const D = canvas_to_viewport(@as(int, @intCast(x)) - (width / 2), @as(int, @intCast(y)) - (height / 2));
            const color = trace_ray(ORIGIN, D, 1, inf, recurse_max);
            put_canvas(x, y, color);
        }
    }

    try write_canvas("test.ppm");
}
