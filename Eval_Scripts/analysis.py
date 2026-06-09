import numpy as np, matplotlib.pyplot as plt
from scipy import stats
import os

def tvla(f, r, order=1):
    if order == 2: f, r = (f-np.mean(f, axis=0))**2, (r-np.mean(r, axis=0))**2
    return stats.ttest_ind(f, r, axis=0, equal_var=False)[0]

def main():
    if not os.path.exists('results/traces_fixed.npy'): return
    tf, tr = np.load('results/traces_fixed.npy'), np.load('results/traces_random.npy')
    t1, t2 = tvla(tf, tr, 1), tvla(tf, tr, 2)
    
    print(f"[+] QIF Leakage Entropy: {0.5 * np.log(2*np.pi*np.e*np.var(tf)):.4f} bits")
    plt.figure(figsize=(12, 6))
    plt.subplot(2,1,1); plt.plot(t1); plt.axhline(4.5, color='r', ls='--'); plt.axhline(-4.5, color='r', ls='--'); plt.title("1st Order TVLA")
    plt.subplot(2,1,2); plt.plot(t2); plt.axhline(4.5, color='r', ls='--'); plt.axhline(-4.5, color='r', ls='--'); plt.title("2nd Order TVLA")
    plt.tight_layout(); plt.savefig('results/side_channel_analysis.png')
    print("[+] Plot saved: results/side_channel_analysis.png")

if __name__ == "__main__": main()
