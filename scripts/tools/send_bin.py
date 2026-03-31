#!/usr/bin/env python3
import sys
import time
from pathlib import Path

import serial


def main() -> int:
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print("usage: send_and_monitor.py <serial_port> <app.bin> [baud]")
        return 1

    port = sys.argv[1]
    image = Path(sys.argv[2]).read_bytes()
    baud = int(sys.argv[3]) if len(sys.argv) == 4 else 115200

    header = str(len(image)).encode("ascii") + b" "

    with serial.Serial(port, baudrate=baud, timeout=2) as ser:
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        time.sleep(0.05)

        # Read bootloader banner (BOOT + Send: ...)
        banner = ser.read_until(b"\n", 256)
        banner += ser.read_until(b"\n", 256)
        if banner:
            print(banner.decode(errors="replace"), end="")

        # Send the size header only
        print(f"[Sending header: {len(image)} bytes...]")
        ser.write(header)
        ser.flush()

        # Wait for bootloader to print "LOAD\n" before sending binary
        # This ensures the bootloader is done printing and ready to receive
        load_resp = ser.read_until(b"\n", 64)
        if load_resp:
            print(load_resp.decode(errors="replace"), end="")

        if b"LOAD" not in load_resp:
            print("[WARNING: Did not see LOAD response, sending anyway]")

        # Small delay to let bootloader enter the receive loop
        time.sleep(0.01)

        # NOW send the binary payload in small chunks with pacing
        # to avoid overwhelming the single-byte UART holding register
        print(f"[Sending {len(image)} bytes of binary...]")
        chunk_size = 16
        for i in range(0, len(image), chunk_size):
            chunk = image[i:i+chunk_size]
            ser.write(chunk)
            ser.flush()
            # Pace: 16 bytes at 115200 = ~1.4ms, give a tiny margin
            time.sleep(0.002)

        print("[Upload complete, waiting for response...]")

        # Read JUMP + app output
        time.sleep(0.5)
        try:
            while True:
                data = ser.read(256)
                if data:
                    print(data.decode(errors="replace"), end="")
                else:
                    break
        except KeyboardInterrupt:
            pass

        print("\n[Done]")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
