import sys
import argparse
import numpy as np
import itertools
import random

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--n-inputs', type=int, required=True)
    parser.add_argument('--program', type=str, required=True)
    parser.add_argument('--iterations', type=int, required=True)
    parser.add_argument('--test-pattern', type=str, required=True)
    parser.add_argument('--ranges', type=str, nargs='*')
    parser.add_argument('--steps', type=str, nargs='*')
    parser.add_argument('--fixed', type=str, nargs='*')
    args = parser.parse_args()

    # --- Parse inputs ---
    ranges = {f'x{i}': r.split(':') for i, r in enumerate(args.ranges)}
    steps = {f'x{i}': s for i, s in enumerate(args.steps)}
    fixed_vars = dict(f.split('=') for f in args.fixed or [])

    # --- Define generator functions ---
    def get_sequence(var):
        if var in fixed_vars:
            return [float(fixed_vars[var])]
        
        try:
            start, end = map(float, ranges[var])
        except (ValueError, KeyError) as e:
            print(f"Error: Invalid range for variable {var}. Received {ranges.get(var)}. Exiting.", file=sys.stderr)
            sys.exit(1)

        step = float(steps[var])
        if step <= 0:
            print(f"Error: Step for variable {var} must be positive. Received {step}. Exiting.", file=sys.stderr)
            sys.exit(1)

        # Use np.linspace for robust floating point ranges
        num_points = int(round((end - start) / step)) + 1
        return np.linspace(start, end, num_points)

    def get_random(var):
        if var in fixed_vars:
            return float(fixed_vars[var])
        start, end = map(float, ranges[var])
        return random.uniform(start, end)

    # --- Generate Jobs ---
    try:
        if args.test_pattern == 'grid':
            sequences = [get_sequence(f'x{i}') for i in range(args.n_inputs)]
            job_iterator = itertools.product(*sequences)
        
        elif args.test_pattern == 'diagonal':
            job_iterator = ( (val,)*args.n_inputs for val in get_sequence('x0') )

        elif args.test_pattern == 'random':
            job_iterator = None # Handled separately
        else: # fixed
            job_iterator = itertools.product(*[get_sequence(f'x{i}') for i in range(args.n_inputs)])
    except (SystemExit, Exception) as e:
        # Catch errors from get_sequence and exit gracefully
        print(f"Job generation failed: {e}", file=sys.stderr)
        sys.exit(1)


    # --- Print job commands ---
    if job_iterator:
        for combo in job_iterator:
            for i in range(1, args.iterations + 1):
                # Ensure combo is a mutable list for padding
                combo_list = list(combo)
                params = ' '.join([f"'{val}'" for val in combo_list])
                while len(combo_list) < 3:
                    params += " ''"
                    combo_list.append(None)
                print(f"run_one_job {args.n_inputs} {args.program}_verificarlo {params} '{i}'")
    
    elif args.test_pattern == 'random':
        for i in range(1, args.iterations + 1):
            combo = [get_random(f'x{v}') for v in range(args.n_inputs)]
            params = ' '.join([f"'{val}'" for val in combo])
            while len(combo) < 3:
                params += " ''"
                combo.append(None)
            print(f"run_one_job {args.n_inputs} {args.program}_verificarlo {params} '{i}'")


if __name__ == '__main__':
    main()
