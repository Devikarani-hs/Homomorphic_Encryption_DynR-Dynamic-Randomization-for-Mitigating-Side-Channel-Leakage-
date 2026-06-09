import numpy as np
import matplotlib.pyplot as plt
from scipy.stats import ttest_ind
import os

# 1. Load the extracted VCD traces
# Ensure these paths point to where your analyze_vcd_sca.py saved the output
fixed_file = 'results/traces_fixed.npy'
random_file = 'results/traces_random.npy'

# Fallback to local dir if not in results/
if not os.path.exists(fixed_file):
    fixed_file = 'traces_fixed.npy'
    random_file = 'traces_random.npy'

print("[*] Loading traces...")
traces_fixed = np.load(fixed_file)
traces_random = np.load(random_file)

num_samples = traces_fixed.shape[1]
time_axis = np.arange(num_samples)

print(f"[*] Loaded {traces_fixed.shape[0]} fixed traces and {traces_random.shape[0]} random traces.")
print("[*] Computing 1st-Order TVLA (Mean Leakage)...")

# 2. Compute 1st-Order TVLA (Welch's t-test on raw traces)
# equal_var=False ensures it uses Welch's t-test rather than Student's t-test
t_stat_1st, _ = ttest_ind(traces_fixed, traces_random, axis=0, equal_var=False)

print("[*] Computing 2nd-Order TVLA (Variance Leakage)...")

# 3. Compute 2nd-Order TVLA (Welch's t-test on mean-centered, squared traces)
mean_fixed = np.mean(traces_fixed, axis=0)
mean_random = np.mean(traces_random, axis=0)

centered_sq_fixed = (traces_fixed - mean_fixed)**2
centered_sq_random = (traces_random - mean_random)**2

t_stat_2nd, _ = ttest_ind(centered_sq_fixed, centered_sq_random, axis=0, equal_var=False)

print("[*] Computing Quantitative Information Flow (SNR Approximation)...")

# 4. Compute QIF / Signal-to-Noise Ratio (SNR)
# SNR = Var(Means) / Mean(Vars)
var_of_means = np.var([mean_fixed, mean_random], axis=0)
mean_of_vars = np.mean([np.var(traces_fixed, axis=0), np.var(traces_random, axis=0)], axis=0)
# Add small epsilon to avoid division by zero
snr = var_of_means / (mean_of_vars + 1e-9) 

# 5. Plotting
print("[*] Generating Plots...")
fig, axes = plt.subplots(3, 1, figsize=(12, 10), sharex=True)
fig.suptitle('Side-Channel Analysis: Unprotected Baseline Counter', fontsize=16, fontweight='bold')

# Plot 1: 1st Order TVLA
axes[0].plot(time_axis, t_stat_1st, color='red', linewidth=1)
axes[0].axhline(y=4.5, color='black', linestyle='--', label='Threshold (+4.5)')
axes[0].axhline(y=-4.5, color='black', linestyle='--', label='Threshold (-4.5)')
axes[0].set_ylabel('T-Statistic')
axes[0].set_title('1st-Order TVLA (Direct Data Leakage)')
axes[0].legend(loc='upper right')
axes[0].grid(True, alpha=0.3)

# Plot 2: 2nd Order TVLA
axes[1].plot(time_axis, t_stat_2nd, color='orange', linewidth=1)
axes[1].axhline(y=4.5, color='black', linestyle='--')
axes[1].axhline(y=-4.5, color='black', linestyle='--')
axes[1].set_ylabel('T-Statistic')
axes[1].set_title('2nd-Order TVLA (Variance / Masking Leakage)')
axes[1].grid(True, alpha=0.3)

# Plot 3: QIF (SNR)
axes[2].plot(time_axis, snr, color='purple', linewidth=1)
axes[2].set_ylabel('SNR')
axes[2].set_xlabel('Simulation Time / Sample Index')
axes[2].set_title('Quantitative Information Flow (SNR)')
axes[2].grid(True, alpha=0.3)

plt.tight_layout(rect=[0, 0.03, 1, 0.95])
output_img = 'results/unprotected_sca_analysis.png'
plt.savefig(output_img, dpi=300)
print(f"[+] Success! Plot saved to {output_img}")
