#!/usr/bin/env python3
import csv
import pandas as pd
import numpy as np
import subprocess
import math

def get_true_value(x):
    """Calls the compiled C program to get the high-precision value."""
    # You'll need to modify this based on your reference program
    # For example, if you have a program that computes 2*x:
    command = ['./parallel_5ref']  # Replace with your actual program
    input_str = f"{x}"
    
    result = subprocess.run(
        command, 
        input=input_str, 
        capture_output=True, 
        text=True, 
        check=True
    )
    return float(result.stdout.strip())

# Input and output filenames
raw_data_filename = 'verificarlo_results/parallel_5/input2/parallel_5-DOUBLE-p53-mca.tab'  # Your input file
output_csv_filename = 'analysis_results.csv'

# Load the raw data from your .tab file
# Skip the header lines starting with #
df = pd.read_csv(
    raw_data_filename, 
    delim_whitespace=True, 
    comment='#',
    names=['i', 'x', 'result']
)
# Convert columns to appropriate types
df['x'] = pd.to_numeric(df['x'], errors='coerce')
df['result'] = pd.to_numeric(df['result'], errors='coerce')

# Drop any rows where conversion failed (NaN values)
df = df.dropna()
# Group the data by the unique input value
grouped = df.groupby('x')
# Initialize variable to track maximum ULP error
max_ulp_error = 0.0
max_ulp_x = None

# Open the output CSV file for writing
with open(output_csv_filename, 'w', newline='') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(['x', 'mean', 'std_dev', 'significant_digits', 'ulp_error'])

    # Process each group of inputs
    for x_value, group in grouped:

        mca_results = group['result']
        mean_val = mca_results.mean()
        std_dev = mca_results.std()
        
        if mean_val != 0 and std_dev > 0:
            sig_digits = -math.log10(std_dev / abs(mean_val))
        else:
            sig_digits = float('inf')

        # Get the true value for this input
        # NOTE: You need to implement get_true_value() based on what your program computes
        # For now, I'm assuming it's computing 2*x based on the pattern in your data
        # You should replace this with the actual computation
        true_val = get_true_value(x_value)  # REPLACE THIS with: true_val = get_true_value(x)
        
        abs_error = abs(mean_val - true_val)
        
        # Determine the precision based on the data type
        # Since your file says DOUBLE with precision 53, use float64
        true_val_float = np.float64(true_val)

        # Use np.spacing() for ULP calculation
        ulp = np.spacing(true_val_float)
        
        ulp_error = abs_error / ulp if ulp > 0 else 0.0

                # Track the maximum ULP error
        if ulp_error > max_ulp_error:
            max_ulp_error = ulp_error
            max_ulp_x = x_value
        
        writer.writerow([x_value, mean_val, std_dev, sig_digits, ulp_error])

print(f"Analysis complete. Results have been saved to '{output_csv_filename}'")
print(f"\nMaximum ULP error: {max_ulp_error:.6f} at x = {max_ulp_x}")
