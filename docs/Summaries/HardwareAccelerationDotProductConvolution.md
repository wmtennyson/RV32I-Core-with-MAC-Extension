# Hardware Acceleration of Dot Product / Convolution

### In-Datacenter Performance Analysis of a Tensor Processing Unit

- **Citation:** Jouppi, Norman P., et al. "In-datacenter performance analysis of a tensor processing unit." Proceedings of the 44th annual international symposium on computer architecture. 2017.
- **Description:** This paper dissects Google’s first TPU, a domain-specific inference accelerator whose center is a 256×256 systolic array of 8-bit MACs backed by a 24 MiB on-chip buffer and dedicated weight DRAM. By quantizing models and pushing massive int8 matrix math through a deterministic pipeline, the TPU meets strict p99 latency targets typical of user-facing services. In head-to-head production workloads (MLPs, LSTMs, CNNs), a TPU die is about 14–15× faster than a CPU die and ~13× faster than a K80 GPU die, with performance per watt that is 17–34× (total) or 41–83× (incremental) better than CPU and 25–29× better than GPU. Roofline analysis shows most MLP/LSTM inference is limited by memory bandwidth while CNNs are compute-bound; thus, memory bandwidth—and not merely clock or array size—is the key lever. Indeed, moving the TPU’s weight memory to GDDR5 would triple delivered TOPS and push perf/W to ~70× GPU and ~200× CPU. The broader message is that packing many small MACs and orchestrating data movement carefully beats general-purpose tricks for latency-bound inference: systolic arrays, big local SRAMs, and predictable execution deliver large, real-world speedups with excellent energy efficiency.


### FPGA-Based Acceleration for Convolutional Neural Networks: A Comprehensive Review

- **Citation:** Jiang, Junye, et al. "FPGA-based Acceleration for Convolutional Neural Networks: A Comprehensive Review." arXiv preprint arXiv:2505.13461 (2025).
- **Description:** This review explains why FPGAs are a sweet spot for CNN inference: you can tailor MAC-heavy pipelines and on-chip data movement to convolution loops, yielding low latency and solid energy efficiency. It provides a clear evaluation playbook—accuracy/F1 on the model side and latency, throughput, peak, and compute efficiency on the hardware side—and catalogs both algorithmic reductions (pruning, quantization, lightweight nets, Winograd/FFT) and hardware tactics (tiling, unrolling, 4D parallelism: Pf/Pc/Pv/Pk). Real designs mix these dimensions, and the most efficient systems use dynamic parallelism to keep compute units busy across layers. Toolflows and design-space exploration (with modeling) help map entire networks to boards under resource and bandwidth limits. The conclusion points to heterogeneous chips, AI-driven DSE, and adaptive accelerators as the next steps for even more efficient CNN hardware.

#### Abstract
- CNNs dominate many AI tasks but are compute-hungry; FPGAs are attractive because they’re reconfigurable, parallel, and energy-efficient.
- The paper reviews FPGA CNN accelerators, proposes a performance evaluation framework, and surveys key optimization strategies (parallel/dataflow/co-design).
- It compares architectures by latency, throughput, compute efficiency, power, and resource use, and lays out future challenges/opportunities.
#### Introduction
- CNNs power vision tasks (classification, detection, segmentation) but push device limits, especially at the edge (phones, drones).
- CPUs/GPUs/ASICs have limits for real-time, low-power inference; FPGAs offer customization, parallelism, and energy efficiency for tailored accelerators.
#### CNN Acceleration Platoforms (CPU / GPU / ASIC / FPGA)
- Side-by-side table contrasts compute performance, energy, flexibility, dev time, cost, and scalability across platforms.
- Key takeaway: FPGAs balance customization + flexibility, enabling fine-grained parallelism and reduced latency for real-time tasks; sparsity can further boost throughput.
- Compared with ASICs (fixed, efficient) and GPUs (throughput-oriented), FPGAs are reprogrammable and power-efficient for edge inference.
#### Evaluation Framework
##### Model Metrics
- Accuracy, Precision, Recall; F1 balances precision–recall trade-offs.
##### Hardware Metrics
- Latency: sum of off-chip transfer, on-chip transfer, and compute; reduce via bandwidth, better storage/reuse, and more parallelism.
- Throughput = Workloads / Latency; distinguish from peak.
- Peak throughput (theoretical) = 2 × #MACs × f; use as the upper bound.
- Compute (MAC) efficiency = Throughput / (2 × #MACs × f); device-independent indicator of how well the design uses its MACs.
#### CNN Acceleration Methods
##### Pruning & Quantization
- Pruning removes unimportant weights/channels; quantization lowers bit-width to pack more work per DSP and cut power. (Section header + survey scope)
##### Model-Structure Compression
- Lightweight nets, knowledge distillation, and layer fusion (e.g., fold BatchNorm) lower compute and memory traffic. (Section outline)
##### Computation Reduction
- FFT and Winograd reduce multiplications (large vs small kernels respectively); both are classic ways to shrink conv cost.
#### Hardware Approaches
##### Data Blocking & Parallel Computing
- Loop tiling improves locality and reduces memory bandwidth; combine with pipelining/parallelism in FPGA fabrics.
- Loop unrolling merges iterations to raise parallelism; degree must match resources/bandwidth to avoid congestion.
##### Four Dimensions of Parallelism
- Filter (Pf), Channel (Pc), Pixel/Spatial (Pv), Kernel (Pk); designers mix these to fit layers and memory patterns.
- Pv and Pk have buffering/size constraints; Pc/Pf are often more flexible for large throughput.
##### Parallel Strategies in Practice
- Examples show different mixes (e.g., Pk+Pv+Pf or Pv+Pf) with reported GOP/s and per-DSP efficiency; mismatch to layer shapes can underutilize resources.
- Dynamic parallelism adapts Pf/Pc/Pv/Pk per layer to keep PEs busy; reported 72–98% compute efficiency on Stratix 10.
##### Other Optimizations
- Input reshaping (e.g., im2col to GEMM) and DSP optimization (packing low-precision MACs) frequently used. (Section outline)
#### Algorithm-Hardware Co-Design
##### Toolflows
- Frameworks (e.g., fpgaConvNet, Angel-Eye, Snowflake, f-CNNx) automate mapping CNNs to FPGAs, using buffering, double-buffer overlaps, and multi-objective cost functions to hit latency/throughput targets.
##### Design Space Exploration (DSE)
- Brute force, simulated annealing, genetic and other methods search tiling/unrolling/parallelism under resource and bandwidth limits. (Section outline)
##### Performance & Resource Modeling
- Analytic and learned models predict latency/power/resources to speed up DSE; the paper visualizes power vs throughput vs latency trade-offs.
#### Discussion & Conclusion
- Architectural levers (deep pipelining, parallelism, reconfigurability) drive compute and energy efficiency; pick low-power devices and prune non-essential logic.
- Future directions: heterogeneous SoCs (CPU/GPU/FPGA/ASIC), AI-driven DSE, and scalable/adaptive accelerators that reconfigure per layer/model.
- Overall message: to hit low-cost, low-latency, high-performance inference, emphasize compute efficiency and dynamic parallelism; DSE becomes increasingly critical.
  
