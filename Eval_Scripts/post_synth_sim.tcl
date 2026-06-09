
# Step A: Create a unified project
create_project ultimate_match ./ultimate_match -part xcku5p-ffvb676-2-e -force
add_files [glob rtl/*.v]
add_files -fileset sim_1 ./tb/tb_hmvp_functional.v
read_xdc constraints/timing.xdc
set_property top safe_top_engine [current_fileset]
set_property top tb_hmvp_functional [get_filesets sim_1]

# Step B: SYNTHESIZE FIRST
# This turns your RTL into physical gates with names like "_reg"
synth_design -top safe_top_engine -flatten_hierarchy none

# Step C: LAUNCH POST-SYNTHESIS SIMULATION
# This is the magic command! It simulates the physical gates, not the Verilog!
launch_simulation -mode post-synthesis -type functional

# Step D: Record the SAIF from the physical gates
open_saif results/physical_gates.saif
log_saif [get_objects -r /tb_hmvp_functional/dut/*]
run 40 ms
close_saif

# Step E: Read the SAIF back into the synthesized design
# Because both use the exact same physical gates, the names will match perfectly!
read_saif -strip_path tb_hmvp_functional/dut results/physical_gates.saif

# Step F: Generate the annotated power report
report_power -file results/power_report_MATCHED_PROTECTED.txt
report_utilization -file results/area_report_PROTECTED.txt

