const std = @import("std");
const c = @cImport({
    @cInclude("sys/sysinfo.h");
    @cInclude("sys/utsname.h");
    @cInclude("unistd.h");
});

const os_info = struct {
    pretty_name: []const u8,
};

fn get_os_info() os_info {
    var out = os_info{ .pretty_name = "Unknown" };

    const os_file = std.fs.openFileAbsolute("/etc/os-release", .{}) catch return out;
    defer os_file.close();

    var buf: [1024]u8 = undefined;
    var buf_reader = std.io.bufferedReader(os_file.reader());
    var in_stream = buf_reader.reader();

    while (in_stream.readUntilDelimiterOrEof(&buf, '\n') catch return out) |line| {
        const key = std.mem.sliceTo(line, '=');

        if (std.mem.eql(u8, key, "PRETTY_NAME")) {
            const quote_start = std.mem.indexOf(u8, line, "\"") orelse continue;
            const quote_end = std.mem.lastIndexOf(u8, line, "\"") orelse continue;

            std.debug.assert(quote_start < quote_end);

            out.pretty_name = std.heap.page_allocator.dupe(
                u8,
                line[quote_start + 1 .. quote_end],
            ) catch return out;
        }
    }

    return out;
}

fn pick_message() *const []const u8 {
    const messages = [_][]const u8{
        "Good hunting sir",
        "Happy coding",
        "Good luck out there",
        "For science. You monster",
        "Rock and stone",
        "Amen brother",
        "Time to face the music",
        "May your updates be many and your errors few",
        "Lets dance",
        "\x1b[31mMankind is dead.\nBlood is fuel.\nHell is full.\x1b[0m",
    };

    var rnd = std.rand.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
    return &messages[rnd.random().uintLessThan(usize, messages.len)];
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var hostname: [64]u8 = undefined;
    var sysinfo = c.struct_sysinfo{};

    if (c.gethostname(&hostname, hostname.len) != 0) {
        // NOTE(Julius): This isnt pretty. But it works!
        @setCold(true);
        @memcpy(hostname[0..7], "Unknown");
    }

    const show_uptime = c.sysinfo(&sysinfo) == 0;
    const username = c.getlogin();

    var uname = c.struct_utsname{};
    _ = c.uname(&uname);

    const ram_total_gb = @divFloor(sysinfo.totalram, std.math.pow(u64, 1024, 3));
    const ram_used_gb = @divFloor(sysinfo.totalram - sysinfo.freeram, std.math.pow(u64, 1024, 3));

    const info = get_os_info();

    try stdout.print("Hello, {s}!\n\n", .{username});
    try stdout.print("You are logged into {s}\n\n", .{hostname});
    try stdout.print("    OS   {s}\n", .{info.pretty_name});
    try stdout.print("KERNEL   {s} v{s}\n", .{ uname.sysname, uname.release });

    if (show_uptime) {
        const uptime_hours: u64 = @divFloor(@as(u64, @intCast(sysinfo.uptime)), 60 * 60);
        const uptime_minutes = @mod(@divFloor(@as(u64, @intCast(sysinfo.uptime)), 60), 60);
        const uptime_seconds = @mod(@as(u64, @intCast(sysinfo.uptime)), 60);
        try stdout.print("UPTIME   {}:{:0>2}:{:0>2}\n", .{ uptime_hours, uptime_minutes, uptime_seconds });
    } else {
        try stdout.print("UPTIME   ???\n", .{});
    }

    try stdout.print("   RAM   {}Gb ({}Gb used)\n", .{ ram_total_gb, ram_used_gb });
    try stdout.print(" PROCS   {}\n\n", .{sysinfo.procs});
    try stdout.print("{s}\n", .{pick_message().*});
    try bw.flush();
}
