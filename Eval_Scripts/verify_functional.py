import numpy as np
import sys

def verify():
    print("=================================================")
    print(" FUNCTIONAL VERIFICATION: RTL vs GOLDEN MODEL")
    print("=================================================")
    
    try:
        golden = np.load('results/golden_out.npy')
        
        with open('results/rtl_out.txt', 'r') as f:
            rtl_lines = f.readlines()
            
        rtl_data = [int(line.strip(), 16) for line in rtl_lines if line.strip()]
        
        if len(golden) != len(rtl_data):
            print(f"[FAIL] Size mismatch! Golden: {len(golden)}, RTL: {len(rtl_data)}")
            sys.exit(1)
            
        errors = 0
        for i in range(len(golden)):
            if golden[i] != rtl_data[i]:
                errors += 1
                if errors <= 5:
                    print(f"Mismatch at index {i}: Golden = {golden[i]}, RTL = {rtl_data[i]}")
        
        if errors == 0:
            print("[SUCCESS] >>> RTL matches Golden Model perfectly for N=4096! <<<")
        else:
            print(f"[FAIL] >>> Found {errors} mismatches. <<<")
            
    except FileNotFoundError as e:
        print(f"[ERROR] Missing files: {e}")
        sys.exit(1)

if __name__ == "__main__":
    verify()
