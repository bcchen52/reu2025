#!/usr/bin/env python3
"""
Simplified script to plot 2D heatmap of significant digits for Verificarlo results
Designed for data files with exactly 2 varying inputs
"""

import sys
import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import argparse
from pathlib import Path

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Plot 2D heatmap of significant digits for Verificarlo results'
    )
    
    parser.add_argument('datafile', 
                        help='Input data file (.tab format)')
    parser.add_argument('precision', type=int,
                        help='Verificarlo precision in bits')
    parser.add_argument('--output', 
                        help='Output filename (default: auto-generated)')
    parser.add_argument('--format', default='pdf', 
                        choices=['pdf', 'png', 'svg', 'eps'],
                        help='Output format (default: pdf)')
    parser.add_argument('--dpi', type=int, default=300,
                        help='DPI for raster formats (default: 300)')
    parser.add_argument('--figsize', nargs=2, type=float, default=[10, 8],
                        help='Figure size in inches (default: 10 8)')
    parser.add_argument('--cmap', default='viridis',
                        help='Colormap for heatmap (default: viridis)')
    parser.add_argument('--title',
                        help='Custom title for the plot')
    parser.add_argument('--show', action='store_true',
                        help='Display plot interactively')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.datafile):
        parser.error(f"Input file '{args.datafile}' not found")
    
    return args

def load_data(filename):
    """Load and parse the data file with 2 varying inputs"""
    # First, detect the format by reading the header
    with open(filename, 'r') as f:
        # Skip comment lines
        line = f.readline()
        while line.startswith('#'):
            line = f.readline()
    
    # Load the data
    data = np.loadtxt(filename, skiprows=1 if not filename.endswith('.csv') else 0)
    
    # Determine number of columns
    n_cols = data.shape[1]
    
    if n_cols == 4:  # Format: i x0 x1 result
        return data[:, 1], data[:, 2], data[:, 3]  # x0, x1, results
    elif n_cols == 3:  # Format: x0 x1 result (no index)
        return data[:, 0], data[:, 1], data[:, 2]  # x0, x1, results
    # --- MODIFIED SECTION START ---
    # Added handling for 5-column data where one input is fixed
    elif n_cols == 5:  # Format: i x0 x1 x2 result (assuming x2 is fixed)
        print("Detected 5 columns. Assuming format 'i x0 x1 x2 result' with x2 as a fixed parameter.")
        return data[:, 1], data[:, 2], data[:, 4]  # x0, x1, results
    # --- MODIFIED SECTION END ---
    else:
        raise ValueError(f"Unexpected number of columns: {n_cols}")

def compute_significant_digits(x0_data, x1_data, results, precision_bits):
    """Compute significant digits for each unique (x0, x1) combination"""
    # Get unique values for each input
    unique_x0 = np.unique(x0_data)
    unique_x1 = np.unique(x1_data)
    
    # Create grid for significant digits
    sig_digits_grid = np.zeros((len(unique_x1), len(unique_x0)))
    
    # Calculate maximum significant digits based on precision
    max_sig_digits = precision_bits * np.log10(2)
    
    # Process each unique combination
    for i, x0 in enumerate(unique_x0):
        for j, x1 in enumerate(unique_x1):
            # Find all results for this combination
            mask = (x0_data == x0) & (x1_data == x1)
            if np.any(mask):
                values = results[mask]
                mean_val = np.mean(values)
                std_val = np.std(values)
                
                # Compute significant digits with proper bounds
                if std_val < 1e-15 or std_val == 0:  # Below machine epsilon
                    sig_digits = max_sig_digits
                elif mean_val == 0:
                    sig_digits = 0
                else:
                    # Cap at maximum possible for the precision
                    sig_digits = min(-np.log10(std_val/abs(mean_val)), max_sig_digits)
                
                sig_digits_grid[j, i] = sig_digits
    
    return unique_x0, unique_x1, sig_digits_grid, max_sig_digits

def create_heatmap(unique_x0, unique_x1, sig_digits_grid, max_sig_digits, args):
    """Create the 2D heatmap of significant digits"""
    fig, ax = plt.subplots(figsize=args.figsize)
    
    # Create the heatmap
    im = ax.imshow(sig_digits_grid, 
                   aspect='auto', 
                   origin='lower',
                   extent=[unique_x0[0], unique_x0[-1], unique_x1[0], unique_x1[-1]],
                   cmap=args.cmap,
                   vmin=0,
                   vmax=max_sig_digits)
    
    # Add colorbar
    cbar = plt.colorbar(im, ax=ax)
    cbar.set_label('Significant Digits', fontsize=12)
    
    # Set labels
    ax.set_xlabel('x0', fontsize=12)
    ax.set_ylabel('x1', fontsize=12)
    
    # Add title: use custom title if provided, otherwise generate default title
    if args.title:
        plot_title = args.title
    else:
        basename = Path(args.datafile).stem
        plot_title = f'Significant Digits Heatmap\n{basename} (Precision: {args.precision} bits)'
    
    ax.set_title(plot_title, fontsize=14)
    
    # Add grid
    ax.grid(True, alpha=0.3, linestyle='--')
    
    # Tight layout
    plt.tight_layout()
    
    return fig

def main():
    """Main function"""
    args = parse_arguments()
    
    # Load data
    print(f"Loading data from: {args.datafile}")
    try:
        x0_data, x1_data, results = load_data(args.datafile)
        print(f"Loaded {len(results)} data points")
    except Exception as e:
        print(f"Error loading data: {e}")
        sys.exit(1)
    
    # Compute significant digits
    print("Computing significant digits...")
    unique_x0, unique_x1, sig_digits_grid, max_sig_digits = compute_significant_digits(
        x0_data, x1_data, results, args.precision
    )
    print(f"Grid size: {len(unique_x0)} x {len(unique_x1)}")
    print(f"Max theoretical significant digits: {max_sig_digits:.2f}")
    
    # Create heatmap
    print("Creating heatmap...")
    fig = create_heatmap(unique_x0, unique_x1, sig_digits_grid, max_sig_digits, args)
    
    # Save plot
    if args.output:
        output_file = args.output
    else:
        basename = Path(args.datafile).stem
        output_file = f"{basename}_sigdigits_heatmap.{args.format}"
    
    fig.savefig(output_file, format=args.format, dpi=args.dpi, bbox_inches='tight')
    print(f"Heatmap saved to: {output_file}")
    
    # Print some statistics
    print(f"\nStatistics:")
    print(f"  Min significant digits: {sig_digits_grid.min():.2f}")
    print(f"  Max significant digits: {sig_digits_grid.max():.2f}")
    print(f"  Mean significant digits: {sig_digits_grid.mean():.2f}")
    
    # Show plot if requested
    if args.show:
        plt.show()
    
    print("\nDone!")

if __name__ == "__main__":
    main()