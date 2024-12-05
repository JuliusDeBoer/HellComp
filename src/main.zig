const std = @import("std");
const c = @cImport({
    @cInclude("unistd.h");
    @cInclude("sys/sysinfo.h");
});

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var hostname: [64]u8 = undefined;
    var sysinfo = c.struct_sysinfo{};
    _ = c.gethostname(&hostname, hostname.len);
    _ = c.sysinfo(&sysinfo);
    const username = c.getlogin();

    const uptime_hours: u64 = @divFloor(@as(u64, @intCast(sysinfo.uptime)), 60 * 60);
    const uptime_minutes = @mod(@divFloor(@as(u64, @intCast(sysinfo.uptime)), 60), 60);
    const uptime_seconds = @mod(@as(u64, @intCast(sysinfo.uptime)), 60);

    const ram_gb = @divFloor(sysinfo.totalram, std.math.pow(u64, 1024, 3));

    try stdout.print("Hello, {s}!\n\n", .{username});
    try stdout.print("You are logged into {s}\n\n", .{hostname});
    try stdout.print("UPTIME   {}:{:0>2}:{:0>2}\n", .{ uptime_hours, uptime_minutes, uptime_seconds });
    try stdout.print("   RAM   {}Gb\n", .{ram_gb});
    try stdout.print(" PROCS   {}\n\n", .{sysinfo.procs});
    try stdout.print("Good hunting!\n", .{});
    try bw.flush();
}
