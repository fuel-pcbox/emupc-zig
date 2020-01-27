const std = @import("std");
const io = std.io;
const mem = std.mem;

const Allocator = std.mem.Allocator;

pub const KiB = 1024;
pub const MiB = 1024 * KiB;
pub const GiB = 1024 * MiB;

const cpu_808x_flags = packed struct {
    carry: u1 = 0,
    reserved1: u1 = 1,
    parity: u1 = 0,
    reserved2: u1 = 0,
    adjust: u1 = 0,
    reserved3: u1 = 0,
    zero: u1 = 0,
    sign: u1 = 0,
    trap: u1 = 0,
    interrupt: u1 = 0,
    direction: u1 = 0,
    overflow: u1 = 0,
    reserved4: u4 = 0xf,
};

pub const cpu_808x = struct {
    gprs: [8]u16,
    segs: [4]u16,
    flags: cpu_808x_flags,
    ip: u16 = 0,
    opcode: u8 = 0,

    pub fn new() cpu_808x {
        var gprs = [8]u16{0, 0, 0, 0, 0, 0, 0, 0};
        var segs = [4]u16{ 0, 0xffff, 0, 0};
        return cpu_808x{
            .gprs = gprs, .segs = segs, .flags = cpu_808x_flags{}
        };
    }
};

pub const pcmachine = struct {
    rom: []u8,
    ram: []u8,
    cpu: cpu_808x,

    pub fn new(allocator: *Allocator, rom_path: []const u8) !pcmachine {
        var ram = try allocator.alloc(u8, 640 * KiB);
        mem.set(u8, ram, 0);

        return pcmachine{
            .rom = try io.readFileAlloc(allocator, rom_path),
            .ram = ram,
            .cpu = cpu_808x.new(),
        };
    }
};

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;

    const args = try std.process.argsAlloc(allocator);

    if (args.len != 2) {
        std.process.exit(2);
    }

    const machine_name = args[1];
    if(mem.eql(u8, machine_name, "ibmxt"))
    {
        const rom_path = "roms\\machines\\ibmpc\\BIOS_5150_24APR81_U33.BIN";
        var machine = try pcmachine.new(allocator, rom_path);

        std.debug.warn("Opcode: {0x:0<2}\n", .{machine.rom[((machine.cpu.segs[1] << 4) + machine.cpu.ip) & 0x1fff]});
    }
}