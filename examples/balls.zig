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

const MovingBall = struct{
    p: Point,
    v: Point,
    r: f64
};

pub fn main_balls(display:zd.BrailleDisplay) !void{
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    var screen: *zd.Screen = display.screen;
    var points = std.ArrayList(MovingBall).init(std.heap.page_allocator);
    defer points.deinit();

    var n:usize = 0;
    while(n<30):(n+=1){
        try points.append(MovingBall{.p = Point{.x=rand.intRangeAtMost(i32, 0, @intCast(i32, screen.width*2-1)), 
                              .y=rand.intRangeAtMost(i32, 0, @intCast(i32, screen.height*4-1))}, 
                    .v = Point{.x=rand.intRangeAtMost(i32, -1, 1),
                               .y=rand.intRangeAtMost(i32, -1, 1)}, 
                    .r = rand.float(f64) * 500.0});
    }

    n = 0;
    while (n < 10000) : (n += 1) {
        var start:i128 = std.time.nanoTimestamp();
        display.clear();
        
        var x:i32 = 0;
        while(x<screen.width*2):(x+=1){
            var y:i32 = 0;
            while(y<screen.height*4):(y+=1){
                var val:f64 = 0;
                for(points.items) |point|{
                    val += point.r/(@intToFloat(f64, (x-point.p.x) * (x-point.p.x)) + @intToFloat(f64, (y-point.p.y) * (y-point.p.y)));
                }   
                if(val > 1) display.point(x, y, true);      
            }   
        }

        var i:usize = 0;
        while(i < points.items.len):(i+=1){
            points.items[i].p.x += points.items[i].v.x;
            points.items[i].p.y += points.items[i].v.y;

            if(points.items[i].p.x < 0 or points.items[i].p.x >= screen.width * 2) points.items[i].v.x *= -1;
            if(points.items[i].p.y < 0 or points.items[i].p.y >= screen.height * 4) points.items[i].v.y *= -1;
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

    try main_balls(display);

    std.debug.print("ending...", .{});
    try display.end();
}
