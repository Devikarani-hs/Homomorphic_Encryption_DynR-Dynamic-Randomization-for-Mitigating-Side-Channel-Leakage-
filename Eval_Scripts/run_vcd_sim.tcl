create_project hmvp_sim ./hmvp_sim -part xcku5p-ffvb676-2-e -force
add_files ./rtl/
add_files -fileset sim_1 ./tb/tb_hmvp_functional.v
set_property top tb_hmvp_functional [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation

# Dump the VCD exactly where the Python script expects it
open_vcd results/power_leakage.vcd
log_vcd [get_objects -r /tb_hmvp_functional/dut/*]

run all
close_vcd
quit
