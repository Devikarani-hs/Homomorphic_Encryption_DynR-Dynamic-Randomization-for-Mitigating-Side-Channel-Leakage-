create_project hmvp_sim ./hmvp_sim -part xcku5p-ffvb676-2-e -force
add_files ./rtl/
add_files -fileset sim_1 ./tb/tb_hmvp_functional.v
set_property top tb_hmvp_functional [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation

# Generate the mandatory SAIF file
open_saif saif_output.saif
log_saif [get_objects -r /tb_hmvp_functional/dut/*]

# Run past the 36.9ms completion time, then pause
run 40 ms

# The TCL script retains absolute control and safely flushes the buffer to your hard drive
close_saif
quit
