#!/usr/bin/env python3
"""
Plotting script for Verificarlo multi-input analysis results
Handles 1, 2, or 3 input variables with various visualization options
"""

import sys
import os
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import argparse
from pathlib import Path
from datetime import datetime

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Plot Verificarlo multi-input analysis results',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic 1-variable plot
  %(prog)s results/softmax-3inputs-grid-DOUBLE-vp53-mca.tab 53
  
  # 2D heatmap for 2 varying inputs
  %(prog)s results/data-3inputs-grid.tab 53 --plot-type heatmap
  
  # Show statistics for specific input combination
  %(prog)s results/data.tab 53 --filter "x1=0.0,x2=0.0"
  
  # Compare multiple precision levels
  %(prog)s results/data.tab 53 --compare results/data-vp24.tab
        """
    )
    
    parser.add_argument('datafile', 
                        help='Input data file (.tab format)')
    parser.add_argument('precision', type=int,
                        help='Verificarlo precision in bits')
    parser.add_argument('--plot-type', default='auto',
                        choices=['auto', 'line', 'scatter', 'heatmap', '3d', 'stats'],
                        help='Type of plot (default: auto-detect based on data)')
    parser.add_argument('--filter', 
                        help='Filter data by fixed values (e.g., "x1=0.0,x2=1.0")')
    parser.add_argument('--compare', 
                        help='Compare with another data file')
    parser.add_argument('--output', 
                        help='Output filename (default: auto-generated)')
    parser.add_argument('--plot-dir', default='plots',
                        help='Directory to save plots (default: ./plots)')
    parser.add_argument('--format', default='pdf', 
                        choices=['pdf', 'png', 'svg', 'eps'],
                        help='Output format (default: pdf)')
    parser.add_argument('--dpi', type=int, default=300,
                        help='DPI for raster formats (default: 300)')
    parser.add_argument('--figsize', nargs=2, type=float, default=[10, 8],
                        help='Figure size in inches (default: 10 8)')
    parser.add_argument('--show', action='store_true',
                        help='Display plot interactively')
    parser.add_argument('--save-stats', action='store_true',
                        help='Save statistics to CSV file')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.datafile):
        parser.error(f"Input file '{args.datafile}' not found")
    
    return args

def detect_input_count(filename):
    """Detect number of inputs and which ones are varying"""
    # First, detect total number of input columns
    with open(filename, 'r') as f:
        header = f.readline().strip()
        if header.startswith('i x'):
            # Count x columns in header
            total_inputs = header.count(' x')
        else:
            # Try to detect from first data line
            f.seek(0)
            f.readline()  # Skip header if any
            first_line = f.readline().strip().split()
            # Assume format: i x0 [x1] [x2] result
            total_inputs = len(first_line) - 2  # subtract i and result
    
    # Now detect which inputs are actually varying
    data = np.loadtxt(filename, skiprows=1)
    if data.ndim == 1:
        data = data.reshape(1, -1)
    
    # Check which columns have varying values
    varying_inputs = []
    if total_inputs >= 1:
        x0_values = np.unique(data[:, 1])  # x0 is column 1
        if len(x0_values) > 1:
            varying_inputs.append('x0')
    
    if total_inputs >= 2:
        x1_values = np.unique(data[:, 2])  # x1 is column 2
        if len(x1_values) > 1:
            varying_inputs.append('x1')
    
    if total_inputs >= 3:
        x2_values = np.unique(data[:, 3])  # x2 is column 3
        if len(x2_values) > 1:
            varying_inputs.append('x2')
    
    # Return both total inputs and number of varying inputs
    return total_inputs, len(varying_inputs), varying_inputs

def load_data(filename):
    """Load and parse the multi-input data file"""
    # Detect number of inputs and which are varying
    n_inputs, n_varying, varying_inputs = detect_input_count(filename)
    
    print(f"Total inputs: {n_inputs}, Varying inputs: {n_varying} ({', '.join(varying_inputs)})")
    
    # Define column names based on total input count
    if n_inputs == 1:
        names = ('i', 'x0', 'result')
        formats = ('i4', 'f8', 'f8')
    elif n_inputs == 2:
        names = ('i', 'x0', 'x1', 'result')
        formats = ('i4', 'f8', 'f8', 'f8')
    else:  # 3 inputs
        names = ('i', 'x0', 'x1', 'x2', 'result')
        formats = ('i4', 'f8', 'f8', 'f8', 'f8')
    
    try:
        data = np.loadtxt(filename, skiprows=1,
                          dtype=dict(names=names, formats=formats))
        return data, n_inputs, n_varying, varying_inputs
    except Exception as e:
        print(f"Error loading data: {e}")
        sys.exit(1)

def filter_data(data, filter_str, n_inputs):
    """Filter data based on fixed values"""
    if not filter_str:
        return data
    
    # Parse filter string
    filters = {}
    for pair in filter_str.split(','):
        var, val = pair.strip().split('=')
        filters[var] = float(val)
    
    # Apply filters
    mask = np.ones(len(data), dtype=bool)
    for var, val in filters.items():
        if var in data.dtype.names:
            mask &= np.abs(data[var] - val) < 1e-10
    
    return data[mask]

def compute_statistics(data, n_inputs, precision_bits=53):
    """Compute statistics for each unique input combination"""
    results = data['result']
    
    # Calculate maximum significant digits based on precision
    max_sig_digits = precision_bits * np.log10(2)
    
    # Get unique input combinations
    if n_inputs == 1:
        unique_inputs = np.unique(data['x0'])
        stats = []
        for x0 in unique_inputs:
            mask = data['x0'] == x0
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
            
            stats.append({
                'x0': x0,
                'mean': mean_val,
                'std': std_val,
                'min': np.min(values),
                'max': np.max(values),
                'count': len(values),
                'sig_digits': sig_digits
            })
    elif n_inputs == 2:
        unique_x0 = np.unique(data['x0'])
        unique_x1 = np.unique(data['x1'])
        stats = []
        for x0 in unique_x0:
            for x1 in unique_x1:
                mask = (data['x0'] == x0) & (data['x1'] == x1)
                if np.any(mask):
                    values = results[mask]
                    mean_val = np.mean(values)
                    std_val = np.std(values)
                    
                    # Compute significant digits with proper bounds
                    if std_val < 1e-15 or std_val == 0:
                        sig_digits = max_sig_digits
                    elif mean_val == 0:
                        sig_digits = 0
                    else:
                        sig_digits = min(-np.log10(std_val/abs(mean_val)), max_sig_digits)
                    
                    stats.append({
                        'x0': x0, 'x1': x1,
                        'mean': mean_val,
                        'std': std_val,
                        'min': np.min(values),
                        'max': np.max(values),
                        'count': len(values),
                        'sig_digits': sig_digits
                    })
    else:  # 3 inputs
        unique_x0 = np.unique(data['x0'])
        unique_x1 = np.unique(data['x1'])
        unique_x2 = np.unique(data['x2'])
        stats = []
        for x0 in unique_x0:
            for x1 in unique_x1:
                for x2 in unique_x2:
                    mask = (data['x0'] == x0) & (data['x1'] == x1) & (data['x2'] == x2)
                    if np.any(mask):
                        values = results[mask]
                        mean_val = np.mean(values)
                        std_val = np.std(values)
                        
                        # Compute significant digits with proper bounds
                        if std_val < 1e-15 or std_val == 0:
                            sig_digits = max_sig_digits
                        elif mean_val == 0:
                            sig_digits = 0
                        else:
                            sig_digits = min(-np.log10(std_val/abs(mean_val)), max_sig_digits)
                        
                        stats.append({
                            'x0': x0, 'x1': x1, 'x2': x2,
                            'mean': mean_val,
                            'std': std_val,
                            'min': np.min(values),
                            'max': np.max(values),
                            'count': len(values),
                            'sig_digits': sig_digits
                        })
    
    return stats

def plot_1d_data(data, stats, args, varying_input='x0'):
    """Create plots for 1D data"""
    fig, axes = plt.subplots(3, 1, figsize=args.figsize, sharex=True)
    
    # Get the appropriate x values based on which input is varying
    x_values = np.array([s[varying_input] for s in stats])
    means = np.array([s['mean'] for s in stats])
    stds = np.array([s['std'] for s in stats])
    sig_digits = np.array([s['sig_digits'] for s in stats])
    
    # Convert binary to decimal precision
    precision_decimal = float(args.precision) * np.log10(2)
    
    # Plot 1: Mean values with error bars
    ax1 = axes[0]
    # For large datasets, use line plot instead of individual error bars
    if len(x_values) > 100:
        ax1.plot(x_values, means, 'b-', linewidth=1.5, label='Mean')
        # Add shaded region for standard deviation
        ax1.fill_between(x_values, means - stds, means + stds, 
                        alpha=0.3, color='blue', label='±1 std')
        ax1.legend()
    else:
        ax1.errorbar(x_values, means, yerr=stds, fmt='o-', capsize=5, markersize=4)
    
    ax1.set_ylabel('Mean value')
    ax1.grid(True, alpha=0.3)
    ax1.set_title('Mean values', fontsize=10)
    
    # Plot 2: Standard deviation
    ax2 = axes[1]
    # Determine if we need log scale
    if stds.max() > 0 and stds.max() / stds[stds > 0].min() > 100:
        ax2.semilogy(x_values, stds, 'g-', linewidth=1.5)
        ax2.set_ylim(stds[stds > 0].min() * 0.5, stds.max() * 2)
    else:
        ax2.plot(x_values, stds, 'g-', linewidth=1.5)
    
    ax2.set_ylabel('Std deviation')
    ax2.grid(True, alpha=0.3)
    ax2.set_title('Standard deviation', fontsize=10)
    
    # Plot 3: Significant digits
    ax3 = axes[2]
    ax3.plot(x_values, sig_digits, 'b-', linewidth=1.5)
    ax3.axhline(y=precision_decimal, color='red', linestyle='--', alpha=0.5, 
                label=f'Max precision ({precision_decimal:.1f})')
    ax3.set_ylabel('Significant digits')
    ax3.set_xlabel(varying_input)
    ax3.grid(True, alpha=0.3)
    ax3.set_title('Significant digits', fontsize=10)
    ax3.legend()
    
    # Set y-limits for significant digits with some padding
    y_min = max(0, sig_digits.min() - 0.5)
    y_max = min(precision_decimal * 1.1, sig_digits.max() + 0.5)
    ax3.set_ylim(y_min, y_max)
    
    # Set x-limits to data range
    ax3.set_xlim(x_values.min(), x_values.max())
    
    plt.tight_layout(pad=2.5)
    return fig

def plot_2d_heatmap(data, stats, n_inputs, args):
    """Create heatmap for 2D data"""
    if n_inputs == 2:
        # 2 varying inputs
        unique_x0 = sorted(list(set(s['x0'] for s in stats)))
        unique_x1 = sorted(list(set(s['x1'] for s in stats)))
    else:
        # 3 inputs but one must be fixed
        if len(set(s.get('x2', 0) for s in stats)) == 1:
            # x2 is fixed
            unique_x0 = sorted(list(set(s['x0'] for s in stats)))
            unique_x1 = sorted(list(set(s['x1'] for s in stats)))
        elif len(set(s.get('x1', 0) for s in stats)) == 1:
            # x1 is fixed
            unique_x0 = sorted(list(set(s['x0'] for s in stats)))
            unique_x1 = sorted(list(set(s['x2'] for s in stats)))
        else:
            # x0 is fixed
            unique_x0 = sorted(list(set(s['x1'] for s in stats)))
            unique_x1 = sorted(list(set(s['x2'] for s in stats)))
    
    # Create matrices for mean, std, and significant digits
    mean_matrix = np.zeros((len(unique_x1), len(unique_x0)))
    std_matrix = np.zeros((len(unique_x1), len(unique_x0)))
    sig_digits_matrix = np.zeros((len(unique_x1), len(unique_x0)))
    
    for s in stats:
        if n_inputs == 2:
            i = unique_x0.index(s['x0'])
            j = unique_x1.index(s['x1'])
        else:
            # Map based on which variable is fixed
            if len(set(s.get('x2', 0) for s in stats)) == 1:
                i = unique_x0.index(s['x0'])
                j = unique_x1.index(s['x1'])
            elif len(set(s.get('x1', 0) for s in stats)) == 1:
                i = unique_x0.index(s['x0'])
                j = unique_x1.index(s['x2'])
            else:
                i = unique_x0.index(s['x1'])
                j = unique_x1.index(s['x2'])
        
        mean_matrix[j, i] = s['mean']
        std_matrix[j, i] = s['std']
        sig_digits_matrix[j, i] = s['sig_digits']
    
    # Create figure with subplots
    fig, axes = plt.subplots(1, 3, figsize=(args.figsize[0]*2, args.figsize[1]*0.8))
    
    # Mean heatmap
    im1 = axes[0].imshow(mean_matrix, aspect='auto', origin='lower',
                         extent=[unique_x0[0], unique_x0[-1], unique_x1[0], unique_x1[-1]])
    axes[0].set_xlabel('x0')
    axes[0].set_ylabel('x1')
    axes[0].set_title('Mean values', fontsize=10)
    plt.colorbar(im1, ax=axes[0])
    
    # Std heatmap (log scale)
    std_log = np.log10(std_matrix + 1e-16)  # Avoid log(0)
    im2 = axes[1].imshow(std_log, aspect='auto', origin='lower',
                         extent=[unique_x0[0], unique_x0[-1], unique_x1[0], unique_x1[-1]])
    axes[1].set_xlabel('x0')
    axes[1].set_ylabel('x1')
    axes[1].set_title('Log10(Std deviation)', fontsize=10)
    plt.colorbar(im2, ax=axes[1])
    
    # Significant digits heatmap
    im3 = axes[2].imshow(sig_digits_matrix, aspect='auto', origin='lower',
                         extent=[unique_x0[0], unique_x0[-1], unique_x1[0], unique_x1[-1]],
                         cmap='viridis')
    axes[2].set_xlabel('x0')
    axes[2].set_ylabel('x1')
    axes[2].set_title('Significant digits', fontsize=10)
    cbar = plt.colorbar(im3, ax=axes[2])
    
    # Set color scale for significant digits
    precision_decimal = float(args.precision) * np.log10(2)
    im3.set_clim(0, precision_decimal)
    
    plt.tight_layout(pad=2.5)
    return fig

def plot_statistics_summary(stats, n_inputs, args):
    """Create a summary statistics plot"""
    fig = plt.figure(figsize=(args.figsize[0]*1.2, args.figsize[1]))
    
    # Extract statistics
    means = [s['mean'] for s in stats]
    stds = [s['std'] for s in stats]
    sig_digits = [s['sig_digits'] for s in stats]
    
    # Convert binary to decimal precision
    precision_decimal = float(args.precision) * np.log10(2)
    
    # Create subplots - now 2x3 grid to include significant digits
    ax1 = plt.subplot(231)
    ax1.hist(means, bins=50, alpha=0.7, color='blue')
    ax1.set_xlabel('Mean values')
    ax1.set_ylabel('Count')
    ax1.set_title('Distribution of means', fontsize=10)
    
    ax2 = plt.subplot(232)
    if any(std > 0 for std in stds):
        ax2.hist(np.log10(np.array(stds) + 1e-16), bins=50, alpha=0.7, color='green')
        ax2.set_xlabel('Log10(Std deviation)')
    else:
        ax2.hist(stds, bins=50, alpha=0.7, color='green')
        ax2.set_xlabel('Std deviation')
    ax2.set_ylabel('Count')
    ax2.set_title('Distribution of std deviations', fontsize=10)
    
    ax3 = plt.subplot(233)
    ax3.hist(sig_digits, bins=50, alpha=0.7, color='purple')
    ax3.set_xlabel('Significant digits')
    ax3.set_ylabel('Count')
    ax3.set_title('Distribution of significant digits', fontsize=10)
    ax3.axvline(x=precision_decimal, color='red', linestyle='--', alpha=0.5)
    
    ax4 = plt.subplot(234)
    ax4.scatter(means, stds, alpha=0.5)
    ax4.set_xlabel('Mean')
    ax4.set_ylabel('Std deviation')
    if any(std > 0 for std in stds):
        ax4.set_yscale('log')
    ax4.set_title('Mean vs Std deviation', fontsize=10)
    
    ax5 = plt.subplot(235)
    # Compute relative errors
    rel_errors = []
    for s in stats:
        if s['mean'] != 0:
            rel_errors.append(s['std'] / abs(s['mean']))
    
    if rel_errors:
        ax5.hist(np.log10(np.array(rel_errors) + 1e-16), bins=50, alpha=0.7, color='red')
        ax5.set_xlabel('Log10(Relative error)')
        ax5.set_ylabel('Count')
        ax5.set_title('Distribution of relative errors', fontsize=10)
    
    ax6 = plt.subplot(236)
    ax6.scatter(means, sig_digits, alpha=0.5, color='orange')
    ax6.set_xlabel('Mean')
    ax6.set_ylabel('Significant digits')
    ax6.set_title('Mean vs Significant digits', fontsize=10)
    ax6.axhline(y=precision_decimal, color='red', linestyle='--', alpha=0.5)
    ax6.set_ylim(0, precision_decimal * 1.1)
    
    plt.tight_layout(pad=2.5)
    return fig


def plot_3d_significant_digits(stats, args):
    """Create 3D visualization of significant digits for 3 varying inputs"""
    from mpl_toolkits.mplot3d import Axes3D
    import matplotlib.cm as cm
    
    # Extract data
    x0_vals = np.array([s['x0'] for s in stats])
    x1_vals = np.array([s['x1'] for s in stats])
    x2_vals = np.array([s['x2'] for s in stats])
    sig_digits = np.array([s['sig_digits'] for s in stats])
    
    # Create figure
    fig = plt.figure(figsize=(12, 10))
    
    # Convert binary to decimal precision
    precision_decimal = float(args.precision) * np.log10(2)
    
    # Create 4 subplots: 3 2D slices and 1 3D scatter
    # Subplot 1: 3D scatter plot
    ax1 = fig.add_subplot(221, projection='3d')
    
    # Color map based on significant digits
    colors = cm.viridis(sig_digits / precision_decimal)
    scatter = ax1.scatter(x0_vals, x1_vals, x2_vals, c=sig_digits, 
                         cmap='viridis', s=20, alpha=0.6,
                         vmin=0, vmax=precision_decimal)
    
    ax1.set_xlabel('x0')
    ax1.set_ylabel('x1')
    ax1.set_zlabel('x2')
    ax1.set_title('3D Scatter: Significant Digits', fontsize=10)
    
    # Add colorbar
    cbar = plt.colorbar(scatter, ax=ax1, pad=0.1)
    cbar.set_label('Significant Digits')
    
    # Subplot 2: x0-x1 plane (average over x2)
    ax2 = fig.add_subplot(222)
    unique_x0 = np.unique(x0_vals)
    unique_x1 = np.unique(x1_vals)
    
    # Create grid for heatmap
    sig_grid_01 = np.zeros((len(unique_x1), len(unique_x0)))
    count_grid = np.zeros((len(unique_x1), len(unique_x0)))
    
    for s in stats:
        i = np.where(unique_x0 == s['x0'])[0][0]
        j = np.where(unique_x1 == s['x1'])[0][0]
        sig_grid_01[j, i] += s['sig_digits']
        count_grid[j, i] += 1
    
    # Average where we have data
    mask = count_grid > 0
    sig_grid_01[mask] /= count_grid[mask]
    
    im2 = ax2.imshow(sig_grid_01, aspect='auto', origin='lower',
                     extent=[unique_x0.min(), unique_x0.max(), 
                            unique_x1.min(), unique_x1.max()],
                     cmap='viridis', vmin=0, vmax=precision_decimal)
    ax2.set_xlabel('x0')
    ax2.set_ylabel('x1')
    ax2.set_title('Avg Significant Digits (x0-x1 plane)', fontsize=10)
    plt.colorbar(im2, ax=ax2)
    
    # Subplot 3: x0-x2 plane (average over x1)
    ax3 = fig.add_subplot(223)
    unique_x2 = np.unique(x2_vals)
    
    sig_grid_02 = np.zeros((len(unique_x2), len(unique_x0)))
    count_grid = np.zeros((len(unique_x2), len(unique_x0)))
    
    for s in stats:
        i = np.where(unique_x0 == s['x0'])[0][0]
        j = np.where(unique_x2 == s['x2'])[0][0]
        sig_grid_02[j, i] += s['sig_digits']
        count_grid[j, i] += 1
    
    mask = count_grid > 0
    sig_grid_02[mask] /= count_grid[mask]
    
    im3 = ax3.imshow(sig_grid_02, aspect='auto', origin='lower',
                     extent=[unique_x0.min(), unique_x0.max(), 
                            unique_x2.min(), unique_x2.max()],
                     cmap='viridis', vmin=0, vmax=precision_decimal)
    ax3.set_xlabel('x0')
    ax3.set_ylabel('x2')
    ax3.set_title('Avg Significant Digits (x0-x2 plane)', fontsize=10)
    plt.colorbar(im3, ax=ax3)
    
    # Subplot 4: x1-x2 plane (average over x0)
    ax4 = fig.add_subplot(224)
    
    sig_grid_12 = np.zeros((len(unique_x2), len(unique_x1)))
    count_grid = np.zeros((len(unique_x2), len(unique_x1)))
    
    for s in stats:
        i = np.where(unique_x1 == s['x1'])[0][0]
        j = np.where(unique_x2 == s['x2'])[0][0]
        sig_grid_12[j, i] += s['sig_digits']
        count_grid[j, i] += 1
    
    mask = count_grid > 0
    sig_grid_12[mask] /= count_grid[mask]
    
    im4 = ax4.imshow(sig_grid_12, aspect='auto', origin='lower',
                     extent=[unique_x1.min(), unique_x1.max(), 
                            unique_x2.min(), unique_x2.max()],
                     cmap='viridis', vmin=0, vmax=precision_decimal)
    ax4.set_xlabel('x1')
    ax4.set_ylabel('x2')
    ax4.set_title('Avg Significant Digits (x1-x2 plane)', fontsize=10)
    plt.colorbar(im4, ax=ax4)
    
    plt.tight_layout(pad=2.5)
    return fig

def create_output_directory(args):
    """Create output directory structure"""
    plot_dir = Path(args.plot_dir)
    plot_dir.mkdir(exist_ok=True)
    
    basename = Path(args.datafile).stem
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = plot_dir / f"{basename}_{timestamp}"
    output_dir.mkdir(exist_ok=True)
    
    return output_dir

def save_statistics(stats, output_dir, basename):
    """Save statistics to CSV file"""
    import csv
    
    csv_file = output_dir / f"{basename}_statistics.csv"
    
    with open(csv_file, 'w', newline='') as f:
        if stats:
            writer = csv.DictWriter(f, fieldnames=stats[0].keys())
            writer.writeheader()
            writer.writerows(stats)
    
    print(f"Statistics saved to: {csv_file}")

def main():
    """Main function"""
    args = parse_arguments()
    
    # Load data
    print(f"Loading data from: {args.datafile}")
    data, n_inputs, n_varying, varying_inputs = load_data(args.datafile)
    print(f"Loaded {len(data)} data points")
    
    # Apply filters if specified
    if args.filter:
        data = filter_data(data, args.filter, n_inputs)
        print(f"After filtering: {len(data)} data points")
    
    # Compute statistics
    print("Computing statistics...")
    stats = compute_statistics(data, n_inputs, args.precision)
    print(f"Computed statistics for {len(stats)} unique input combinations")
    
    # Create output directory
    output_dir = create_output_directory(args)
    print(f"Output directory: {output_dir}")
    
    # Determine plot type based on varying inputs
    if args.plot_type == 'auto':
        if n_varying == 1:
            plot_type = 'line'
        elif n_varying == 2:
            plot_type = 'heatmap'
        else:
            plot_type = 'stats'
    else:
        plot_type = args.plot_type
    
    # Create plots
    print(f"Creating {plot_type} plot for {n_varying} varying input(s)...")
    
    if plot_type == 'line' and n_varying == 1:
        # Determine which input is varying
        varying_input = varying_inputs[0] if varying_inputs else 'x0'
        fig = plot_1d_data(data, stats, args, varying_input)
    elif plot_type == 'heatmap' and n_varying == 2:
        fig = plot_2d_heatmap(data, stats, n_inputs, args)
    elif plot_type == 'stats':
        fig = plot_statistics_summary(stats, n_inputs, args)
    else:
        print(f"Warning: {plot_type} plot not suitable for {n_varying} varying input(s)")
        fig = plot_statistics_summary(stats, n_inputs, args)
    
    # Add title
    basename = Path(args.datafile).stem
    fig.suptitle(f"{basename} (Precision: {args.precision} bits)", fontsize=13)
    
    # Save plot
    if args.output:
        output_file = output_dir / args.output
    else:
        output_file = output_dir / f"{basename}_plot.{args.format}"
    
    fig.savefig(output_file, format=args.format, dpi=args.dpi)
    print(f"Plot saved to: {output_file}")
    
    # Create additional 3D plot if all 3 inputs are varying
    if n_varying == 3 and n_inputs == 3:
        print("Creating 3D significant digits visualization...")
        fig_3d = plot_3d_significant_digits(stats, args)
        
        # Save 3D plot
        output_file_3d = output_dir / f"{basename}_3d_sigdigits.{args.format}"
        fig_3d.savefig(output_file_3d, format=args.format, dpi=args.dpi)
        print(f"3D plot saved to: {output_file_3d}")
    
    # Save statistics if requested
    if args.save_stats:
        save_statistics(stats, output_dir, basename)
    
    # Show plot if requested
    if args.show:
        plt.show()
    
    print("\nDone!")

if __name__ == "__main__":
    main()
