const zd = @import("zig-drawille");
const std = @import("std");

const zigimg = @import("zigimg");
const Image = zigimg.Image;

pub fn main_img_dither(display:zd.BrailleDisplay) !void{
    var screen: *zd.Screen = display.screen;
    _ = screen;
    var img:Image = try Image.fromFilePath(std.heap.page_allocator, "assets/lenna.png");
    defer img.deinit();

    var grayscale_img_buf: []f32 = try std.heap.page_allocator.alloc(f32, img.width*img.height);
    var pixelsIterator = img.iterator();
    var n:usize = 0;
    while (pixelsIterator.next()) |color| : (n += 1) {
        grayscale_img_buf[n] = (color.r + color.g + color.b) / 3.0;
    }

    var y:usize = 0;
    while(y<img.height-1):(y+=1){
        var x:usize = 1;
        while(x<img.width-1):(x+=1){
            var oldpixel:f32 = grayscale_img_buf[x+y*img.height];
            var newpixel:f32 = std.math.round(oldpixel);
            grayscale_img_buf[x+y*img.height] = newpixel;
            var quant_error:f32 = oldpixel - newpixel;
            grayscale_img_buf[x+1+y*img.width] = grayscale_img_buf[x+1+y*img.height] + quant_error * 7.0 / 16.0;
            grayscale_img_buf[x-1+(y+1*img.width)] = grayscale_img_buf[x-1+(y+1*img.width)] + quant_error * 3.0 / 36.0;
            grayscale_img_buf[x+(y+1*img.width)] = grayscale_img_buf[x+(y+1*img.width)] + quant_error * 5.0 / 36.0;
            grayscale_img_buf[x+1+(y+1*img.width)] = grayscale_img_buf[x+1+(y+1*img.width)] + quant_error * 1.0 / 36.0;
        }   
    }
    
    while(true){
        for (grayscale_img_buf) |color, i|{
            if(color > 0.5){
                display.point(@intCast(i32, i%img.width), @intCast(i32, i/img.height), true);
            }
        }
        try display.draw();
        std.time.sleep(1e+9);
    }
}


pub fn main() anyerror!void {
    var screen = try zd.Screen.init(std.heap.page_allocator);
    var display = try zd.BrailleDisplay.init(std.heap.page_allocator, &screen);
    std.debug.print("screen size: {} x {}\n", .{display.screen.width, display.screen.height});
    std.debug.print("buf size: {}\n", .{display.buf.len});
    std.time.sleep(1e+9);
    std.debug.print("starting...", .{});

    try main_img_dither(display);

    std.debug.print("ending...", .{});
    try display.end();
}
