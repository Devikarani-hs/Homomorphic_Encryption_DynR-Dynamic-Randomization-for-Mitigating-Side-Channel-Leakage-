# DynR: Dynamic Randomization for Mitigating Side-Channel Leakage in PQC

**[Anonymous Repository for Double-Blind Peer Review]**

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

This repository contains the synthesizable Register-Transfer Level (RTL) code, testbenches, and evaluation scripts for the **DynR (Dynamic Randomization) Architecture**. 

This hardware accelerator is designed to overcome the highly predictable, deterministic physical leakage of Homomorphic Matrix-Vector Products (HMVP) in Module-Lattice-Based Post-Quantum Cryptography (PQC). The datapath implements a hardware-optimized, 4-cycle read-modify-write Fisher-Yates FSM directly mapped to DSP slices. This allows for true, non-deterministic in-place memory permutation with zero additional BRAM overhead, successfully flattening First-Order Side-Channel Analysis (SCA) vulnerabilities within the ISO-17825 confidence thresholds.

## Repository Structure

To facilitate reproducibility during the review process, the repository is organized as follows:

```text
├── hw_src/                    # Synthesizable Verilog RTL source files
│   ├── bmm_core.v             # Barrett Modular Multiplier pipeline
│   ├── fisher_yates_fsm.v     # 4-cycle in-place shuffling controller
│   ├── dynr_top.v             # Top-level integration of the protected IP
│   └── unprotected_ip.v       # Standard deterministic baseline for comparison
├── sim/                       # Simulation environments and testbenches
│   └── tb_dynr.v              # Testbench for verification and trace generation
├── impl/                      # Xilinx Vivado TCL scripts and constraints
│   ├── run_synth.tcl          # Batch script for automated implementation
│   └── constraints.xdc        # Physical constraints for Kintex UltraScale+
├── eval_scripts/              # Python framework for side-channel analysis
│   └── tvla_qif_vcd.py        # Parses VCD traces and computes ISO-17825 TVLA
└── README.md                  # Project documentation

Prerequisites

To reproduce the hardware synthesis and side-channel evaluation results, the following tools are required:

    Hardware Synthesis: Xilinx Vivado Design Suite (Tested on version 2022.x or newer).

    Side-Channel Analysis: Python 3.8+ with the following packages installed.

1. Functional Simulation & Trace Generation

To verify the mathematical correctness of the in-place memory permutation and generate the power traces used for SCA evaluation:

    Launch Vivado and create a new simulation project.

    Add all Verilog files from the hw_src/ directory as design sources.

    Add sim/tb_dynr.v as the simulation source.

    Run the behavioral simulation. The testbench will functionally verify the outputs and automatically dump the signal switching activities into unprotected.vcd and protected.vcd Value Change Dump files.

2. FPGA Synthesis and ImplementationTo reproduce the resource utilization (BRAM, DSP, LUT) and maximum frequency ($F_{max}$) claims reported in the paper, run the automated build script in batch mode from your terminal:

vivado -mode batch -source impl/run_synth.tcl

Note: The run_synth.tcl script is strictly configured to target the Kintex UltraScale+ (xcku5p-ffvb676-2-e) FPGA to ensure a rigorous, direct comparison with standard baselines.

3. Side-Channel Evaluation (TVLA & SNR)

A Python-based evaluation framework is provided to verify the architecture's resistance to first-order power leakage.

Ensure the generated .vcd files are in the designated results directory, then execute:
Bash

cd eval_scripts
python3 tvla_qif_vcd.py

Expected Output: The script will output high-resolution, 4-panel plots (unprotected_four_panel.png and protected_four_panel.png) illustrating:

    First-Order Welch's t-test statistics.

    Second-Order (variance) leakage profiles.

    Hamming distance distribution and Shannon Entropy restoration.

    Signal-to-Noise Ratio (SNR) profiles.

These plots confirm that the DynR architecture successfully suppresses first-order side-channel leakage within the ±4.5 cryptographic safety threshold.
License & Double-Blind Policy

This project is licensed under the Apache License 2.0. However, to comply with double-blind peer review guidelines, all author names, affiliations, and grant acknowledgments have been thoroughly scrubbed from the source files and commit history. Full attribution and standard licensing files will be restored upon publication.
