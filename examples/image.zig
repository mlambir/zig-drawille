const zd = @import("zig-drawille");
const std = @import("std");

const zigimg = @import("zigimg");
const Image = zigimg.Image;

pub fn main_img(display:zd.BrailleDisplay) !void{
    var screen: *zd.Screen = display.screen;
    _ = screen;
    var img:Image = try Image.fromFilePath(std.heap.page_allocator, "assets/lenna.png");
    defer img.deinit();

    var pixelsIterator = img.iterator();
    var i:usize = 0;
    while(true){
        while (pixelsIterator.next()) |color| : (i += 1) {
            var color_float =(color.r + color.g + color.b) / 3.0;
            if(color_float > 0.5){
                display.point(@intCast(i32, i%img.width), @intCast(i32, i/img.height), true);
            }
        }
        try display.draw();
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
