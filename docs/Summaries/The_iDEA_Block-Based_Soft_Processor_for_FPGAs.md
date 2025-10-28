**SUMARRY: The iDEA DSP Block-Based Soft Processor FPGAs**

- **Main Idea:** In moderen FPGAs DSP can be used for a wide range of arithemetic functions, offering increased performance while saving resources
- **Device Used:** DSP48E1 Xilinx device support dynamic programmability
- **Extension Used:** DSP Extension Architecture (iDEA)
- Uses a multiplier accumulator
- DSP48E1 composes a preadder, multiplier, and adder/subtracter logic unit(ALU)
- Functions require a like finite impulse-response filters
- FPGAs are often used to implement full systems rather than just accelerators

- Even though a hard porecessor can offer better performance to an equivalent soft processor, they are inflexible and cannot be tailored to suit different applicatoins

- Over time, numerous improvements have been made to speed, frequency, logic functionality, and controllability
- Control singals: Opmode, alumode, inmode
- Table 1: Comparison of Muliplier and DSP Primatives in Xilinx Devices
- Fig.1: Architecture of the DSP48E1 (Block Digram Pg.5)

- Explains how different instuction are excuted on the DSP48E1

- iDEA is a scalar processor based on a load-store RISC architecture
- Main advantage of using RISC is uniform instruction set that leads to more straightforward decode logic and simpler hardware
- iDEA executes 32-bit instructions on 32-bit data
- Only 1 DSP48E1 is used
- More in-depth Block Diagram Fig.6 iDEA processor block diagram (Pg. 9)

-Table V: IDEA Instruction Set (Pg. 12)

- Multiplication and shift to be efficiently performed

