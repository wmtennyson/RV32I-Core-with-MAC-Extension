# RISC-V Custom DSP Extensions

### Designing RISC-V Extensions for Artificial Neural Networks
- **Citation**: Designing RISC-V Instruction Set Extensions for Artificial Neural Networks: An LLVM Compiler-Driven Perspective — K.K. Balasubramanian et al., IEEE Access, 2024. 
- **Description**:
    Designing RISC-V Instruction Set Extensions for Artificial Neural Networks: An LLVM Compiler-Driven Perspective
AI Outline by Scholar PDF Reader
#### Abstract
  - Describes an approach to designing custom instruction set extensions for a RISC-V processor to improve performance in AI edge applications.
  - Presents the key findings obtained by profiling a set of known quantized ANNs.
  - Highlights that the introduced custom instruction extensions enable a performance speedup up to 13x compared to RV32I, 5x compared to RV32IM, with a maximum code size reduction of 11.7%.
#### I. Introduction
  - Presents an overview of the advantages and disadvantages of cloud-based and Edge-AI implementations of AI algorithms.
  - Describes the benefits of using custom instruction set extensions in a RISC-V processor for running AI algorithms on edge devices. 
  - Introduces the methodology used to design a custom instruction set extension for a RISC-V processor by analyzing the compiled code in the context of edge AI applications.
  - Briefly mentions the RISC-V ISA and ANNs that have been used in this paper.
#### II. Motivation and Background
  - Describes the motivation for designing custom instruction set extensions to improve processor performance.
  - Presents the advantages of RISC-V for implementing such custom extensions.
  - Briefly mentions the main features of the RV32I ISA.
#### III. LLVM
  - Provides an overview of the LLVM compiler infrastructure, including its modular structure, its three-stage pipeline (Frontend, Intermediate Representation, and Backend), and its applications in AI frameworks.
  - Mentions MLIR and Glow as examples of AI frameworks that leverage LLVM.
#### IV. ANN Case Study With Glow
  - Describes the integrated Glow–LLVM software pipeline.
  - Mentions the perceptron, RESNET18, VGG11, and LENET5 ANNs as the example models used in the case study.
  - Highlights that instruction micro-fusion can be used as an optimization strategy.
  - Presents the three custom instructions, LWM, LWA, and LWS, devised to reduce the overall number of instructions and clock cycles.
#### V. LLVM Backend Instruction Mapping
  - Provides a step-by-step discussion of the modifications applied to the LLVM toolchain to support the addition of new instructions.
  - Discusses the static compiler invocation in LLVM.
  - Describes the machine-dependent Selection DAG and how instruction folding can be achieved within the LLVM backend.
#### VI. Validation and Benchmarks
  - Presents the code density and performance benchmark results obtained from the inclusion of the custom instructions in the RISC-V processor.
  - Highlights the performance speedup of the extended processor compared to RV32I and RV32IM.
  - Briefly discusses the code density results compared to X86 and ARM architectures.
#### VII. Discussion and Conclusion
  - Discusses the benefits of using LLVM and RISC-V for optimizing AI workloads in edge computing.
  - Highlights the limitations of the proposed approach.
  - Presents the key findings of the work and proposes future research directions.



    

