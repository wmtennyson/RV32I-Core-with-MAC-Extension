#!/usr/bin/env python3
import sys
import time
from pathlib import Path

import serial


def main() -> int:
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print("usage: send_bin.py <serial_port> <app.bin> [baud]")
        return 1

    port = sys.argv[1]
    image = Path(sys.argv[2]).read_bytes()
    baud = int(sys.argv[3]) if len(sys.argv) == 4 else 115200

    header = str(len(image)).encode("ascii") + b" "

    with serial.Serial(port, baudrate=baud, timeout=0.2) as ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.1)
        ser.write(header)
        ser.write(image)
        ser.flush()
        time.sleep(0.2)
        try:
            response = ser.read_all()
            if response:
                print(response.decode(errors="replace"), end="")
        except Exception:
            pass

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
