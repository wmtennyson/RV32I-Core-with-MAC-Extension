# Hardware Acceleration of Dot Product / Convolution

### In-Datacenter Performance Analysis of a Tensor Processing Unit

- **Citation:** Jouppi, Norman P., et al. "In-datacenter performance analysis of a tensor processing unit." Proceedings of the 44th annual international symposium on computer architecture. 2017.
- **Description:** The paper studies Google’s first-gen Tensor Processing Unit (TPU), a PCIe coprocessor built specifically for neural-network inference. Its heart is a 256×256 systolic array of 8-bit MACs (≈92 TOPS) fed by a large software-managed on-chip buffer and an 8 GiB weight DRAM. The TPU’s deterministic pipeline and local dataflow let it honor strict p99 latency targets that constrain CPUs/GPUs to small batches. On six production DNNs (MLPs, LSTMs, CNNs) covering ~95% of demand, the TPU die delivers around 15× the K80 GPU die’s performance (weighted) and order-of-magnitude better energy efficiency at the server level. Roofline analysis shows MLPs/LSTMs are memory-bound on TPU while CNNs are compute-bound, making memory bandwidth the dominant tuning knob; simply enlarging the MAC array can backfire due to tiling/fragmentation. Using GPU-class GDDR5 would have tripled achieved TOPS and pushed perf/W to ~70× GPU and ~200× CPU. The overarching lesson for hardware acceleration of dot products/convolutions: pack many small int8 MACs, keep data local, orchestrate systolic flow, and design for tail-latency—that combination yields large, real-world gains in both speed and energy.

#### Abstract (key takeaways)
- TPU = a domain-specific ASIC for NN inference (not training), first deployed in 2015.
- Core is a 65,536-MAC, 8-bit matrix-multiply unit (≈92 TOPS peak) with a large on-chip memory managed by software.
- Deterministic, single-threaded execution favors p99 latency targets vs. CPU/GPU features that boost averages but hurt tail latency.
- On real production workloads (MLP, CNN, LSTM), TPU is ~15–30× faster than contemporary CPU/GPU and ~30–80× better in TOPS/Watt; with GDDR5-class memory, ~3× higher TOPS and ~70×/200× perf/W vs. GPU/CPU projected.
#### 1) TPU Origin, Architecture, Implementation, and Software
- Motivation: 2013 projections (voice search, etc.) would double DC compute on CPUs; team built an inference ASIC in 15 months.
- Integration model: TPU is a PCIe coprocessor (closer to an FPU than a GPU); host sends instructions, simplifying HW + deployment.
- Goal: run whole models on-device to reduce host interaction; internal paths are wide (256-byte) for high throughput.
- Block diagram highlights: Matrix Multiply Unit (256×256 MACs), Accumulators (4 MiB), Unified Buffer (24–28 MiB), Weight FIFO streaming from 8 GiB Weight DRAM.
- ISA flavor: a small CISC-like set; five key ops—Read_Host_Memory, Read_Weights, MatrixMultiply/Convolve, Activate (ReLU/sigmoid/pooling), Write_Host_Memory.
- Microarch philosophy: keep the matrix unit busy, overlap non-matrix work, and use systolic execution to cut power-hungry SRAM traffic.
#### 2) Matrix Unit & Dataflow Details
- 256×256 MAC array does 8-bit multiplies; 16-bit products accumulate in 32-bit registers (4 MiB total).
- Supports matrix-multiply and convolution; one 64 KiB weight tile (double-buffered) to hide shift latency. Designed for dense matrices.
- Operates at half/quarter speed when activations/weights are 16-bit (mix or both).
- Systolic wavefront: activations in from left, weights from top; diagonal wavefront updates accumulators—software is functionally unaware but must mind unit latency for performance.
#### 3) Platforms & Workload (what they measured)
- Workload: six production models (2×MLP, 2×LSTM, 2×CNN) covering ~95% of inference demand (e.g., RankBrain, Translate subset, Inception, AlphaGo).
- Benchmarked platforms: Haswell CPU, NVIDIA K80 GPU, TPU, all 2015-era DC configurations with ECC, etc.
#### 4) Performance Analysis (Rooflines & Latency Reality)
- TPU roofline “ridge” at ~1350 MACs/byte of weight traffic: MLP/LSTM are memory-bound, CNNs compute-bound on TPU.
- CPUs/GPUs sit further below their peaks because p99 latency caps batch size, prioritizing latency over throughput.
- Example: MLP0 p99 ≤ 7 ms; at that cap, Haswell/K80 use ~42%/37% of their achievable throughput, TPU ~80%.
- Weighted means (actual mix): TPU die ~15.3× GPU die perf (both include host overhead).
#### 5) Cost-Performance & Performance/Watt (TCO Proxy)
- They use performance/Watt as a proxy for TCO (publishable), comparing whole servers.
- Results: TPU server 17–34× CPU (total), 41–83× CPU (incremental); ~25–29× GPU (incremental).
#### 6) Energy Proportionality
- Measured power vs. utilization (0–100%) across platforms; the TPU has low absolute power but imperfect proportionality—still, CPU+4×TPU yields large speedups at modest power.
#### 7) Alternative TPU Designs (what matters most)
- Performance model agrees with HW counters (≤~10% error); then sweep parameters. Biggest lever = memory bandwidth: 4× BW → ~3× perf.
- Raising clock helps CNNs (compute-bound) but little for MLP/LSTM (memory-bound).
- Making the array larger (512×512) can slightly hurt—tiling inefficiency outweighs fewer steps (2-D fragmentation).
- Unified Buffer usage was improved by software; peak models now fit in ~14 MiB (from 24 MiB).
#### 8) Discussion / Lessions (a few "fallacies")
- Don’t focus only on CNNs—they were ~5% of DC inference then; MLP/LSTM dominate.
- IPS is a poor single metric; it’s more a function of the model than the hardware.
- Inference is latency-bound, so architectures must perform well under 99th-percentile constraints.
#### 9) Related Work (very briefly)
- Compared with FPGA “Catapult”: CNN speedups 2.3–7× (maybe 17×) vs. server, but TPU sees 40–70× vs. a somewhat faster server—and is programmed at a higher level (TensorFlow) rather than Verilog.
#### 10) Conclusion
- Even with some memory-bound under-utilization, “a small fraction of a huge resource can still be big” → roofline shows massive cost-effective gains. (They call this the Cornucopia Corollary to Amdahl’s Law.)
- TPU packs 25× more MACs and 3.5× more on-chip memory than K80, yet uses <½ the power; 8-bit systolic MACs are drastically cheaper in energy/area than 32-bit FP.
- Expectation: TPU becomes an archetype for domain-specific accelerators; successors will push further.


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
##### _Model Metrics_
- Accuracy, Precision, Recall; F1 balances precision–recall trade-offs.
##### _Hardware Metrics_
- Latency: sum of off-chip transfer, on-chip transfer, and compute; reduce via bandwidth, better storage/reuse, and more parallelism.
- Throughput = Workloads / Latency; distinguish from peak.
- Peak throughput (theoretical) = 2 × #MACs × f; use as the upper bound.
- Compute (MAC) efficiency = Throughput / (2 × #MACs × f); device-independent indicator of how well the design uses its MACs.
#### CNN Acceleration Methods
##### _Pruning & Quantization_
- Pruning removes unimportant weights/channels; quantization lowers bit-width to pack more work per DSP and cut power. (Section header + survey scope)
##### _Model-Structure Compression_
- Lightweight nets, knowledge distillation, and layer fusion (e.g., fold BatchNorm) lower compute and memory traffic. (Section outline)
##### _Computation Reduction_
- FFT and Winograd reduce multiplications (large vs small kernels respectively); both are classic ways to shrink conv cost.
#### Hardware Approaches
##### _Data Blocking & Parallel Computing_
- Loop tiling improves locality and reduces memory bandwidth; combine with pipelining/parallelism in FPGA fabrics.
- Loop unrolling merges iterations to raise parallelism; degree must match resources/bandwidth to avoid congestion.
##### _Four Dimensions of Parallelism_
- Filter (Pf), Channel (Pc), Pixel/Spatial (Pv), Kernel (Pk); designers mix these to fit layers and memory patterns.
- Pv and Pk have buffering/size constraints; Pc/Pf are often more flexible for large throughput.
##### _Parallel Strategies in Practice_
- Examples show different mixes (e.g., Pk+Pv+Pf or Pv+Pf) with reported GOP/s and per-DSP efficiency; mismatch to layer shapes can underutilize resources.
- Dynamic parallelism adapts Pf/Pc/Pv/Pk per layer to keep PEs busy; reported 72–98% compute efficiency on Stratix 10.
##### _Other Optimizations_
- Input reshaping (e.g., im2col to GEMM) and DSP optimization (packing low-precision MACs) frequently used. (Section outline)
#### Algorithm-Hardware Co-Design
##### _Toolflows_
- Frameworks (e.g., fpgaConvNet, Angel-Eye, Snowflake, f-CNNx) automate mapping CNNs to FPGAs, using buffering, double-buffer overlaps, and multi-objective cost functions to hit latency/throughput targets.
##### _Design Space Exploration (DSE)_
- Brute force, simulated annealing, genetic and other methods search tiling/unrolling/parallelism under resource and bandwidth limits. (Section outline)
##### _Performance & Resource Modeling_
- Analytic and learned models predict latency/power/resources to speed up DSE; the paper visualizes power vs throughput vs latency trade-offs.
#### Discussion & Conclusion
- Architectural levers (deep pipelining, parallelism, reconfigurability) drive compute and energy efficiency; pick low-power devices and prune non-essential logic.
- Future directions: heterogeneous SoCs (CPU/GPU/FPGA/ASIC), AI-driven DSE, and scalable/adaptive accelerators that reconfigure per layer/model.
- Overall message: to hit low-cost, low-latency, high-performance inference, emphasize compute efficiency and dynamic parallelism; DSE becomes increasingly critical.
  
