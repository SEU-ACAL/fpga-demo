#!/usr/bin/env python3
"""Test XDMA User BAR (AXI-Lite / MMIO) read/write via /dev/xdmaN_user."""
import argparse
import mmap
import os
import struct
import sys


def mmio_write32(mm: mmap.mmap, offset: int, value: int) -> None:
    mm.seek(offset)
    mm.write(struct.pack("<I", value & 0xFFFFFFFF))


def mmio_read32(mm: mmap.mmap, offset: int) -> int:
    mm.seek(offset)
    return struct.unpack("<I", mm.read(4))[0]


def main() -> int:
    p = argparse.ArgumentParser(description="XDMA User BAR MMIO test")
    p.add_argument("--dev", default="/dev/xdma0_user", help="xdma user device")
    p.add_argument("--offset", type=lambda x: int(x, 0), default=0)
    p.add_argument("--count", type=int, default=64, help="number of 32-bit words to test")
    args = p.parse_args()

    fd = os.open(args.dev, os.O_RDWR | os.O_SYNC)
    size = args.count * 4
    mm = mmap.mmap(fd, size, offset=args.offset)

    errors = 0
    for i in range(args.count):
        addr = i * 4
        pattern = 0xDEAD0000 | i
        mmio_write32(mm, addr, pattern)
        got = mmio_read32(mm, addr)
        if got != pattern:
            print(f"[test] FAIL @ 0x{args.offset + addr:x}: "
                  f"wrote 0x{pattern:08x} read 0x{got:08x}")
            errors += 1

    mm.close()
    os.close(fd)

    if errors:
        print(f"[test] FAIL: {errors}/{args.count} mismatches")
        return 1

    print(f"[test] PASS: {args.count} words @ 0x{args.offset:x}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"[test] FAIL: {e}")
        raise SystemExit(1)
