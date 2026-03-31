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

## Project Structure

```
sources_1/
├── RV32I_Core.sv              Top-level CPU module
├── IF/
│   └── fetch_unit.sv          Instruction fetch + PC management
├── ID/
│   ├── Decode_Unit.sv         Decode, register file, branch resolution
│   ├── Control_Unit.sv        Opcode decoder
│   ├── Branch_Unit.sv         Branch/jump comparator and target calc
│   ├── Forwarding_Unit.sv     Data hazard forwarding logic
│   ├── Hazard_Unit.sv         Stall detection
│   ├── ImmGen.sv              Immediate generator (I/S/B/U/J)
│   └── regfile.sv             32x32 register file
├── EX/
│   ├── Execute_Unit.sv        ALU + operand selection + forwarding muxes
│   ├── EXE_ALU.sv             Arithmetic/logic unit
│   └── EXE_Control.sv         ALU control decoder
├── MEM/
│   └── mem_unit.sv            Load/store unit with byte/half/word support
├── WB/
│   └── WriteBack_Unit.sv      Writeback mux (ALU / memory / PC+4)
├── Interstage/
│   ├── if_id_reg.sv           IF/ID pipeline register
│   ├── id_ex_reg.sv           ID/EX pipeline register
│   ├── ex_mem_reg.sv          EX/MEM pipeline register
│   └── mem_wb_reg.sv          MEM/WB pipeline register
├── imports/
│   ├── rtl/
│   │   ├── top_fpga.sv        SoC top level (CPU + memory + UART + PLL)
│   │   ├── simple_uart_rx.sv  UART receiver
│   │   └── simple_uart_tx.sv  UART transmitter
│   └── bootloader/
│       └── bootloader.mem     Bootloader ROM image
├── new/
│   └── Def.vh                 Shared macro definitions (ALU ops, opcodes)
sim_1/                         Testbenches
constrs_1/                     XDC pin constraints for Arty A7
```

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

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
