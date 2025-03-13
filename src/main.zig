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

fn print_message(out: anytype) void {
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
        "We ride at dawn",
        "\x1b[31mMankind is dead.\nBlood is fuel.\nHell is full.\x1b[0m",
        "We ball",
    };

    var rnd = std.rand.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));
    out.print("{s}\n", .{messages[rnd.random().uintLessThan(usize, messages.len)]}) catch {};
}

fn print_uptime(out: anytype, uptime: u64) void {
    const uptime_hours: u64 = @divFloor(uptime, 60 * 60);
    const uptime_minutes = @mod(@divFloor(uptime, 60), 60);
    const uptime_seconds = @mod(@as(u64, uptime), 60);
    out.print(
        "UPTIME   {}:{:0>2}:{:0>2}\n",
        .{ uptime_hours, uptime_minutes, uptime_seconds },
    ) catch {};
}

fn print_kernel(out: anytype, uname: c.struct_utsname) void {
    out.print("KERNEL   {s} v{s}\n", .{ uname.sysname, uname.release }) catch {};
}

fn print_ram(out: anytype, sysinfo: c.struct_sysinfo) void {
    const ram_total_gb = @divFloor(sysinfo.totalram, std.math.pow(u64, 1024, 3));
    const ram_used_gb = @divFloor(sysinfo.totalram - sysinfo.freeram, std.math.pow(u64, 1024, 3));

    out.print("   RAM   {}Gb ({}Gb used)\n", .{ ram_total_gb, ram_used_gb }) catch {};
}

fn print_procs(out: anytype, sysinfo: c.struct_sysinfo) void {
    out.print(" PROCS   {}\n\n", .{sysinfo.procs}) catch {};
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var hostname: [64]u8 = std.mem.zeroes([64]u8);
    var sysinfo = c.struct_sysinfo{};

    if (c.gethostname(&hostname, hostname.len) != 0) {
        // NOTE(Julius): This isnt pretty. But it works!
        @setCold(true);
        @memcpy(hostname[0..7], "Unknown");
    }

    const show_uptime = c.sysinfo(&sysinfo) == 0;
    var uname = c.struct_utsname{};

    _ = c.uname(&uname);
    try stdout.print("Hello, {s}!\n\n", .{c.getlogin()});
    try stdout.print("You are logged into {s}\n\n", .{hostname});

    print_kernel(stdout, uname);

    if (show_uptime) {
        print_uptime(stdout, @intCast(sysinfo.uptime));
    }

    print_ram(stdout, sysinfo);
    print_procs(stdout, sysinfo);
    print_message(stdout);

    try bw.flush();
}
