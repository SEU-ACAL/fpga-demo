#!/usr/bin/env python3
import argparse
import os


def xfer_write(path: str, offset: int, data: bytes) -> None:
    with open(path, "r+b", buffering=0) as f:
        f.seek(offset)
        n = f.write(data)
        if n != len(data):
            raise RuntimeError(f"short write: {n}/{len(data)}")


def xfer_read(path: str, offset: int, size: int) -> bytes:
    with open(path, "rb", buffering=0) as f:
        f.seek(offset)
        data = f.read(size)
        if len(data) != size:
            raise RuntimeError(f"short read: {len(data)}/{size}")
        return data


def main() -> int:
    p = argparse.ArgumentParser(description="QDMA MM H2C/C2H DMA test")
    p.add_argument("--h2c", required=True,
                    help="H2C device (e.g., /dev/qdma21001-MM-0)")
    p.add_argument("--c2h", required=True,
                    help="C2H device (e.g., /dev/qdma21001-MM-1)")
    p.add_argument("--offset", type=lambda x: int(x, 0), default=0)
    p.add_argument("--size", type=int, default=4096,
                    help="transfer size in bytes")
    args = p.parse_args()

    if args.size <= 0:
        raise RuntimeError("size must be > 0")
    if args.offset < 0:
        raise RuntimeError("offset must be >= 0")

    pattern = os.urandom(args.size)

    print(f"[test] write {args.size} bytes @ 0x{args.offset:x} via {args.h2c}")
    xfer_write(args.h2c, args.offset, pattern)

    print(f"[test] read  {args.size} bytes @ 0x{args.offset:x} via {args.c2h}")
    got = xfer_read(args.c2h, args.offset, args.size)

    if got != pattern:
        for i, (a, b) in enumerate(zip(pattern, got)):
            if a != b:
                print(f"[test] mismatch at byte {i}: "
                      f"expect=0x{a:02x} got=0x{b:02x}")
                break
        raise RuntimeError("data compare failed")

    print(f"[test] PASS: {args.size} bytes verified")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"[test] FAIL: {e}")
        raise SystemExit(1)
