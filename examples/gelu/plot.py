#!/usr/bin/env python3

############################################################################
# Plots mean (mu), standard deviation (sigma), and significant digits (s)  #
# from a set of stochastic outputs from verificarlo.                       #
############################################################################

import sys
import numpy as np
import csv
import math
import os

import matplotlib
# Use Agg backend for headless runs
matplotlib.use('Agg')

import matplotlib.pyplot as plt

# Read command line arguments
if len(sys.argv) < 3 or not sys.argv[1].endswith('.tab'):
    print("usage: ./plot_verificarlo.py DATA.tab precision [expected_function]")
    print("  expected_function: optional, either 'none' or a function like '4*x' (default: none)")
    sys.exit(1)

fname = sys.argv[1]
prec_b = sys.argv[2]
version = fname[:-4]

# Parse expected function if provided
expected_func = None
expected_func_str = "none"
if len(sys.argv) > 3:
    expected_func_str = sys.argv[3]
    if expected_func_str.lower() != 'none':
        # Create a lambda function from the string
        # Safety: only allow x as variable and basic math operations
        try:
            expected_func = lambda x: eval(expected_func_str, {"__builtins__": {}, "x": x, "math": math})
        except:
            print(f"Warning: Could not parse expected function '{expected_func_str}', proceeding without it")
            expected_func = None

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

print(f"Detected {header_lines} header lines in {fname}")

# Parse table file
# three columns:
#   - i: sample number
#   - x: input value
#   - result: function evaluation on x
D = np.loadtxt(fname, skiprows=header_lines,
        dtype = dict(names=('i', 'x', 'result'),
                     formats=('i4', 'f8', 'f8')))

# Extract program name from filename
program_name = os.path.basename(version).split('-')[0]

# Compute all statistics (mu, sigma, s)
x_values = np.unique(D['x'])
mu_values = []
sigma_values = []
s_values = []
expected_values = []
relative_errors = []

for x in x_values:
    # select all result samples for given x
    result_samples = D[D['x'] == x]['result']
    
    # Compute expected value if function provided
    if expected_func:
        expected = expected_func(x)
        expected_values.append(expected)
    else:
        expected = None
    
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
    
    # Compute relative error if expected value available
    if expected is not None:
        if expected != 0:
            rel_err = abs(mu - expected) / abs(expected)
        else:
            rel_err = abs(mu - expected) if mu != expected else 0
        relative_errors.append(rel_err)
    
    mu_values.append(mu)
    sigma_values.append(sigma)
    s_values.append(s)

# Save statistics to CSV file
csv_filename = version + "-stats.csv"
with open(csv_filename, 'w', newline='') as csvfile:
    if expected_func:
        fieldnames = ['x', 'mean', 'std_deviation', 'significant_digits', 'expected', 'relative_error']
    else:
        fieldnames = ['x', 'mean', 'std_deviation', 'significant_digits']
    
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    
    for i in range(len(x_values)):
        row = {
            'x': x_values[i],
            'mean': mu_values[i],
            'std_deviation': sigma_values[i],
            'significant_digits': s_values[i]
        }
        if expected_func:
            row['expected'] = expected_values[i]
            row['relative_error'] = relative_errors[i]
        writer.writerow(row)

print(f"Statistics saved to {csv_filename}")

# Plot all statistics
# Determine number of subplots
num_plots = 3 if not expected_func else 4

# Set title
title = f"{program_name} - verificarlo precision = {prec_b} bits"
if expected_func:
    title += f" (expected: {expected_func_str})"

plt.figure(title, figsize=(10, 2.5 * num_plots))
plt.suptitle(title)

plot_idx = 1

# Plot 1: Significant digits
plt.subplot(num_plots, 1, plot_idx)
plt.ylabel("$s$ (significant digits)")
plt.plot(x_values, s_values, 'b.')
plt.axhline(y=prec_dec, color='r', linestyle='--', alpha=0.5, label=f'Max precision ({prec_dec:.1f})')
plt.grid(True, alpha=0.3)
plt.legend()
plot_idx += 1

# Plot 2: Standard deviation
plt.subplot(num_plots, 1, plot_idx)
plt.ylabel("$\hat{\sigma}$ (std dev)")
plt.plot(x_values, sigma_values, 'g.')
if max(sigma_values) > 0:
    plt.yscale('log')
plt.grid(True, alpha=0.3)
plot_idx += 1

# Plot 3: Relative error (if expected function provided)
if expected_func and relative_errors:
    plt.subplot(num_plots, 1, plot_idx)
    plt.ylabel("Relative Error")
    plt.plot(x_values, relative_errors, 'r.')
    if max(relative_errors) > 0:
        plt.yscale('log')
    plt.grid(True, alpha=0.3)
    plot_idx += 1

# Plot 4: Samples and mean
plt.subplot(num_plots, 1, plot_idx)
plt.xlabel("$x$")
plt.ylabel("$f(x)$ and $\hat{\mu}$")
# Plot all samples with transparency
plt.plot(D['x'], D['result'], 'k.', alpha=0.3, markersize=4, label='Samples')
# Plot mean values
plt.plot(x_values, mu_values, 'b-', linewidth=2, label='$\hat{\mu}$ (mean)')
# Plot expected values if available
if expected_func:
    plt.plot(x_values, expected_values, 'r--', linewidth=2, label=f'Expected ({expected_func_str})')
plt.legend()
plt.grid(True, alpha=0.3)

# Set layout
plt.tight_layout()
plt.subplots_adjust(top=0.95)

# Save plot as pdf
plotname = version + "-" + prec_b + ".pdf"
plt.savefig(plotname, format='pdf', dpi=150)
print(f"Plot saved to {plotname}")

# Also save as png for easier viewing
plotname_png = version + "-" + prec_b + ".png"
plt.savefig(plotname_png, format='png', dpi=150)
print(f"Plot also saved to {plotname_png}")

# Print summary statistics
print("\nSummary Statistics:")
print(f"Average significant digits: {np.mean(s_values):.2f}")
print(f"Min significant digits: {np.min(s_values):.2f}")
print(f"Max significant digits: {np.max(s_values):.2f}")
if relative_errors:
    print(f"Average relative error: {np.mean(relative_errors):.2e}")
