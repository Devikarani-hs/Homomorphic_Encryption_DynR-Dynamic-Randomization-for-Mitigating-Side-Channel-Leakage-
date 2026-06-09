# ==========================================
# PHASE 1: SIMULATION & SAIF GENERATION
# ==========================================
create_project hmvp_sim ./hmvp_sim -part xcku5p-ffvb676-2-e -force
add_files ./rtl/
add_files -fileset sim_1 ./tb/tb_hmvp_functional.v
set_property top tb_hmvp_functional [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation
# Write the SAIF directly to the final destination
open_saif results/unprotected.saif
log_saif [get_objects -r /tb_hmvp_functional/dut/*]
run 40 ms
close_saif
close_project

# ==========================================
# PHASE 2: SYNTHESIS & POWER ANALYSIS
# ==========================================
read_verilog [glob rtl/*.v]
read_xdc constraints/timing.xdc

# Synthesize without flattening to preserve RTL names
synth_design -top safe_top_engine -part xcku5p-ffvb676-2-e -mode out_of_context -flatten_hierarchy none

# Read the SAIF file we just generated in Phase 1
read_saif -strip_path tb_hmvp_functional/dut results/unprotected.saif

# Generate Power and Area reports BEFORE routing messes up the nets
report_power -file results/power_report_unprotected.txt
report_utilization -file results/area_report_unprotected.txt

# ==========================================
# PHASE 3: ROUTING & TIMING
# ==========================================
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -file results/timing_report_unprotected.txt
