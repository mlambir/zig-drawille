const zd = @import("zig-drawille");
const std = @import("std");


pub fn main_lines(display:zd.BrailleDisplay) !void{
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    var screen: *zd.Screen = display.screen;

    var points = try std.heap.page_allocator.alloc(i32, screen.width/8);
    
    var i:usize = 0;
    while(i<points.len):(i+=1){
        points[i] = rand.intRangeLessThan(i32, 0, @intCast(i32, screen.height*4));
    }

    var n:usize = 0;
    while (n < 10000) : (n += 1) {
        var start:i128 = std.time.nanoTimestamp();
        display.clear();

        i=0;
        while(i<points.len-1):(i+=1){
            zd.drawLine(display, @intCast(i32, i*8*2), points[i], @intCast(i32, (i+1)*8*2), points[i+1]);
            points[i] = points[i+1];
        }
        points[points.len-1] = rand.intRangeLessThan(i32, 0, @intCast(i32, screen.height*4));


        try display.draw();

        var t = std.time.nanoTimestamp() - start;
        var timediff = 1.0e9/10.0 - @intToFloat(f128, t);
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
