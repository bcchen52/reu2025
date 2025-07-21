#!/usr/bin/env python3
"""
Generalized plotting script for Verificarlo output
Plots mean (mu), standard deviation (sigma), and significant digits (s)
from stochastic outputs of numerical programs run with Verificarlo
"""

import sys
import os
import numpy as np
import matplotlib
# Use Agg backend for headless runs
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import math
import argparse
from pathlib import Path
from datetime import datetime

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Plot Verificarlo stochastic analysis results',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s data.tab 24
  %(prog)s data.tab 53 --title "My Analysis" --output my_plot.pdf
  %(prog)s data.tab 24 --show --figsize 12 10
  %(prog)s data.tab 24 --plot-dir my_plots
        """
    )
    
    parser.add_argument('datafile', 
                        help='Input data file (.tab format)')
    parser.add_argument('precision', type=int,
                        help='Verificarlo precision in bits')
    parser.add_argument('--title', 
                        help='Custom plot title (default: auto-generated from filename)')
    parser.add_argument('--output', 
                        help='Output filename (default: auto-generated)')
    parser.add_argument('--plot-dir', default='plots',
                        help='Directory to save plots (default: ./plots)')
    parser.add_argument('--show', action='store_true',
                        help='Display plot interactively (default: save only)')
    parser.add_argument('--format', default='pdf', 
                        choices=['pdf', 'png', 'svg', 'eps'],
                        help='Output format (default: pdf)')
    parser.add_argument('--dpi', type=int, default=300,
                        help='DPI for raster formats (default: 300)')
    parser.add_argument('--figsize', nargs=2, type=float, default=[10, 8],
                        help='Figure size in inches (default: 10 8)')
    parser.add_argument('--style', default='default',
                        help='Matplotlib style (default: default)')
    parser.add_argument('--alpha', type=float, default=0.5,
                        help='Alpha transparency for sample points (default: 0.5)')
    parser.add_argument('--xlim', nargs=2, type=float,
                        help='X-axis limits (default: auto)')
    parser.add_argument('--log-sigma', action='store_true',
                        help='Use log scale for sigma plot')
    parser.add_argument('--save-data', action='store_true',
                        help='Save computed statistics to CSV file')
    
    args = parser.parse_args()
    
    # Validate input file
    if not os.path.exists(args.datafile):
        parser.error(f"Input file '{args.datafile}' not found")
    
    return args

def load_data(filename):
    """Load and parse the data file"""
    try:
        # Try to load with headers
        data = np.loadtxt(filename, skiprows=1,
                         dtype=dict(names=('i', 'x', 'result'),
                                  formats=('i4', 'f8', 'f8')))
    except:
        # Try without headers or with different format
        try:
            data = np.loadtxt(filename,
                             dtype=dict(names=('i', 'x', 'result'),
                                      formats=('i4', 'f8', 'f8')))
        except Exception as e:
            print(f"Error loading data file: {e}")
            sys.exit(1)
    
    return data

def compute_statistics(data, precision_bits):
    """Compute mean, standard deviation, and significant digits"""
    # Convert binary to decimal precision
    precision_decimal = float(precision_bits) * math.log(2, 10)
    
    # Get unique x values
    x_values = np.unique(data['x'])
    
    # Initialize result arrays
    mu_values = []
    sigma_values = []
    s_values = []
    
    for x in x_values:
        # Select all samples for given x
        samples = data[data['x'] == x]['result']
        
        # Compute mean and standard deviation
        mu = np.mean(samples)
        sigma = np.std(samples)
        
        # Compute significant digits using Stott Parker's formula
        if sigma == 0:
            s = precision_decimal
        elif mu == 0:
            s = 0
        else:
            s = min(-math.log10(sigma / abs(mu)), precision_decimal)
        
        mu_values.append(mu)
        sigma_values.append(sigma)
        s_values.append(s)
    
    return x_values, np.array(mu_values), np.array(sigma_values), np.array(s_values), precision_decimal

def create_plot(data, x_values, mu_values, sigma_values, s_values, precision_decimal, args):
    """Create the plot with three subplots"""
    
    # Set style if specified
    if args.style != 'default':
        try:
            plt.style.use(args.style)
        except:
            print(f"Warning: Style '{args.style}' not found, using default")
    
    # Create figure
    fig = plt.figure(figsize=args.figsize)
    
    # Set title
    if args.title:
        title = args.title
    else:
        # Extract info from filename
        basename = Path(args.datafile).stem
        title = f"{basename} (Verificarlo precision = {args.precision} bits)"
    
    fig.suptitle(title, fontsize=14)
    
    # Create subplots
    ax1 = plt.subplot(311)
    ax2 = plt.subplot(312)
    ax3 = plt.subplot(313)
    
    # Plot 1: Significant digits
    ax1.plot(x_values, s_values, 'o', markersize=4, color='blue')
    ax1.set_ylabel('Significant digits ($s$)', fontsize=12)
    ax1.grid(True, alpha=0.3)
    ax1.axhline(y=precision_decimal, color='red', linestyle='--', alpha=0.5, 
                label=f'Max precision ({precision_decimal:.1f})')
    ax1.legend()
    
    # Plot 2: Standard deviation
    if args.log_sigma and np.any(sigma_values > 0):
        ax2.semilogy(x_values, sigma_values, 'o', markersize=4, color='green')
        ax2.set_ylabel('Standard deviation ($\\hat{\\sigma}$) [log scale]', fontsize=12)
    else:
        ax2.plot(x_values, sigma_values, 'o', markersize=4, color='green')
        ax2.set_ylabel('Standard deviation ($\\hat{\\sigma}$)', fontsize=12)
    ax2.grid(True, alpha=0.3)
    
    # Plot 3: Samples and mean
    ax3.plot(data['x'], data['result'], 'k.', alpha=args.alpha, markersize=4, 
             label='Samples')
    ax3.plot(x_values, mu_values, 'r-', linewidth=2, label='Mean ($\\hat{\\mu}$)')
    ax3.set_xlabel('$x$', fontsize=12)
    ax3.set_ylabel('Result values', fontsize=12)
    ax3.grid(True, alpha=0.3)
    ax3.legend()
    
    # Set x-axis limits if specified
    if args.xlim:
        for ax in [ax1, ax2, ax3]:
            ax.set_xlim(args.xlim)
    
    # Adjust layout
    plt.tight_layout()
    plt.subplots_adjust(top=0.94)
    
    return fig

def create_output_directory(args):
    """Create output directory structure"""
    # Create main plot directory
    plot_dir = Path(args.plot_dir)
    plot_dir.mkdir(exist_ok=True)
    
    # Create subdirectory based on input filename
    input_basename = Path(args.datafile).stem
    
    # Extract program name and parameters from filename
    # Expected format: program-method-type-vpX-mode.tab
    parts = input_basename.split('-')
    if len(parts) >= 2:
        program_name = parts[0]
        sub_dir = plot_dir / program_name
    else:
        sub_dir = plot_dir / input_basename
    
    sub_dir.mkdir(exist_ok=True)
    
    # Create timestamp subdirectory for this run
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = sub_dir / timestamp
    output_dir.mkdir(exist_ok=True)
    
    return output_dir

def save_plot(fig, args, output_dir):
    """Save the plot to file"""
    if args.output:
        output_file = output_dir / args.output
    else:
        # Generate output filename from input
        basename = Path(args.datafile).stem
        output_file = output_dir / f"{basename}-p{args.precision}.{args.format}"
    
    # Save with appropriate settings
    save_kwargs = {'format': args.format}
    if args.format in ['png', 'jpg']:
        save_kwargs['dpi'] = args.dpi
    
    fig.savefig(output_file, **save_kwargs)
    print(f"Plot saved to: {output_file}")
    
    # Also save a copy with descriptive name in the parent directory
    descriptive_file = output_file.parent.parent / f"latest_{output_file.name}"
    fig.savefig(descriptive_file, **save_kwargs)
    print(f"Latest copy saved to: {descriptive_file}")
    
    return output_file

def save_statistics(x_values, mu_values, sigma_values, s_values, output_dir, basename):
    """Save computed statistics to CSV file"""
    import csv
    
    stats_file = output_dir / f"{basename}_statistics.csv"
    
    with open(stats_file, 'w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['x', 'mean', 'std_dev', 'significant_digits'])
        
        for i in range(len(x_values)):
            writer.writerow([x_values[i], mu_values[i], sigma_values[i], s_values[i]])
    
    print(f"Statistics saved to: {stats_file}")
    return stats_file

def create_info_file(args, output_dir, x_values, mu_values, sigma_values, s_values):
    """Create an info file with analysis details"""
    info_file = output_dir / "analysis_info.txt"
    
    with open(info_file, 'w') as f:
        f.write("Verificarlo Analysis Information\n")
        f.write("=" * 40 + "\n\n")
        f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Input file: {args.datafile}\n")
        f.write(f"Precision: {args.precision} bits\n")
        f.write(f"Number of x values: {len(x_values)}\n")
        f.write(f"X range: [{x_values.min():.6f}, {x_values.max():.6f}]\n\n")
        
        f.write("Summary Statistics:\n")
        f.write(f"Mean significant digits: {s_values.mean():.2f}\n")
        f.write(f"Min significant digits: {s_values.min():.2f} at x={x_values[s_values.argmin()]:.6f}\n")
        f.write(f"Max significant digits: {s_values.max():.2f} at x={x_values[s_values.argmax()]:.6f}\n")
        
        if np.any(sigma_values > 0):
            max_sigma_idx = sigma_values.argmax()
            f.write(f"Most unstable point: x={x_values[max_sigma_idx]:.6f} (σ={sigma_values[max_sigma_idx]:.2e})\n")
    
    print(f"Info file saved to: {info_file}")
    return info_file

def print_summary(x_values, mu_values, sigma_values, s_values):
    """Print summary statistics"""
    print("\n=== Summary Statistics ===")
    print(f"Number of x values: {len(x_values)}")
    print(f"X range: [{x_values.min():.6f}, {x_values.max():.6f}]")
    print(f"Mean significant digits: {s_values.mean():.2f}")
    print(f"Min significant digits: {s_values.min():.2f} at x={x_values[s_values.argmin()]:.6f}")
    print(f"Max significant digits: {s_values.max():.2f} at x={x_values[s_values.argmax()]:.6f}")
    
    # Find most unstable point
    if np.any(sigma_values > 0):
        max_sigma_idx = sigma_values.argmax()
        print(f"Most unstable point: x={x_values[max_sigma_idx]:.6f} "
              f"(σ={sigma_values[max_sigma_idx]:.2e})")

def main():
    """Main function"""
    # Parse arguments
    args = parse_arguments()
    
    # Create output directory
    output_dir = create_output_directory(args)
    print(f"Output directory: {output_dir}")
    
    # Load data
    print(f"Loading data from: {args.datafile}")
    data = load_data(args.datafile)
    print(f"Loaded {len(data)} data points")
    
    # Compute statistics
    print("Computing statistics...")
    x_values, mu_values, sigma_values, s_values, precision_decimal = compute_statistics(
        data, args.precision)
    
    # Print summary
    print_summary(x_values, mu_values, sigma_values, s_values)
    
    # Create plot
    print("Creating plot...")
    fig = create_plot(data, x_values, mu_values, sigma_values, s_values, 
                     precision_decimal, args)
    
    # Save plot
    output_file = save_plot(fig, args, output_dir)
    
    # Save statistics if requested
    if args.save_data:
        basename = Path(args.datafile).stem
        save_statistics(x_values, mu_values, sigma_values, s_values, output_dir, basename)
    
    # Create info file
    create_info_file(args, output_dir, x_values, mu_values, sigma_values, s_values)
    
    # Show plot if requested
    if args.show:
        plt.show()
    
    print("\nDone!")

if __name__ == "__main__":
    main()
