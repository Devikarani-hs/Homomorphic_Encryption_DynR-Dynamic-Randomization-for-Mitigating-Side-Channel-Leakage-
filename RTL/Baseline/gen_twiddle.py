#!/usr/bin/env python3
"""
gen_twiddle.py  – generate twiddle .mem files for 6 x 30-bit RNS primes, N=4096
Writes ALL output files into the same directory as this script,
regardless of which directory python3 is invoked from.
"""
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def find_ntt_primes(bits=30, N=4096, count=6):
    primes = []
    lo = 1 << (bits - 1)
    hi = 1 << bits
    p = lo | 1
    while len(primes) < count and p < hi:
        if p % N == 1:
            d, r = p - 1, 0
            while d % 2 == 0:
                d //= 2; r += 1
            ok = True
            for a in [2, 3, 5, 7, 11, 13, 17, 19, 23]:
                if a >= p: continue
                x = pow(a, d, p)
                if x == 1 or x == p - 1: continue
                for _ in range(r - 1):
                    x = x * x % p
                    if x == p - 1: break
                else:
                    ok = False; break
            if ok:
                primes.append(p)
        p += 2
    return primes

def prim_root(p):
    phi = p - 1
    facs = set()
    n = phi
    for f in [2, 3, 5, 7, 11, 13]:
        if n % f == 0:
            facs.add(f)
            while n % f == 0: n //= f
    if n > 1: facs.add(n)
    for g in range(2, p):
        if all(pow(g, phi // f, p) != 1 for f in facs):
            return g

N = 4096
primes = find_ntt_primes(30, N, 6)
print(f"RNS primes: {[hex(p) for p in primes]}")

for idx, p in enumerate(primes):
    g  = prim_root(p)
    w  = pow(g, (p - 1) // N, p)
    tw = [pow(w, i, p) for i in range(N)]

    fname = os.path.join(SCRIPT_DIR, f"twiddle_q{idx}.mem")
    with open(fname, "w") as f:
        for v in tw:
            f.write(f"{v:08x}\n")
    print(f"  Written {fname}  prime={hex(p)}")

# rns_primes.txt
with open(os.path.join(SCRIPT_DIR, "rns_primes.txt"), "w") as f:
    for p in primes: f.write(f"{p}\n")

# barrett_k.txt — floor(2^60 / p)
with open(os.path.join(SCRIPT_DIR, "barrett_k.txt"), "w") as f:
    for p in primes:
        k = (1 << 60) // p
        f.write(f"{k:016x}\n")

# n_inv.txt — N^-1 mod p
with open(os.path.join(SCRIPT_DIR, "n_inv.txt"), "w") as f:
    for p in primes:
        ni = pow(N, -1, p)
        f.write(f"{ni:08x}\n")

print("Done. All files in:", SCRIPT_DIR)
