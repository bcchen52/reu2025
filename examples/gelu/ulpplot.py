#!/usr/bin/env python3
import csv
import pandas as pd
import numpy as np
import subprocess
import math
import matplotlib.pyplot as plt
import sys
import argparse

def get_true_value(x, c_program):
    """Calls the compiled C program to get the high-precision value."""
    # Pass the value as a command-line argument, not via stdin
    command = [c_program, str(x)]
    
    try:
        result = subprocess.run(
            command, 
            capture_output=True, 
            text=True, 
            check=True
        )
        output = result.stdout.strip()
        
        # Parse the scientific notation output (e.g., "1.23456789012345e-01")
        return float(output)
        
    except subprocess.CalledProcessError as e:
        print(f"Error running C program: {e}")
        print(f"Command was: {' '.join(command)}")
        print(f"Stderr: {e.stderr}")
        print(f"Stdout: {e.stdout}")
        sys.exit(1)
    except ValueError as e:
        print(f"Error parsing output from C program: {e}")
        print(f"Output was: '{output}'")
        sys.exit(1)



def main():
    parser = argparse.ArgumentParser(description='Analyze ULP errors from Verificarlo MCA results')
    parser.add_argument('c_program', help='Path to the compiled C reference program')
    parser.add_argument('input_file', help='Path to the input .tab file from Verificarlo')
    parser.add_argument('output_csv', help='Path for the output CSV file with analysis results')
    
    args = parser.parse_args()
    
    # Validate that C program exists and is executable
    import os
    if not os.path.exists(args.c_program):
        print(f"Error: C program '{args.c_program}' not found")
        sys.exit(1)
    if not os.access(args.c_program, os.X_OK):
        print(f"Error: C program '{args.c_program}' is not executable")
        sys.exit(1)
    
    print(f"Loading data from '{args.input_file}'...")
    
    try:
        # Load the raw data from the .tab file
        # Skip the header lines starting with #
        df = pd.read_csv(
            args.input_file, 
            delim_whitespace=True, 
            comment='#',
            names=['i', 'x', 'result']
        )
    except FileNotFoundError:
        print(f"Error: Input file '{args.input_file}' not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading input file: {e}")
        sys.exit(1)
    
    # Convert columns to appropriate types
    df['x'] = pd.to_numeric(df['x'], errors='coerce')
    df['result'] = pd.to_numeric(df['result'], errors='coerce')
    
    # Drop any rows where conversion failed (NaN values)
    df = df.dropna()
    
    if df.empty:
        print("Error: No valid data found in input file")
        sys.exit(1)
    
    print(f"Processing {len(df)} data points...")
    
    # Group the data by the unique input value
    grouped = df.groupby('x')
    
    # Initialize tracking variables
    max_ulp_error = 0.0
    max_ulp_x = None
    
    # Lists to store data for plotting
    x_values_list = []
    ulp_errors_list = []
    
    # Open the output CSV file for writing
    with open(args.output_csv, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['x', 'mean', 'std_dev', 'significant_digits', 'true_value', 'abs_error', 'ulp_error'])
        
        # Process each group of inputs
        for x_value, group in grouped:
            mca_results = group['result']
            mean_val = mca_results.mean()
            std_dev = mca_results.std()
            
            # Calculate significant digits
            if mean_val != 0 and std_dev > 0:
                sig_digits = -math.log10(std_dev / abs(mean_val))
            else:
                sig_digits = float('inf') if std_dev == 0 else 0
            
            # Get the true value for this input
            true_val = get_true_value(x_value, args.c_program)
            
            abs_error = abs(mean_val - true_val)
            
            # Determine the precision based on the data type
            # Check if we're dealing with float32 or float64
            # Assuming float64 (double precision) by default
            true_val_float = np.float64(true_val)
            
            # Use np.spacing() for ULP calculation
            ulp = abs(np.spacing(true_val_float))
            
            ulp_error = abs_error / ulp if ulp != 0 else 0.0
            
            # Track the maximum ULP error
            if ulp_error > max_ulp_error:
                max_ulp_error = ulp_error
                max_ulp_x = x_value
            
            # Store data for plotting
            x_values_list.append(x_value)
            ulp_errors_list.append(ulp_error)
            
            writer.writerow([x_value, mean_val, std_dev, sig_digits, true_val, abs_error, ulp_error])
    
    print(f"\nAnalysis complete. Results saved to '{args.output_csv}'")
    print(f"\nSummary Statistics:")
    print(f"  Total unique x values: {len(x_values_list)}")
    print(f"  Maximum ULP error: {max_ulp_error:.6f} at x = {max_ulp_x}")
    print(f"  Mean ULP error: {np.mean(ulp_errors_list)}")
    print(f"  Median ULP error: {np.median(ulp_errors_list)}")
    print(f"  Min ULP error: {np.min(ulp_errors_list)}")
    

if __name__ == "__main__":
    sys.exit(main())