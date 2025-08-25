#!/usr/bin/env python3
import sys
import numpy as np
import matplotlib.pyplot as plt

def main():
    if len(sys.argv) != 3:
        print("Usage: python lineplot.py <output_low.csv> <errors.txt>")
        sys.exit(1)

    # We accept the first arg for interface consistency; we only use the second.
    out_path = sys.argv[1]
    err_path = sys.argv[2]

    # Read numbers from the .txt, ignore first line, keep file order.
   
    outputs = np.loadtxt(out_path, dtype=np.float64, skiprows=1)
    errors  = np.loadtxt(err_path, dtype=np.float64, skiprows=1)

    ulp_errors = errors/np.spacing(outputs.astype(np.float32))

    #x = range(len(values))
    
    x = np.linspace(-4.0, 4.0, 80)
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(x, ulp_errors)
    ax.set_xlabel("x0")
    ax.set_ylabel("Error in ULPs")
    ax.set_title("GELU w/ Exp fp32 Error in ULPs")
    fig.tight_layout()
    fig.savefig("gelu_exp_fp32_ulp.pdf", dpi=150)

if __name__ == "__main__":
    main()
