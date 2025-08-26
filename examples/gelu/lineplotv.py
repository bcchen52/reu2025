#!/usr/bin/env python3
import sys
import numpy as np
import matplotlib.pyplot as plt

def main():
    if len(sys.argv) != 4:
        print("Usage: python lineplot.py <data.csv> <output.pdf> title")
        sys.exit(1)

    # We accept the first arg for interface consistency; we only use the second.
    data_path = sys.argv[1]
    output_path = sys.argv[2]
    title = sys.argv[3]

    # Read numbers from the .txt, ignore first line, keep file order.
    x_data  = np.loadtxt(data_path, dtype=np.float64, skiprows=1, delimiter=',', usecols=0)
    
    # Read the pre-calculated ulp_error from the 7th column (index 6)
    ulp_errors = np.loadtxt(data_path, dtype=np.float64, skiprows=1, delimiter=',', usecols=6)

    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(x_data, ulp_errors)
    ax.set_xlabel("x0")
    ax.set_ylabel("Error in ULPs")
    ax.set_title(f"{title}")
    fig.tight_layout()
    fig.savefig(output_path, dpi=300)
    plt.close(fig)

if __name__ == "__main__":
    main()