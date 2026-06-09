read_verilog [glob rtl/*.v]
read_xdc constraints/timing.xdc

# 1. Synthesize while preserving all RTL names
synth_design -top safe_top_engine -part xcku5p-ffvb676-2-e -mode out_of_context -flatten_hierarchy none

# 2. READ SAIF IMMEDIATELY (Before opt_design and route_design destroy the nets)
set saif_file [lindex $argv 0]
read_saif -strip_path tb_hmvp_functional/dut $saif_file

# 3. Generate Power and Area Reports based on the pristine netlist
report_power -file results/power_report_FINAL_RUN.txt
report_utilization -file results/area_report_FINAL_RUN.txt

# 4. Proceed with physical routing just to get the Timing Report
opt_design
place_design
phys_opt_design
route_design

report_timing_summary -file results/timing_report_FINAL_RUN.txt
