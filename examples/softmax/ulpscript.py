#!/usr/bin/env python3
import csv
import pandas as pd
import numpy as np
import subprocess
import math

def get_true_value(x0, x1, x2):
    """Calls the compiled C program to get the high-precision value."""
    command = ['./softmax_ref2']
    input_str = f"{x0} {x1} {x2}"
    
    result = subprocess.run(
        command, 
        input=input_str, 
        capture_output=True, 
        text=True, 
        check=True
    )
    return float(result.stdout.strip())

# Input and output filenames
raw_data_filename = 'verificarlo_results/softmax8/softmax_og0_lp_naive-3inputs-grid-FLOAT-vp24-mca.tab' 
output_csv_filename = 'analysis_results.csv'

# Load the raw data from your .tab file
df = pd.read_csv(
    raw_data_filename, 
    delim_whitespace=True, 
    skiprows=1,
    names=['i', 'x0', 'x1', 'x2', 'result']
)

# Group the data by the unique input combinations
grouped = df.groupby(['x0', 'x1', 'x2'])

# Open the output CSV file for writing
with open(output_csv_filename, 'w', newline='') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(['x0', 'x1', 'x2', 'mean', 'std_dev', 'significant_digits', 'ulp_error'])

    # Process each group of inputs
    for name, group in grouped:
        x0, x1, x2 = name
        
        # Skip rows if any of the input values are not valid numbers (NaN)
        if any(math.isnan(v) for v in [x0, x1, x2]):
            continue

        mca_results = group['result']
        mean_val = mca_results.mean()
        std_dev = mca_results.std()
        
        if mean_val != 0 and std_dev > 0:
            sig_digits = -math.log10(std_dev / abs(mean_val))
        else:
            sig_digits = float('inf')

        true_val = get_true_value(x0, x1, x2)
        
        abs_error = abs(mean_val - true_val)
        true_val_f32 = np.float32(true_val)

        # --- Use np.spacing() for a cleaner ULP calculation ---
        ulp = np.spacing(true_val_f32)
        
        ulp_error = abs_error / ulp if ulp > 0 else 0.0
        
        writer.writerow([x0, x1, x2, mean_val, std_dev, sig_digits, ulp_error])

print(f"Analysis complete. Results have been saved to '{output_csv_filename}'")