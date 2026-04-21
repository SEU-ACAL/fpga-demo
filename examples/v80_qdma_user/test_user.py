#!/usr/bin/env python3
import argparse
import mmap
import os
import struct


def mmio_write32(mm: mmap.mmap, offset: int, value: int) -> None:
  mm.seek(offset)
  mm.write(struct.pack("<I", value & 0xFFFFFFFF))


def mmio_read32(mm: mmap.mmap, offset: int) -> int:
  mm.seek(offset)
  return struct.unpack("<I", mm.read(4))[0]


def main() -> int:
  p = argparse.ArgumentParser(description="QDMA user BAR MMIO test")
  p.add_argument("--dev", required=True, help="qdma user device")
  p.add_argument("--offset", type=lambda x: int(x, 0), default=0)
  p.add_argument("--count", type=int, default=64, help="number of 32-bit words")
  args = p.parse_args()

  if args.count <= 0:
    raise RuntimeError("count must be > 0")
  if args.offset < 0:
    raise RuntimeError("offset must be >= 0")
  if args.offset % 4 != 0:
    raise RuntimeError("offset must be 4-byte aligned")
  if not os.path.exists(args.dev):
    raise RuntimeError(f"device not found: {args.dev}")

  fd = os.open(args.dev, os.O_RDWR | os.O_SYNC)
  try:
    size = args.count * 4
    mm = mmap.mmap(fd, size, offset=args.offset)
    try:
      errors = 0
      for i in range(args.count):
        addr = i * 4
        pattern = 0xA5A50000 | i
        mmio_write32(mm, addr, pattern)
        got = mmio_read32(mm, addr)
        if got != pattern:
          print(
            f"[test] FAIL @ 0x{args.offset + addr:x}: "
            f"wrote 0x{pattern:08x} read 0x{got:08x}"
          )
          errors += 1

      if errors:
        raise RuntimeError(f"compare mismatch: {errors}/{args.count}")
    finally:
      mm.close()
  finally:
    os.close(fd)

  print(f"[test] PASS: {args.count} words @ 0x{args.offset:x}")
  return 0


if __name__ == "__main__":
  try:
    raise SystemExit(main())
  except Exception as e:
    print(f"[test] FAIL: {e}")
    raise SystemExit(1)
