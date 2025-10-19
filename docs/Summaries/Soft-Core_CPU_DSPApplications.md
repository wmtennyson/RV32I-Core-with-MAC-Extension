# Soft-Core CPU Design for DSP Applications

### FPGA-Based Image Processing Processor

- **Citation:** IPPro: FPGA-Based Image Processing Processor — Fahad M. Siddiqui et al., IEEE SiPS Workshop 2014; extended in Journal of Signal Processing Systems, 2017. 
- **Description:** 
**Overview**
The paper presents IPPro, a high-performance, scalable soft-core processor designed for image processing applications on FPGAs (Field Programmable Gate Arrays).  It is implemented on an Xilinx Zynq FPGA, operating at 526 MHz, delivering 526 MIPS performance.

**Architecture**
- 16-bit RISC soft-core processor (customizable to 8/16/32 bits).  
- Built using DSP48E1 blocks, Block RAM, and Kintex-7 slices.  
- Uses 1 DSP48, 1 Block RAM, and 330 slice registers per core.  
- Five-stage pipelined design: Fetch, Decode, Execute1, Execute2, Write.  
- Supports SIMD (Single Instruction, Multiple Data) and MIMD parallel computation modes.

**Memory Structure**
- Distributed, fast local memories for instructions, registers, data, and kernel constants.  
- Four addressing modes:  
  1. Register–Register (R–R)  
  2. Register–Data (R–D)  
  3. Register–Kernel (R–K)  
  4. Register–Immediate (R–I)  
- Optimized for efficient image data handling and reduced transfer overheads.

**Instruction Set**
- 53 instructions for arithmetic, logic, and branch control.  
- Includes special instructions for image processing operations such as:
  - Thresholding  
  - Convolution  
  - Morphological filtering  
  - Contrast adjustment

**Performance Enhancements**
- Reduced pipeline stages → lower branch penalty.  
- Custom branch controller for mask-based conditional execution.  
- Optimized for balance between resource usage and speed.

**System Architecture**
*(See Figure 3 in the paper)*  
Multiple IPPro cores are connected into a SIMD-IPPro cluster controlled by an ARM processor.
- ARM Cortex-A9 cores manage control, synchronization, and data streaming.  
- DMA + DDR3 shared memory provides fast data exchange between ARM and FPGA logic.  
- Designed for scalability with shared resources and reduced area utilization.

**Case Study: Traffic Sign Recognition (TSR)**
**Implementation:**  
- Tested on a Zedboard (Xilinx Zynq SoC).  
- IPPro accelerates color filtering and morphological operations—the most computationally intensive stages.  
- Other TSR stages (edge detection, classification, template matching) run on ARM cores.
- Compared to previous FPGA/CPU systems (e.g., MicroBlaze, LEON, Nios II), IPPro achieved the highest throughput, processing HD video at up to 155 fps.

**Conclusions**
- IPPro shows that FPGA soft-core processors can match or surpass handcrafted designs while being programmable and scalable. 
- Achieved 15–33× speedup in image processing tasks with lower design effort.  
- Combines hardware-level acceleration with software-like flexibility.


