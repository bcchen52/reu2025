#!/usr/bin/env python3

############################################################################
# Plots significant digits (s) from a set of stochastic outputs           #
# from verificarlo in a simple line plot format.                          #
############################################################################

import sys
import numpy as np
import math
import os

import matplotlib
# Use Agg backend for headless runs
matplotlib.use('Agg')

import matplotlib.pyplot as plt

def main():
    # Read command line arguments
    if len(sys.argv) < 4:
        print("Usage: python plot_sig_digits.py <DATA.tab> <precision> <output.pdf> [title]")
        sys.exit(1)

    fname = sys.argv[1]
    prec_b = sys.argv[2]
    output_path = sys.argv[3]
    
    # Use provided title or generate from filename
    if len(sys.argv) > 4:
        title = sys.argv[4]
    else:
        program_name = os.path.basename(fname).split('-')[0].replace('.tab', '')
        title = f"{program_name} - verificarlo precision = {prec_b} bits"

    # Convert binary to decimal precision
    prec_dec = float(prec_b) * math.log(2, 10)

    # Count header lines (including the column names line)
    with open(fname, 'r') as f:
        header_lines = 0
        for line in f:
            if line.startswith('#') or line.strip() == 'i x result':
                header_lines += 1
            else:
                # Check if this is actually a data line
                parts = line.strip().split()
                if len(parts) >= 3:
                    try:
                        int(parts[0])  # Try to parse first column as int
                        float(parts[1])  # Try to parse second column as float
                        float(parts[2])  # Try to parse third column as float
                        break  # This is a valid data line
                    except ValueError:
                        header_lines += 1  # This is still a header line
                else:
                    header_lines += 1

    # Parse table file
    # three columns:
    #   - i: sample number
    #   - x: input value
    #   - result: function evaluation on x
    D = np.loadtxt(fname, skiprows=header_lines,
            dtype = dict(names=('i', 'x', 'result'),
                         formats=('i4', 'f8', 'f8')))

    # Compute significant digits for each unique x value
    x_values = np.unique(D['x'])
    s_values = []

    for x in x_values:
        # select all result samples for given x
        result_samples = D[D['x'] == x]['result']
        
        # Compute mu and sigma statistics
        mu = np.mean(result_samples)
        sigma = np.std(result_samples)
        
        # Compute significant digits
        if sigma == 0:
            s = prec_dec
        elif mu == 0:
            s = 0
        else:
            # Stott Parker's formula using mean as reference
            s = min(-math.log10(sigma/abs(mu)), prec_dec)
        
        s_values.append(s)

    # Create the plot in similar style to lineplotv
    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(x_values, s_values, 'b.-')
    ax.axhline(y=prec_dec, color='r', linestyle='--', alpha=0.7, 
               label=f'Max precision ({prec_dec:.1f})')
    ax.set_xlabel("x")
    ax.set_ylabel("Significant digits")
    ax.set_title(title)
    ax.grid(True, alpha=0.3)
    ax.legend()
    
    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    
    print(f"Plot saved to {output_path}")
    
    # Print summary statistics
    print(f"Average significant digits: {np.mean(s_values):.2f}")
    print(f"Min significant digits: {np.min(s_values):.2f}")
    print(f"Max significant digits: {np.max(s_values):.2f}")

if __name__ == "__main__":
    main()