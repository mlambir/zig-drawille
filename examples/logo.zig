const zd = @import("zig-drawille");
const std = @import("std");

const zigimg = @import("zigimg");
const Image = zigimg.Image;

const Point = struct{
    x:i32, 
    y:i32
};

const MovingPoint = struct{
        p: Point,
        v: Point,
        r: f64
    };

pub fn main_img(display:zd.BrailleDisplay) !void{
    
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    
    var screen: *zd.Screen = display.screen;
    _ = screen;
    var img:Image = try Image.fromFilePath(std.heap.page_allocator, "assets/logo.png");
    defer img.deinit();

    var points = std.ArrayList(MovingPoint).init(std.heap.page_allocator);
    defer points.deinit();

    var n:usize = 0;
    while(n<5):(n+=1){
        try points.append(MovingPoint{.p = Point{.x=rand.intRangeAtMost(i32, 0, @intCast(i32, screen.width*2-1-img.width)), 
                              .y=rand.intRangeAtMost(i32, 0, @intCast(i32, screen.height*4-1-img.height))}, 
                    .v = Point{.x=rand.intRangeAtMost(i32, -1, 1),
                               .y=rand.intRangeAtMost(i32, -1, 1)}, 
                    .r = rand.float(f64) * 500.0});
    }



    while(true){
        display.clear();
        var start:i128 = std.time.nanoTimestamp();
        var pixelsIterator = img.iterator();
        var i:usize = 0;
        while (pixelsIterator.next()) |color| : (i += 1) {
            var color_float =(color.r + color.g + color.b) / 3.0;
            if(color_float > 0.5){
                for(points.items) |p|{
                    display.point(@intCast(i32, i%img.width) + p.p.x, @intCast(i32, i/img.width)+p.p.y, true);
                }
            }
        }

        i = 0;
        while(i < points.items.len):(i+=1){
            points.items[i].p.x += points.items[i].v.x;
            points.items[i].p.y += points.items[i].v.y;

            if(points.items[i].p.x < 0 or points.items[i].p.x >= screen.width * 2 - img.width) points.items[i].v.x *= -1;
            if(points.items[i].p.y < 0 or points.items[i].p.y >= screen.height * 4 - img.height) points.items[i].v.y *= -1;
        }

        try display.draw();
        var t = std.time.nanoTimestamp() - start;
        var timediff = 1.0e9/60.0 - @intToFloat(f128, t);
        if(timediff>0){
            std.time.sleep(@floatToInt(u64, timediff));
        }
        t = std.time.nanoTimestamp() - start;
    }
}

pub fn main() anyerror!void {
    var screen = try zd.Screen.init(std.heap.page_allocator);
    var display = try zd.BrailleDisplay.init(std.heap.page_allocator, &screen);
    std.debug.print("screen size: {} x {}\n", .{display.screen.width, display.screen.height});
    std.debug.print("buf size: {}\n", .{display.buf.len});
    std.time.sleep(1e+9);
    std.debug.print("starting...", .{});

    try main_img(display);

    std.debug.print("ending...", .{});
    try display.end();
}
