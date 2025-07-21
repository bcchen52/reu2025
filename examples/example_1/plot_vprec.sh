#!/usr/bin/env python3
"""
Generalized plotting script for Verificarlo VPREC output
Plots results from deterministic VPREC backend runs
"""

import sys
import os
import numpy as np
import matplotlib
# Use Agg backend for headless runs
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import argparse
from pathlib import Path
from datetime import datetime

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Plot Verificarlo VPREC analysis results',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s data.tab binary32
  %(prog)s data.tab custom_p10 --title "10-bit Precision Analysis"
  %(prog)s data.tab bfloat16 --reference ref_data.tab
  %(prog)s data.tab custom_p8_r5 --plot-dir my_plots --format png
        """
    )
    
    parser.add_argument('datafile', 
                        help='Input data file (.tab format)')
    parser.add_argument('preset',
                        help='VPREC preset name (e.g., binary32, bfloat16, custom_p10)')
    parser.add_argument('--title', 
                        help='Custom plot title (default: auto-generated from filename)')
    parser.add_argument('--output', 
                        help='Output filename (default: auto-generated)')
    parser.add_argument('--plot-dir', default='vprec_plots',
                        help='Directory to save plots (default: ./vprec_plots)')
    parser.add_argument('--reference', 
                        help='Reference data file for comparison')
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
    parser.add_argument('--ylim', nargs=2, type=float,
                        help='Y-axis limits (default: auto)')
    parser.add_argument('--xlim', nargs=2, type=float,
                        help='X-axis limits (default: auto)')
    parser.add_argument('--log-y', action='store_true',
                        help='Use log scale for y-axis')
    parser.add_argument('--abs-error', action='store_true',
                        help='Plot absolute error if reference is provided')
    parser.add_argument('--rel-error', action='store_true',
                        help='Plot relative error if reference is provided')
    parser.add_argument('--save-data', action='store_true',
                        help='Save processed data to CSV file')
    
    args = parser.parse_args()
    
    # Validate input file
    if not os.path.exists(args.datafile):
        parser.error(f"Input file '{args.datafile}' not found")
    
    if args.reference and not os.path.exists(args.reference):
        parser.error(f"Reference file '{args.reference}' not found")
    
    return args

def load_data(filename):
    """Load and parse the data file"""
    try:
        # Try to load with headers
        data = np.loadtxt(filename, skiprows=1,
                         dtype=dict(names=('i', 'x', 'result'),
                                  formats=('i4', 'f8', 'f8')))
    except:
        try:
            data = np.loadtxt(filename,
                             dtype=dict(names=('i', 'x', 'result'),
                                      formats=('i4', 'f8', 'f8')))
        except Exception as e:
            print(f"Error loading data file: {e}")
            sys.exit(1)
    
    return data

def create_output_directory(args):
    """Create output directory structure"""
    plot_dir = Path(args.plot_dir)
    plot_dir.mkdir(exist_ok=True)
    
    # Extract program name from filename
    input_basename = Path(args.datafile).stem
    parts = input_basename.split('-')
    
    if len(parts) >= 2:
        program_name = parts[0]
        sub_dir = plot_dir / program_name
    else:
        sub_dir = plot_dir / input_basename
    
    sub_dir.mkdir(exist_ok=True)
    
    # Create timestamp subdirectory
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = sub_dir / f"vprec_{timestamp}"
    output_dir.mkdir(exist_ok=True)
    
    return output_dir

def compute_errors(x_values, test_values, ref_values):
    """Compute absolute and relative errors"""
    abs_errors = np.abs(test_values - ref_values)
    
    # Compute relative errors, avoiding division by zero
    rel_errors = np.zeros_like(abs_errors)
    mask = ref_values != 0
    rel_errors[mask] = abs_errors[mask] / np.abs(ref_values[mask])
    
    return abs_errors, rel_errors

def create_plot(data, args, reference_data=None):
    """Create the plot based on data and options"""
    
    # Set style if specified
    if args.style != 'default':
        try:
            plt.style.use(args.style)
        except:
            print(f"Warning: Style '{args.style}' not found, using default")
    
    # Extract x and result values
    x_values = data['x']
    result_values = data['result']
    
    # Create figure
    fig = plt.figure(figsize=args.figsize)
    
    # Set title
    if args.title:
        title = args.title
    else:
        basename = Path(args.datafile).stem
        title = f"{basename} (VPREC: {args.preset})"
    
    # Determine number of subplots
    n_plots = 1
    if reference_data is not None and (args.abs_error or args.rel_error):
        n_plots += 1 if args.abs_error else 0
        n_plots += 1 if args.rel_error else 0
    
    plot_idx = 1
    
    # Main result plot
    ax1 = plt.subplot(n_plots, 1, plot_idx)
    plot_idx += 1
    
    ax1.plot(x_values, result_values, 'b.', markersize=4, label=f'VPREC {args.preset}')
    
    # Add reference if provided
    if reference_data is not None:
        ref_x = reference_data['x']
        ref_results = reference_data['result']
        ax1.plot(ref_x, ref_results, 'r-', linewidth=1, alpha=0.7, label='Reference')
        ax1.legend()
    
    ax1.set_ylabel('Result values', fontsize=12)
    if n_plots == 1:
        ax1.set_xlabel('$x$', fontsize=12)
    ax1.grid(True, alpha=0.3)
    
    if args.log_y:
        ax1.set_yscale('log')
    
    if args.ylim:
        ax1.set_ylim(args.ylim)
    if args.xlim:
        ax1.set_xlim(args.xlim)
    
    # Error plots if reference is provided
    if reference_data is not None:
        # Interpolate reference data to match test points
        ref_interp = np.interp(x_values, reference_data['x'], reference_data['result'])
        abs_errors, rel_errors = compute_errors(x_values, result_values, ref_interp)
        
        if args.abs_error:
            ax2 = plt.subplot(n_plots, 1, plot_idx)
            plot_idx += 1
            ax2.semilogy(x_values, abs_errors, 'g.', markersize=4)
            ax2.set_ylabel('Absolute Error', fontsize=12)
            ax2.grid(True, alpha=0.3)
            if args.xlim:
                ax2.set_xlim(args.xlim)
            if plot_idx <= n_plots:
                ax2.set_xticklabels([])
        
        if args.rel_error:
            ax3 = plt.subplot(n_plots, 1, plot_idx)
            ax3.semilogy(x_values, rel_errors, 'm.', markersize=4)
            ax3.set_ylabel('Relative Error', fontsize=12)
            ax3.set_xlabel('$x$', fontsize=12)
            ax3.grid(True, alpha=0.3)
            if args.xlim:
                ax3.set_xlim(args.xlim)
    
    fig.suptitle(title, fontsize=14)
    plt.tight_layout()
    plt.subplots_adjust(top=0.94)
    
    return fig

def save_plot(fig, args, output_dir):
    """Save the plot to file"""
    if args.output:
        output_file = output_dir / args.output
    else:
        basename = Path(args.datafile).stem
        output_file = output_dir / f"{basename}-vprec.{args.format}"
    
    save_kwargs = {'format': args.format}
    if args.format in ['png', 'jpg']:
        save_kwargs['dpi'] = args.dpi
    
    fig.savefig(output_file, **save_kwargs)
    print(f"Plot saved to: {output_file}")
    
    # Save latest copy
    latest_file = output_file.parent.parent / f"latest_{output_file.name}"
    fig.savefig(latest_file, **save_kwargs)
    print(f"Latest copy saved to: {latest_file}")
    
    return output_file

def save_analysis_data(data, output_dir, basename, reference_data=None):
    """Save analysis data to CSV file"""
    import csv
    
    csv_file = output_dir / f"{basename}_vprec_data.csv"
    
    with open(csv_file, 'w', newline='') as csvfile:
        if reference_data is not None:
            # Interpolate reference for error calculation
            ref_interp = np.interp(data['x'], reference_data['x'], reference_data['result'])
            abs_errors, rel_errors = compute_errors(data['x'], data['result'], ref_interp)
            
            writer = csv.writer(csvfile)
            writer.writerow(['x', 'vprec_result', 'reference', 'abs_error', 'rel_error'])
            
            for i in range(len(data)):
                writer.writerow([data['x'][i], data['result'][i], ref_interp[i], 
                               abs_errors[i], rel_errors[i]])
        else:
            writer = csv.writer(csvfile)
            writer.writerow(['x', 'vprec_result'])
            
            for i in range(len(data)):
                writer.writerow([data['x'][i], data['result'][i]])
    
    print(f"Data saved to: {csv_file}")
    return csv_file

def create_info_file(args, output_dir, data, reference_data=None):
    """Create an info file with analysis details"""
    info_file = output_dir / "vprec_analysis_info.txt"
    
    with open(info_file, 'w') as f:
        f.write("Verificarlo VPREC Analysis Information\n")
        f.write("=" * 40 + "\n\n")
        f.write(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Input file: {args.datafile}\n")
        f.write(f"VPREC preset: {args.preset}\n")
        f.write(f"Number of test points: {len(data)}\n")
        f.write(f"X range: [{data['x'].min():.6f}, {data['x'].max():.6f}]\n\n")
        
        f.write("Result Statistics:\n")
        f.write(f"Min result: {data['result'].min():.6e}\n")
        f.write(f"Max result: {data['result'].max():.6e}\n")
        f.write(f"Mean result: {data['result'].mean():.6e}\n")
        
        if reference_data is not None:
            ref_interp = np.interp(data['x'], reference_data['x'], reference_data['result'])
            abs_errors, rel_errors = compute_errors(data['x'], data['result'], ref_interp)
            
            f.write("\nError Statistics (vs reference):\n")
            f.write(f"Max absolute error: {abs_errors.max():.6e}\n")
            f.write(f"Mean absolute error: {abs_errors.mean():.6e}\n")
            f.write(f"Max relative error: {rel_errors.max():.6e}\n")
            f.write(f"Mean relative error: {rel_errors.mean():.6e}\n")
    
    print(f"Info file saved to: {info_file}")
    return info_file

def print_summary(data, args, reference_data=None):
    """Print summary statistics"""
    print("\n=== VPREC Analysis Summary ===")
    print(f"Preset: {args.preset}")
    print(f"Number of points: {len(data)}")
    print(f"X range: [{data['x'].min():.6f}, {data['x'].max():.6f}]")
    print(f"Result range: [{data['result'].min():.6e}, {data['result'].max():.6e}]")
    
    if reference_data is not None:
        ref_interp = np.interp(data['x'], reference_data['x'], reference_data['result'])
        abs_errors, rel_errors = compute_errors(data['x'], data['result'], ref_interp)
        print(f"\nMax absolute error: {abs_errors.max():.6e}")
        print(f"Max relative error: {rel_errors.max():.6e}")

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
    
    # Load reference data if provided
    reference_data = None
    if args.reference:
        print(f"Loading reference data from: {args.reference}")
        reference_data = load_data(args.reference)
        print(f"Loaded {len(reference_data)} reference points")
    
    # Print summary
    print_summary(data, args, reference_data)
    
    # Create plot
    print("Creating plot...")
    fig = create_plot(data, args, reference_data)
    
    # Save plot
    output_file = save_plot(fig, args, output_dir)
    
    # Save data if requested
    if args.save_data:
        basename = Path(args.datafile).stem
        save_analysis_data(data, output_dir, basename, reference_data)
    
    # Create info file
    create_info_file(args, output_dir, data, reference_data)
    
    # Show plot if requested
    if args.show:
        plt.show()
    
    print("\nDone!")

if __name__ == "__main__":
    main()
