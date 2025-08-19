#!/usr/bin/env python3
import sys
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

def main():
    if len(sys.argv) != 3:
        print("Usage: python heatmap.py <errors.csv>")
        sys.exit(1)

    out_file = sys.argv[1]
    err_file = sys.argv[2] 

    # Load the error values (skip header)
    errors = np.loadtxt(err_file, delimiter=',', skiprows=1)
    output = np.loadtxt(out_file, delimiter=',', skiprows=1)

    # Determine grid dimensions (must be square)
    N = errors.size
    side = int(np.sqrt(N))
    if side * side != N:
        raise ValueError(f"Expected a square grid, but got {N} values.")

    # Reshape into a 2D array: rows = x1 values, columns = x0 values
    out_grid = output.reshape((side, side)).T
    err_grid = errors.reshape((side, side)).T
    err_grid = np.float32(err_grid)
    ulp_grid = np.spacing(np.float32(out_grid))
    ulp_err = err_grid / ulp_grid
    
    print(np.max(ulp_err))
    print(np.max(err_grid))

    # 1) Find the flat index of the max ULP‑error
    flat_max = np.argmax(ulp_err)

    # 2) Convert to 2D indices
    i_row, i_col = np.unravel_index(flat_max, ulp_err.shape)

    # 3) Look up values
    max_ulp   = ulp_err[i_row, i_col]
    max_err   = err_grid[i_row, i_col]
    max_out   = out_grid[i_row, i_col]

    # 4) (Optionally) map back to your x0,x1 coordinates
    #    if you built x_vals = np.linspace(-10,10,side), y_vals same:
    x0_vals = np.linspace(0.0,1,side)
    x1_vals = np.linspace(0.0,1,side)
    x0_star = x0_vals[i_col]
    x1_star = x1_vals[i_row]

    print(f"Max ULP‑error = {max_ulp:.3g} at (x0, x1) = ({x0_star:.3g}, {x1_star:.3g})")
    print(f"  → output  y0 = {max_out:.6g}")
    print(f"  → abs‑error    = {max_err:.3g}")

    
    # Create axis values from -10 to 10 inclusive
    x_vals = np.linspace(0.0, 1, side)
    y_vals = np.linspace(0.0, 1, side)


    anom = err_grid == 0   # mask NaN/Inf and your sentinel 0
    Zm   = np.ma.array(ulp_err, mask=anom)            # masked array
    cmap = plt.cm.get_cmap('viridis')
    cmap.set_bad('red')   

    # Plot heatmap
    fig, ax = plt.subplots(figsize=(8, 6))
    cax = ax.imshow(
        Zm,
        origin='lower',
        extent=(x_vals[0], x_vals[-1], y_vals[0], y_vals[-1]),
        interpolation='nearest',
        cmap=cmap,
        aspect='auto'
    )
    bad_patch = mpatches.Patch(facecolor='red', edgecolor='red', label='Error Unbounded (Inf)')
    ax.legend(handles=[bad_patch], loc='upper right', frameon=True)
    ax.set_xlabel('x0')
    ax.set_ylabel('x1')
    ax.set_title('Naive Softmax fp32 CiRE Error in ULPs')
    fig.colorbar(cax, ax=ax, label='Error in ULPs')
    plt.tight_layout()

    plt.savefig('ex.pdf')
    plt.show()
    

if __name__ == "__main__":
    main()

