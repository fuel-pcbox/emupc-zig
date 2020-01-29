const std = @import("std");
const io = std.io;
const mem = std.mem;
const traits = @import("traits.zig");

const Allocator = std.mem.Allocator;

pub const KiB = 1024;
pub const MiB = 1024 * KiB;
pub const GiB = 1024 * MiB;

const Cpu808xFlags = packed struct {
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

    pub fn setFlags(self: @This(), value: u16) void {
        carry = value & 1;
        parity = (value >> 2) & 1;
        adjust = (value >> 4) & 1;
        zero = (value >> 6) & 1;
        sign = (value >> 7) & 1;
        trap = (value >> 8) & 1;
        interrupt = (value >> 9) & 1;
        direction = (value >> 10) & 1;
        overflow = (value >> 11) & 1;
    }

    pub fn getFlags(self: @This()) u16 {
        return carry | (@as(u16, parity) << 2) | (@as(u16, adjust) << 4) | (@as(u16, zero) << 6) |
            (@as(u16, sign) << 7) | (@as(u16, trap) << 8) | (@as(u16, interrupt) << 9) | (@as(u16, direction) << 10) |
            (@as(u16, overflow) << 11);
    }
};

pub const Cpu808x = struct {
    gprs: [8]u16,
    segs: [4]u16,
    flags: Cpu808xFlags,
    ip: u16 = 0,
    opcode: u8 = 0,

    pub fn init() Cpu808x {
        var gprs = [8]u16{ 0, 0, 0, 0, 0, 0, 0, 0 };
        var segs = [4]u16{ 0, 0xffff, 0, 0 };
        return Cpu808x{
            .gprs = gprs,
            .segs = segs,
            .flags = Cpu808xFlags{},
        };
    }

    pub fn tick(self: *@This(), machine: var) void {
        if (comptime !traits.implementsMachine(@TypeOf(machine))) {
            @compileError("Passed in non-valid machine");
        }
    }
};

pub const PcMachine = struct {
    rom: []u8,
    ram: []u8,
    cpu: Cpu808x,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator, rom_path: []const u8) !PcMachine {
        var ram = try allocator.alloc(u8, 640 * KiB);
        mem.set(u8, ram, 0);

        return PcMachine{
            .rom = try io.readFileAlloc(allocator, rom_path),
            .ram = ram,
            .cpu = Cpu808x.init(),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.ram);
    }

    pub fn memReadByte(self: PcMachine, address: u20) u8 {
        return switch (address) {
            0...0x9ffff => self.ram[address],
            0xa0000...0xfdfff => 0xff,
            0xfe000...0xfffff => self.rom[address & 0x1fff],
        };
    }

    pub fn memWriteByte(self: PcMachine, address: u20, data: u8) void {
        switch (address) {
            0...0x9ffff => self.ram[address] = data,
            0xa0000...0xfffff => return,
        }
    }
};

pub fn main() anyerror!void {
    const allocator = std.heap.c_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer allocator.free(args);

    if (args.len != 2) {
        return error.incorrectArgumentCount;
    }

    const machine_name = args[1];
    if (mem.eql(u8, machine_name, "ibmxt")) {
        const rom_path = try std.fs.path.join(allocator, &([_][]const u8{ "roms", "machines", "ibmpc", "BIOS_5150_24APR81_U33.BIN" }));
        defer allocator.free(rom_path);
        var machine = try PcMachine.init(allocator, rom_path);
        defer machine.deinit();

        std.debug.warn("Opcode: {0x:0<2}\n", .{machine.memReadByte(0xffff0)});

        machine.memWriteByte(0, 0xff);
        machine.cpu.tick(machine);

        std.debug.warn("Value at 0: {0x:0<2}\n", .{machine.memReadByte(0)});
    }
}
