# Minimal RV32I UART Loader — How-To Guide

A lightweight UART bootloader and upload toolchain for loading and running compiled C programs on a custom RV32I pipelined processor implemented on an FPGA (Digilent Arty A7).

---

## Directory Structure

```
minimal_rv32i_loader/
├── sw/
│   ├── bootloader/          Bootloader firmware (runs from boot ROM)
│   │   ├── boot_crt0.S       Startup assembly (sets stack, calls boot_main)
│   │   ├── bootloader.c      Bootloader C source (UART receive loop)
│   │   ├── bootloader.ld     Linker script (maps to 0x00000000)
│   │   ├── bootloader.mem    Pre-built ROM image for $readmemh
│   │   ├── bootloader.bin    Raw binary
│   │   ├── bootloader.elf    ELF with debug symbols
│   │   └── Makefile
│   └── app/                 Example application (loaded into RAM at runtime)
│       ├── crt0.S             Startup assembly (sets stack, clears .bss)
│       ├── main.c             Test app: prints "APP OK", hits EBREAK
│       ├── app.ld             Linker script (maps to 0x20000000)
│       ├── app.bin            Pre-built binary ready to upload
│       ├── app.elf            ELF with debug symbols
│       └── Makefile
├── tools/
│   ├── send_bin.py            Sends a binary to the FPGA over UART
│   ├── send_and_monitor.py    Sends binary + stays open as serial monitor
│   └── bin_to_mem.py          Converts .bin to Verilog $readmemh format
├── top_fpga_template.xdc      Pin constraints for Arty A7
├── README.md
└── ATTRIBUTION.md
```

---

## Memory Map

| Address       | Region          | Description                              |
|---------------|-----------------|------------------------------------------|
| 0x00000000    | Boot ROM        | Bootloader code + string constants       |
| 0x20000000    | Executable RAM  | Application loaded here via UART         |
| 0x40000000    | UART Data       | Write = TX byte, Read = RX byte          |
| 0x40000004    | UART Status     | bit 0 = rx_valid, bit 1 = tx_ready       |

---

## Dependencies

### For FPGA synthesis and programming
- **AMD/Xilinx Vivado** 2024.x or 2025.x (Design Suite or ML Edition)
- **Digilent Arty A7** board (A7-35T or A7-100T)
- USB cable (micro-USB) for JTAG programming and UART communication

### For uploading programs to the FPGA
- **Python 3.10+**
- **pyserial** — install with: `pip install pyserial`

### For rebuilding the bootloader or app from source (optional)
- **RISC-V GCC toolchain** — the Makefiles expect `riscv-none-elf-gcc` on your PATH. Install options:
  - **xPack**: https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases
  - **SiFive Freedom Tools**: https://github.com/sifive/freedom-tools/releases
  - **Linux**: `sudo apt install gcc-riscv64-unknown-elf` (then set `CROSS=riscv64-unknown-elf`)
- **GNU Make**
- Pre-built binaries (`bootloader.mem`, `app.bin`) are included, so this step is only needed if you modify the C source.

---

## Quick Start (Step by Step)

### 1. Set up the Vivado project

1. Create a new Vivado project targeting your Arty A7 part (`xc7a35tcsg324-1` or `xc7a100tcsg324-1`).
2. Add your RV32I core RTL sources and `top_fpga.sv` as design sources.
3. Add `bootloader.mem` from `sw/bootloader/` as a design source (Memory File).
4. Add `top_fpga_template.xdc` as a constraints file.
5. Generate the Clocking Wizard IP (`clk_wiz_0`): 100 MHz input, 50 MHz output, active-low reset, locked output enabled.

### 2. Configure top_fpga.sv

Ensure `top_fpga.sv` has:
- `CLK_HZ = 50_000_000` (matching the PLL output)
- `$readmemh` pointing to the correct absolute path for `bootloader.mem`
- The boot ROM accessible from both instruction and data memory ports (the bootloader stores string constants in code space)
- UART TX/RX pins matching your board (Arty A7: TX = D10, RX = A9)

### 3. Build the bitstream

In Vivado: **Synthesis → Implementation → Generate Bitstream**

Verify:
- Timing passes (positive WNS)
- No DRC errors
- `bootloader.mem` loaded successfully (check synthesis log for "read successfully")

### 4. Program the FPGA

1. Connect the Arty A7 via USB.
2. In Vivado: **Open Hardware Manager → Auto Connect → Program Device**.
3. Select the generated `.bit` file and click **Program**.
4. Verify: LED[3] (LD7) should be on (UART TX ready). The board's green "DONE" LED confirms the FPGA is configured.

### 5. Verify the bootloader

1. Note your COM port number in **Device Manager → Ports (COM & LPT)**.
2. Open a serial terminal (PuTTY, Tera Term, or similar):
   - Port: your COM port (e.g., COM4)
   - Baud: 115200
   - Data bits: 8, Stop bits: 1, Parity: None, Flow control: None
   - Connection type: **Serial** (not SSH)
3. Press the **reset button** on the Arty.
4. You should see:
   ```
   BOOT
   Send: <decimal_size><space><raw_binary>
   ```

### 6. Upload and run the test application

1. **Close** your serial terminal (the COM port can only be used by one program at a time).
2. Open a terminal/PowerShell and navigate to the `minimal_rv32i_loader` directory.
3. Run:
   ```
   python tools/send_and_monitor.py COM4 sw/app/app.bin
   ```
   (Replace `COM4` with your actual COM port.)
4. Expected output:
   ```
   BOOT
   Send: <decimal_size><space><raw_binary>
   [Sending header: 180 bytes...]
   LOAD
   [Sending 180 bytes of binary...]
   [Upload complete, waiting for response...]
   JUMP
   APP OK
   [Done]
   ```
5. LED[0] (LD4) turns on, confirming the app executed EBREAK (`done_o` asserted).

---

## Upload Protocol

The bootloader expects this format over UART at 115200 baud (8N1):

```
<decimal_byte_count><space><raw_binary_bytes>
```

For example, to send a 180-byte binary, the host transmits:
```
180 <180 raw bytes>
```

The bootloader:
1. Parses the ASCII decimal size
2. Prints `LOAD`
3. Receives exactly that many bytes into RAM at `0x20000000`
4. Prints `JUMP`
5. Jumps to `0x20000000` to execute the application
6. If the application returns, prints `RET` and loops back to wait for another upload

**Important**: The FPGA UART has no receive FIFO (single-byte holding register). The upload script must wait for the `LOAD` response before sending binary data, and should pace transmission in small chunks to avoid byte loss.

---

## Writing Your Own Application

1. Edit `sw/app/main.c` with your code. You have access to:
   - UART TX: write a byte to `0x40000000` (poll `0x40000004` bit 1 for ready)
   - UART RX: read a byte from `0x40000000` (poll `0x40000004` bit 0 for valid)
   - RAM: full read/write access from `0x20000000`

2. Rebuild (requires RISC-V toolchain):
   ```
   cd sw/app
   make clean && make
   ```

3. Upload the new binary:
   ```
   python tools/send_and_monitor.py COM4 sw/app/app.bin
   ```

To signal completion, execute `EBREAK` (opcode `0x00100073`) which asserts `done_o` on the core. To signal an error, execute `ECALL` (opcode `0x00000073`) which asserts `trap_o`.

---

## Rebuilding the Bootloader (optional)

Only needed if you change the memory map or bootloader behavior.

```
cd sw/bootloader
make clean && make
```

This produces `bootloader.mem`. Copy it into your Vivado project sources and update the `$readmemh` path in `top_fpga.sv`. You must re-run the full Vivado flow (synthesis through bitstream) for bootloader changes to take effect.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| No `BOOT` message in terminal | Bitstream not programmed, or reset issue | Re-program the board; press reset while terminal is open |
| `BOOT` appears but upload hangs | Script sends binary before bootloader is ready | Use `send_and_monitor.py` which waits for `LOAD` before sending |
| `LOAD` appears but no `JUMP` | Bytes lost during transfer (no FIFO) | Use the paced upload script; reduce chunk size if needed |
| Garbled text in terminal | Wrong baud rate or pin assignment | Verify 115200 baud, check XDC pin mapping matches board |
| PuTTY won't open COM port | Port locked by another program | Close Vivado Hardware Manager and any other serial connections |
| LED[1] on after upload | App hit ECALL (trap) | Check application code for errors; may indicate illegal instruction |
