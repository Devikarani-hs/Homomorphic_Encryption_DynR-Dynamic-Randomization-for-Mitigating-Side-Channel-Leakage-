import numpy as np
import scipy.stats as stats
import matplotlib.pyplot as plt
import sys

VCD_FILE = "results/power_leakage.vcd"

print(f"[*] Parsing VCD File: {VCD_FILE} (Pure Python Fast Mode)")

toggle_counts = []
current_time = 0
current_toggles = 0
CLOCK_PERIOD_PS = 20000 # 20.0 ns from your 50MHz constraint
parsing_data = False

try:
    with open(VCD_FILE, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
                
            # Wait until the header is finished and the actual dump begins
            if line == "$dumpvars":
                parsing_data = True
                continue
                
            if not parsing_data:
                continue
                
            # Time update marker
            if line.startswith('#'):
                try:
                    time = int(line[1:])
                    # If we moved to a new clock cycle, save the toggles
                    if time - current_time >= CLOCK_PERIOD_PS:
                        toggle_counts.append(current_toggles)
                        current_toggles = 0
                        current_time = time
                except ValueError:
                    pass
                    
            # Skip VCD commands
            elif line.startswith('$'):
                continue
                
            # Anything else is a signal toggle (0, 1, x, z, b...)
            else:
                current_toggles += 1
                
except FileNotFoundError:
    print(f"[!] Error: Could not find {VCD_FILE}. Did you run the simulation?")
    sys.exit(1)

hw_traces = np.array(toggle_counts)

if len(hw_traces) < 100:
    print("[!] Not enough clock cycles captured. Check your simulation.")
    sys.exit(1)

print(f"[*] Extracted {len(hw_traces)} clock cycles of power data.")

# Split data into two sets (Simulating Fixed vs Random for TVLA)
midpoint = len(hw_traces) // 2
set_0 = hw_traces[:midpoint]
set_1 = hw_traces[midpoint:midpoint*2]

# --- 1. First-Order TVLA ---
print("[*] Calculating 1st-Order TVLA...")
window_size = min(1000, len(set_0) // 10)
rolling_t_1st = [stats.ttest_ind(set_0[i:i+window_size], set_1[i:i+window_size], equal_var=False)[0] 
                 for i in range(0, len(set_0) - window_size, window_size//2)]

# --- 2. Second-Order TVLA ---
print("[*] Calculating 2nd-Order TVLA...")
mean_0, mean_1 = np.mean(set_0), np.mean(set_1)
set_0_sq, set_1_sq = (set_0 - mean_0)**2, (set_1 - mean_1)**2

rolling_t_2nd = [stats.ttest_ind(set_0_sq[i:i+window_size], set_1_sq[i:i+window_size], equal_var=False)[0] 
                 for i in range(0, len(set_0_sq) - window_size, window_size//2)]

# --- 3. QIF (Quantitative Information Flow) ---
print("[*] Calculating Leakage Entropy (QIF)...")
counts = np.bincount(hw_traces)
probabilities = counts[counts > 0] / len(hw_traces)
entropy = -np.sum(probabilities * np.log2(probabilities))

# ==========================================
# PLOTTING FOR PUBLICATION
# ==========================================
print("[*] Generating IEEE-Formatted Plots...")
plt.style.use('seaborn-v0_8-whitegrid')
fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(10, 12))

# Plot 1: 1st Order TVLA
ax1.plot(rolling_t_1st, color='blue', linewidth=1.5)
ax1.axhline(y=4.5, color='red', linestyle='--', linewidth=2, label='+4.5 Threshold')
ax1.axhline(y=-4.5, color='red', linestyle='--', linewidth=2, label='-4.5 Threshold')
ax1.set_title("First-Order TVLA (Welch's T-Test)")
ax1.set_ylabel("t-statistic")
ax1.set_ylim(-8, 8) # ZOOMED Y-AXIS
ax1.legend(loc="upper right")

# Plot 2: 2nd Order TVLA
ax2.plot(rolling_t_2nd, color='purple', linewidth=1.5)
ax2.axhline(y=4.5, color='red', linestyle='--', linewidth=2)
ax2.axhline(y=-4.5, color='red', linestyle='--', linewidth=2)
ax2.set_title("Second-Order TVLA (Mean-Free Squared)")
ax2.set_ylabel("t-statistic")
ax2.set_ylim(-8, 12) # ZOOMED Y-AXIS
ax2.legend(loc="upper right")

# Plot 3: QIF Histogram
ax3.hist(hw_traces, bins=50, color='teal', alpha=0.7, edgecolor='black')
ax3.set_title(f"Quantitative Information Flow (QIF) - Entropy: {entropy:.2f} bits")
ax3.set_xlabel("Hamming Distance (Gate Toggles per Cycle)")
ax3.set_ylabel("Frequency")

plt.tight_layout()
plt.savefig("results/sca_analysis_plots.png", dpi=300)
print("[+] Analysis Complete! Plot saved to results/sca_analysis_plots.png")
