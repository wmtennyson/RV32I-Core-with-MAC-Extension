#!/usr/bin/env python3
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: bin_to_mem.py <input.bin> <output.mem>")
        return 1

    inp = Path(sys.argv[1]).read_bytes()
    out_lines = []

    for i in range(0, len(inp), 4):
        chunk = inp[i:i+4]
        if len(chunk) < 4:
            chunk = chunk + b"\x00" * (4 - len(chunk))
        word = int.from_bytes(chunk, byteorder="little", signed=False)
        out_lines.append(f"{word:08x}")

    Path(sys.argv[2]).write_text("\n".join(out_lines) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
