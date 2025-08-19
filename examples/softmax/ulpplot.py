#!/usr/bin/env python3
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from scipy.interpolate import griddata
import argparse
from mpl_toolkits.axes_grid1 import make_axes_locatable # <-- 1. ADDED IMPORT

def create_clean_heatmap(filepath, x_col='x0', y_col='x1', z_col='ulp_error',
                        resolution=200, title=None, save_path=None, figsize=(8, 8),
                        use_log=False, method='linear', interpolation='nearest'):
    """
    Create a clean, simple heatmap from CSV file matching the reference style.

    Parameters:
    -----------
    filepath : str
        Path to the CSV file
    x_col : str
        Column name for X axis (default: 'x0')
    y_col : str
        Column name for Y axis (default: 'x1')
    z_col : str
        Column name for values to plot (default: 'ulp_error')
    resolution : int
        Grid resolution for interpolation (default: 200)
    title : str
        Optional title for the plot
    save_path : str
        Optional path to save the figure
    figsize : tuple
        Figure size (width, height) in inches
    use_log : bool
        Whether to use log10 scale for the values (default: False)
    method : str
        Interpolation method for griddata: 'linear', 'nearest', 'cubic' (default: 'linear')
    interpolation : str
        Interpolation method for imshow: 'nearest', 'bilinear', 'bicubic', etc. (default: 'nearest')
    """
    # Load data
    df = pd.read_csv(filepath)
    print(f"Loaded {len(df)} rows from {filepath}")

    # Extract data
    x = df[x_col].values
    y = df[y_col].values
    z = df[z_col].values

    # Print statistics
    print(f"\n{z_col} statistics:")
    print(f"Min: {z.min():.2e}")
    print(f"Max: {z.max():.2e}")
    print(f"Mean: {z.mean():.2e}")

    # Create grid for interpolation
    xi = np.linspace(x.min(), x.max(), resolution)
    yi = np.linspace(y.min(), y.max(), resolution)
    xi, yi = np.meshgrid(xi, yi)

    # Interpolate the data
    zi = griddata((x, y), z, (xi, yi), method=method, fill_value=np.nan)

    # Create the figure
    fig, ax = plt.subplots(figsize=figsize)

    # Apply log scale if requested
    if use_log:
        # Use log10 scale, handling zeros and negative values
        zi_plot = np.log10(np.maximum(zi, 1e-16))
        colorbar_label = f'Log10(Error in ULPs)'
    else:
        # Use the data as-is without log scale
        zi_plot = zi
        colorbar_label = 'Error in ULPs'

    # Create the heatmap
    im = ax.imshow(zi_plot,
                    extent=[x.min(), x.max(), y.min(), y.max()],
                    origin='lower',
                    aspect='equal',
                    cmap='viridis',
                    interpolation=interpolation)

    # --- 2. MODIFIED CODE BLOCK FOR COLOR BAR ---
    # Create a divider for the existing axes
    divider = make_axes_locatable(ax)
    # Append a new axis to the right of the main plot axis for the colorbar
    cax = divider.append_axes("right", size="5%", pad=0.1)
    # Create the color bar on the new axis
    cbar = fig.colorbar(im, cax=cax)
    cbar.set_label(colorbar_label, fontsize=12)
    # --- END OF MODIFIED BLOCK ---

    # Set labels
    ax.set_xlabel(x_col)
    ax.set_ylabel(y_col)

    # Set title if provided
    if title:
        ax.set_title(title) # Corrected this from your original script too

    # Set axis limits
    ax.set_xlim(x.min(), x.max())
    ax.set_ylim(y.min(), y.max())

    # Save if path provided
    if save_path:
        fig.savefig(save_path, dpi=300, bbox_inches='tight', format=None)
        print(f"Saved figure to {save_path}")

    plt.show()

def main():
    parser = argparse.ArgumentParser(description='Create clean ULP error heat maps')
    parser.add_argument('filepath', help='Path to the CSV file')
    parser.add_argument('--x', default='x0', help='Column for X axis (default: x0)')
    parser.add_argument('--y', default='x1', help='Column for Y axis (default: x1)')
    parser.add_argument('--z', default='ulp_error', help='Column for values (default: ulp_error)')
    parser.add_argument('--resolution', type=int, default=200, help='Grid resolution (default: 200)')
    parser.add_argument('--method', default='linear', choices=['linear', 'nearest', 'cubic'],
                        help='Griddata interpolation method (default: linear)')
    parser.add_argument('--interpolation', default='nearest',
                        choices=['nearest', 'bilinear', 'bicubic', 'lanczos', 'none'],
                        help='Image interpolation method (default: nearest)')
    parser.add_argument('--title', help='Plot title')
    parser.add_argument('--save', help='Save figure to file')
    parser.add_argument('--log', action='store_true', help='Use log10 scale for values')
    parser.add_argument('--size', type=float, default=8, help='Figure size in inches (default: 8)')

    args = parser.parse_args()

    # Create the heatmap
    create_clean_heatmap(
        filepath=args.filepath,
        x_col=args.x,
        y_col=args.y,
        z_col=args.z,
        resolution=args.resolution,
        title=args.title,
        save_path=args.save,
        figsize=(args.size, args.size),
        use_log=args.log,
        method=args.method,
        interpolation=args.interpolation
    )

if __name__ == "__main__":
    main()