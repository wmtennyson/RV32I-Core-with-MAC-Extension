# CPU Architecture Design Document

This document describes the architecture, components, and design decisions for the 2025 Senior Project CPU. Please feel free to add to this Document.

## 1. Overview

The Goal of this Senior Design Project is to create a RISC-V CPU capable of accelerating Dot Product / Convolutional computations. In other words, the goal is to build a CPU that accelerates dot-product / Convolutional style workloads, which dominate DSP, image processing, and ML inference. The base of the CPU will be designed according to the RISC-V ratified specifications; later, the design will be optimized to include a Multiply-Accumulate function in the Arithmetic Control Unit. 

## 2. Block Diagram

*Add or link a block diagram image of your CPU architecture.*

## 3. Key Components

- **ALU:** Arithmetic Logic Unit
  - MAC (Multiply-Accumulate Unit for Convolution)
- **Registers:** General-purpose and special registers
- **Register File**
- **Program Counter**
- **Instruction Memory**
- **Data Memory**
- **Memory Interface:** How CPU connects to RAM/ROM
- **Control Unit**

## 4. Design Decisions

*Document major decisions here (e.g., pipelining, instruction width, etc.).*

## 5. Testing and Verification

*Describe your testbench strategy, simulation approach, and verification plan.*
