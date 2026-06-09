
# 1. Open the project
open_project ./hmvp_sim_protected/hmvp_sim_protected.xpr

# 2. [THE IRONCLAD FIX]: Force Vivado to synthesize the design right now and wait for it to finish.
puts ">>> Synthesizing the design from scratch..."
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# 3. Now we physically open the synthesis run (because we just forced it to exist)
open_run synth_1 -name synth_1

# 4. Mute the BRAM memory collision warnings
set_msg_config -id {Unisim RAMB18E2-17} -suppress

# 5. Launch Post-Synthesis Functional Simulation
puts ">>> Launching Post-Synthesis Simulation in background..."
launch_simulation -mode post-synthesis -type functional

# 6. Generate and save the SAIF file
puts ">>> Recording SAIF file..."
open_saif results/protected_terminal.saif
log_saif [get_objects -r /tb_hmvp_functional/dut/*]
run 40 ms
close_saif

# 7. Read the dictionary back into the synthesized design
puts ">>> Annotating Power Data..."
read_saif -strip_path tb_hmvp_functional/dut results/protected_terminal.saif

# 8. Generate the final high-confidence power report
report_power -file results/power_report_MATCHED_TERMINAL.txt

puts ">>> SUCCESS: Headless simulation complete. Check results folder!"
exit
