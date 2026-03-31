# Senior Project — 2025

A 5-stage pipelined RV32I processor designed in SystemVerilog, targeting DSP applications. The core runs on a Digilent Arty A7 FPGA with a UART bootloader for loading and executing compiled C programs over serial.

MAC (multiply-accumulate) extensions for DSP workloads are planned.

## Architecture

- **ISA**: RV32I (RISC-V 32-bit integer base)
- **Pipeline**: 5-stage (Fetch, Decode, Execute, Memory, Writeback)
- **Branch resolution**: Decode stage with forwarding from EX, MEM, and WB
- **Hazard handling**: Stall-based (load-use, branch-after-load, branch-after-jump)
- **Data forwarding**: Full forwarding unit covering ALU-to-ALU, MEM-to-ALU, and branch operand paths
- **Memory**: Dual-port Block RAM (64 KB executable RAM + 8 KB boot ROM)
- **Clock**: 50 MHz via PLL (Clocking Wizard from 100 MHz board oscillator)
- **Peripherals**: UART TX/RX (115200 baud, memory-mapped)
- **Target board**: Digilent Arty A7-100T (Xilinx xc7a100tcsg324-1)

## Memory Map

| Address        | Region       | Description                          |
|----------------|-------------|--------------------------------------|
| `0x0000_0000`  | Boot ROM     | Bootloader firmware (read-only)      |
| `0x2000_0000`  | RAM          | Application code + data (read/write) |
| `0x4000_0000`  | UART Data    | Write = TX byte, Read = RX byte     |
| `0x4000_0004`  | UART Status  | bit 0 = rx_valid, bit 1 = tx_ready  |

## Getting Started

### Prerequisites

**FPGA toolchain:**
- [AMD/Xilinx Vivado](https://www.xilinx.com/products/design-tools/vivado.html) 2024.x or 2025.x
- Digilent Arty A7 board + USB cable

**Program upload:**
- Python 3.10+
- pyserial: `pip install pyserial`

**Rebuilding firmware (optional):**
- RISC-V GCC toolchain (`riscv-none-elf-gcc`). Pre-built binaries are included so this is only needed if you modify the bootloader or app source.

### Build and Program

1. Open the Vivado project or create a new one targeting your Arty A7 part.
2. Add all files under `sources_1/` as design sources.
3. Add `bootloader.mem` as a memory file.
4. Generate the Clocking Wizard IP (`clk_wiz_0`): 100 MHz in, 50 MHz out, active-low reset, locked output.
5. Add `top_fpga_template.xdc` as constraints.
6. Run **Synthesis → Implementation → Generate Bitstream → Program Device**.

### Upload and Run an Application

1. Note your COM port in Device Manager.
2. Close Vivado's Hardware Manager.
3. Run:
   ```
   python tools/send_and_monitor.py COM4 sw/app/app.bin
   ```
4. Expected output:
   ```
   BOOT
   Send: <decimal_size><space><raw_binary>
   LOAD
   JUMP
   APP OK
   ```

See [HOW_TO_GUIDE.md](HOW_TO_GUIDE.md) for detailed setup instructions, troubleshooting, and how to write your own applications.

## Roadmap

- [x] RV32I base integer ISA
- [x] 5-stage pipeline with forwarding and hazard detection
- [x] UART bootloader for runtime program loading
- [x] FPGA deployment on Arty A7 at 50 MHz
- [ ] MAC (multiply-accumulate) instruction extensions for DSP
- [ ] DSP application demo

## Attributions
This starter package was developed specifically for this RV32I project and is not a verbatim copy of any external repository.

The UART upload protocol and host-side binary transmission flow were inspired by the RudolV project by bobbl, which outlines a simple UART bootloader process that sends the image length followed by the binary payload.

The bare-metal startup code and linker layout draw inspiration from the RISC-V Scratchpad examples by five-embeddev, particularly their minimal startup and linker organization.

The approach of keeping the first downloadable application extremely small was informed by minimal bare-metal examples such as krakenlake/riscv-hello-uart.

All files have been simplified and rewritten to align with a specific memory map, a custom Verilog core interface, and a raw binary loader workflow.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
