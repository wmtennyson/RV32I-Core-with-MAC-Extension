**SUMMARY: EXTREM-EDGE ARTICLE**

**GENERAL SUMMARY**
- **Main Idea:** EXTREM-EDGE is a **hardware/software co-design methodology** for creating flexible, scalable, and energy-efficient AI processors for edge computing.
- **Problem Solved:** It addresses the issue that typical AI accelerators are rigid, expensive, and quickly become obsolete.
- **Solution (2-Part):**
    - 1. **Hardware Extension:** Adds custom **AI Functional Units (AFUs)** directly into the CPU's execution pipeline. This is a "tightly-coupled" approach, distinct from a separate coprocessor.
    - 2. **Software Extension:** Adds new **custom instructions** to the RISC-V ISA (in the `CUSTOM-2` opcode space) to directly control the new AFU hardware.
- **Design Methodology:**
    - The processor is described in a high-level language called **nML**.
    - This nML file is fed into the **Synopsys ASIP Designer** tool.
    - The tool **automatically generates** both the synthesizable Verilog (the hardware) and the matching software toolchain (compiler, assembler, simulator).
- **Results:**
    - **1.75x** speedup on a GEMV kernel (using a MAC AFU).
    - **1.41x** cycle reduction for a full ResNet-8 ML model.

**RELEVANCE TO SENIOR PROJECT (CPU w/ MAC Unit)**
- **Core Architecture:** Our "custom MAC unit" is exactly what the paper calls an **AFU (AI Functional Unit)**.
- **Pipeline Integration:** The paper's strategy of placing the AFU *in-pipeline* (tightly coupled) is our exact design goal. This affirms our approach over using an external coprocessor.
- **ISA Co-Design:** This paper confirms that just building the MAC hardware isn't enough. We **must** also implement the software side:
    - Define new custom instructions (e.g., `mac.op`, `mac.simd.op`) for our MAC unit.
    - Use the standard `CUSTOM-2` opcode space (`0x5B`) to be standards-compliant.
- **Toolchain Methodology:** The paper highlights the need to update the toolchain (assembler, compiler) to recognize the new instructions. Their use of ASIP Designer is the automated, professional way to do this. For our project, this means we must, at a minimum, modify our assembler.
- **Benchmarking Strategy:** The paper gives us a clear validation plan:
    - 1. **Kernel Benchmark:** Test a core operation like **GEMV (General Matrix-Vector multiplication)**.
    - 2. **Application Benchmark:** Test a real-world model like **ResNet-8** from the **MLPerf Tiny** suite.
