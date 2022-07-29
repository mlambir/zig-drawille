const std = @import("std");
const c = @cImport(@cInclude("sys/ioctl.h"));

const ascii = std.ascii;
const io = std.io;
const fmt = std.fmt;
const os = std.os;
const system = os.system;
const print = warn;
const termios = os.termios;
const warn = std.debug.warn;

const STDIN_FILENO = 0;
const stdout = std.io.getStdOut().writer();
const in_stream = std.io.getStdOut().reader();
const VMIN = 5;
const VTIME = 6;

pub const Screen = struct {
    width: usize = undefined,
    height: usize = undefined,
    buf: ?[]u16 = null,

    original: termios,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Screen {
        var screen = Screen{
            .original = os.tcgetattr(STDIN_FILENO) catch {
                unreachable;
            },
            .allocator = allocator,
        };
        try screen.updateSize();

        var raw = screen.original;

        raw.iflag &= ~(system.IGNBRK | system.BRKINT | system.PARMRK | system.ISTRIP | system.INLCR | system.IGNCR | system.ICRNL | system.IXON);
        raw.oflag &= ~system.OPOST;
        raw.lflag &= ~(system.ECHO | system.ECHONL | system.ICANON | system.ISIG | system.IEXTEN);
        raw.cflag &= ~(system.CSIZE | system.PARENB);
        raw.cflag |= system.CS8;
        raw.cc[system.V.MIN] = 1;
        raw.cc[system.V.TIME] = 0;

        // if (!os.isatty(STDIN_FILENO)) {
        //     return error.NotATTY;
        // }

        screen.clear() catch {};

        // disable cursor
        _ = stdout.write("\x1B[?25l") catch {};

        return screen;
    }

    pub fn end(self: *Screen) !void {
        // free the memory first in case the next ones fail
        if (self.buf) |buf| {
            self.allocator.free(buf);
        }
        // clear screen
        //_ = try stdout.write("\x1b[2J");
        //_ = try stdout.write("\x1b[H");
        // re-enable cursor
        _ = try stdout.write("\x1B[?25h");
        // Restore the original termios
        try os.tcsetattr(STDIN_FILENO, os.TCSA.FLUSH, self.original);
    }

    /// erases the buffer and clears the screen, can be expensive and cause flickering
    pub fn clear(self: Screen) !void {
        _ = self;
        _ = try stdout.write("\x1b[2J");
        _ = try stdout.write("\x1b[H");
    }

    pub fn buf_clear(self: *Screen) !void {
        if (self.buf) |buf| {
            var i: usize = 0;
            while (i < buf.len) : (i += 1) {
                buf[i] = ' ';
            }
        }
    }

    fn updateSize(self: *Screen) !void {
        var w: c.winsize = std.mem.zeroes(c.winsize);
        _ = c.ioctl(0, c.TIOCGWINSZ, &w);
        self.width = w.ws_col;
        self.height = w.ws_row;
        if (self.buf) |b| {
            self.allocator.free(b);
        }
        self.buf = try self.allocator.alloc(u16, self.width * self.height);
    }

    pub fn set_at(self: *Screen, x:usize, y:usize, char: u16) void {
        if (self.buf) |buf| {
            buf[self.width * y + x] = char;
        }else{
            std.debug.print("starting...", .{});
        }
    }

    pub fn refresh(self: Screen) !void {
        if (self.buf) |buf| {
            const utf8string = try std.unicode.utf16leToUtf8Alloc(self.allocator, buf);
            defer self.allocator.free(utf8string);
            _ = try stdout.write("\x1b[0;0H");
            _ = try stdout.write(utf8string);
        }
    }
};

// dots:
//    ,___,
//    |1 4|
//    |2 5|
//    |3 6|
//    |7 8|
//    `````

const pixel_map = [4][2]u8{ [_]u8{ 0x01, 0x08 }, 
                            [_]u8{ 0x02, 0x10 }, 
                            [_]u8{ 0x04, 0x20 }, 
                            [_]u8{ 0x40, 0x80 } };

// braille unicode characters starts at 0x2800
const braille_char_offset = 0x2800;

pub const BrailleDisplay = struct {
    screen: *Screen,
    buf: []bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, screen: *Screen) !BrailleDisplay {

        var b = BrailleDisplay{ .allocator = allocator, 
                                .screen = screen, 
                                .buf = try allocator.alloc(bool, screen.width * screen.height * 8) };
        b.clear();
        return b;
    }

    pub fn end(self: BrailleDisplay) !void {
        self.allocator.free(self.buf);
        self.screen.end() catch {};
    }

    pub fn clear(self: BrailleDisplay) void {
        var i: usize = 0;
        while (i < self.buf.len) : (i += 1) {
            self.buf[i] = false;
        }
    }

    pub fn point(self:BrailleDisplay, x: i32, y: i32, val: bool) void {
        // std.debug.print("p: {}\n", .{x + y * self.screen.width * 2});
        if(x<0 or y<0 or x>=self.screen.width*2 or y>=self.screen.height*4) return;
        self.buf[@intCast(usize, x) + @intCast(usize, y) * self.screen.width * 2] = val;
    }

    pub fn draw(self: BrailleDisplay) !void {
        var x: usize = 0;
        while(x<self.screen.width):(x+=1){
            var y: usize = 0;
            while(y<self.screen.height):(y+=1){
                var char:u16 = braille_char_offset;
                for(pixel_map) |row, my| {
                    for(row) |char_offset, mx| {
                        if(self.buf[x*2+mx + (y*4+my)*self.screen.width*2]){
                            char |= char_offset;
                        }
                    }
                }
                self.screen.set_at(x, y, char);
            }
        }
        try self.screen.refresh();
    }
};

pub fn drawLine(d:BrailleDisplay, x0_:i32, y0_:i32, x1_:i32, y1_: i32) void{
    var x0:i32 = x0_;
    var x1:i32 = x1_;
    var y0:i32 = y0_;
    var y1:i32 = y1_;
    var dx:i32 = std.math.absInt(x1 - x0) catch unreachable;
    var sx:i32 = if(x0 < x1) 1 else -1;
    var dy:i32 =  -(std.math.absInt(y1 - y0) catch unreachable);
    var sy:i32 = if(y0 < y1) 1 else -1;
    var err:i32 = dx + dy;

    while(true){
        d.point(x0, y0, true);
        if (x0 == x1 and y0 == y1) break;
        var e2 = 2 * err;

        if (e2 >= dy){
            if (x0 == x1) break;
            err = err + dy;
            x0 = x0 + sx;
        }
        if (e2 <= dx){
            if(y0 == y1) break;
            err = err + dx;
            y0 = y0 + sy;
        }
    }
}