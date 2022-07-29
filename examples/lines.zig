const zd = @import("zig-drawille");
const std = @import("std");


const Point = struct{
    x:i32, 
    y:i32
};
const Line = struct{
    p1: Point, 
    p2: Point
};

const MovingLine = struct{
    p1: Point,
    p2: Point,
    v1: Point,
    v2: Point,
};

pub fn main_lines(display:zd.BrailleDisplay) !void{
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    var screen: *zd.Screen = display.screen;

    var lines = std.ArrayList(MovingLine).init(std.heap.page_allocator);

    var n:usize = 0;
    while(n<30):(n+=1){
        try lines.append(MovingLine{.p1 = Point{.x=rand.intRangeAtMost(i32, 0, @intCast(i32, screen.width*2-1)), 
                              .y=rand.intRangeAtMost(i32, 0, @intCast(i32, screen.height*4-1))}, 
                   .p2 = Point{.x=rand.intRangeAtMost(i32, 0, @intCast(i32, screen.width*2-1)),
                              .y=rand.intRangeAtMost(i32, 0, @intCast(i32, screen.height*4-1))}, 
                   .v1 = Point{.x=rand.intRangeAtMost(i32, -1, 1),
                               .y=rand.intRangeAtMost(i32, -1, 1)},
                   .v2 = Point{.x=rand.intRangeAtMost(i32, -1, 1),
                               .y=rand.intRangeAtMost(i32, -1, 1)}});
    }

    n = 0;
    while (n < 10000) : (n += 1) {
        var start:i128 = std.time.nanoTimestamp();
        display.clear();
        for(lines.items) |line|{
            zd.drawLine(display, line.p1.x, line.p1.y, line.p2.x, line.p2.y);
        }
        var i:usize = 0;
        while(i < lines.items.len):(i+=1){
            lines.items[i].p1.x += lines.items[i].v1.x;
            lines.items[i].p1.y += lines.items[i].v1.y;
            lines.items[i].p2.x += lines.items[i].v2.x;
            lines.items[i].p2.y += lines.items[i].v2.y;
            if(lines.items[i].p1.x < 0 or lines.items[i].p1.x >= screen.width * 2) lines.items[i].v1.x *= -1;
            if(lines.items[i].p1.y < 0 or lines.items[i].p1.y >= screen.height * 4) lines.items[i].v1.y *= -1;
            if(lines.items[i].p2.x < 0 or lines.items[i].p2.x >= screen.width * 2) lines.items[i].v2.x *= -1;
            if(lines.items[i].p2.y < 0 or lines.items[i].p2.y >= screen.height * 4) lines.items[i].v2.y *= -1;
        }

        try display.draw();

        var t = std.time.nanoTimestamp() - start;
        var timediff = 1.0e9/60.0 - @intToFloat(f128, t);
        if(timediff>0){
            std.time.sleep(@floatToInt(u64, timediff));
        }
        t = std.time.nanoTimestamp() - start;
        // _ = try stdout.print("\x1b[0;0H FPS: {d:.2}", .{@floatCast(f64, 1.0e9/@intToFloat(f128, t))});
    }
}

pub fn main() anyerror!void {
    var screen = try zd.Screen.init(std.heap.page_allocator);
    var display = try zd.BrailleDisplay.init(std.heap.page_allocator, &screen);
    std.debug.print("screen size: {} x {}\n", .{display.screen.width, display.screen.height});
    std.debug.print("buf size: {}\n", .{display.buf.len});
    std.time.sleep(1e+9);
    std.debug.print("starting...", .{});

    try main_lines(display);

    std.debug.print("ending...", .{});
    try display.end();
}
