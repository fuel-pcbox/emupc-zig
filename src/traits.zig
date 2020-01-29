const std = @import("std");

pub fn implementsMachine(comptime t: type) bool {
    const memReadByteFn = fn (t, u20) u8;
    const memWriteByteFn = fn (t, u20, u8) void;
    if (std.meta.trait.hasFn("memReadByte")(t) and
        @TypeOf(t.memReadByte) == memReadByteFn and
        std.meta.trait.hasFn("memWriteByte")(t) and
        @TypeOf(t.memWriteByte) == memWriteByteFn)
    {
        return true;
    } else {
        return false;
    }
}
