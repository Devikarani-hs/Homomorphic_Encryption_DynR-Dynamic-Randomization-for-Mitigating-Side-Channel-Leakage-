# ===================================================================
# HE ACCELERATOR - MASTER CONSTRAINTS FILE (55 MHz Target)
# ===================================================================

# 1. PRIMARY CLOCK CONSTRAINT (55 MHz = 18.181 ns)
create_clock -period 18.181 -name clk -waveform {0.000 9.090} [get_ports clk]

# 2. OUT-OF-CONTEXT (OOC) CLOCK ROUTING
set_property HD.CLK_SRC BUFGCE_X0Y0 [get_ports clk]

# 3. ASYNCHRONOUS RESET OPTIMIZATION
set_false_path -from [get_ports rst_n]

# 4. MAXIMUM FANOUT OPTIMIZATION
set_property MAX_FANOUT 100 [get_cells -hierarchical -filter {NAME =~ *running_d1*}]
