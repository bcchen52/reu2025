#!/bin/bash
# Generalized Verificarlo runner script for numerical programs
# Supports programs with or without method parameters

set -e
export LC_ALL=C

# Record start time
SCRIPT_START=$(date +%s)

# Function to display usage
usage() {
    echo "Usage: $0 -p PROGRAM -t TYPE -v VPRECISION -M MODE [-m METHOD] [-r RANGE] [-s STEP] [-i ITERATIONS] [-o OUTPUT_DIR] [-e EXTRA_FILES]"
    echo ""
    echo "Required arguments:"
    echo "  -p PROGRAM      : C source file to compile (without .c extension)"
    echo "  -t TYPE         : Precision type [FLOAT | DOUBLE]"
    echo "  -v VPRECISION   : MCA Virtual Precision (positive integer)"
    echo "  -M MODE         : MCA Mode [mca | pb | rr]"
    echo ""
    echo "Optional arguments:"
    echo "  -m METHOD       : Method/algorithm to use (only if program requires it)"
    echo "  -r RANGE        : Test range as 'start:end' (default: '-1.0:1.0')"
    echo "  -s STEP         : Step size for test values (default: 0.01)"
    echo "  -i ITERATIONS   : Number of iterations per test value (default: 20)"
    echo "  -o OUTPUT_DIR   : Output directory for results (default: './results')"
    echo "  -e EXTRA_FILES  : Additional source files to compile (space-separated)"
    echo "  -E EXTRA_DEFS   : Additional preprocessor definitions (space-separated)"
    echo "  -P              : Enable plotting (requires plot.py in current directory)"
    echo "  -a ARGS         : Additional arguments to pass to the program"
    echo ""
    echo "Examples:"
    echo "  # Program with method:"
    echo "  $0 -p tchebychev -m HORNER -t FLOAT -v 24 -M mca"
    echo ""
    echo "  # Program without method:"
    echo "  $0 -p myfunction -t DOUBLE -v 53 -M pb"
    echo ""
    echo "  # With additional program arguments:"
    echo "  $0 -p solver -t FLOAT -v 24 -M mca -a '100 1e-6'"
    exit 1
}

# Default values
RANGE_START="-1.0"
RANGE_END="1.0"
STEP="0.01"
ITERATIONS="20"
OUTPUT_DIR="./results"
EXTRA_FILES=""
EXTRA_DEFS=""
ENABLE_PLOT=false
METHOD=""
EXTRA_ARGS=""

# Parse command line arguments
while getopts "p:m:t:v:M:r:s:i:o:e:E:a:Ph" opt; do
    case $opt in
        p) PROGRAM="$OPTARG" ;;
        m) METHOD="$OPTARG" ;;
        t) REAL="$OPTARG" ;;
        v) VERIFICARLO_PRECISION="$OPTARG" ;;
        M) VERIFICARLO_MCAMODE="$OPTARG" ;;
        r)
            IFS=':' read -r RANGE_START RANGE_END <<< "$OPTARG"
            ;;
        s) STEP="$OPTARG" ;;
        i) ITERATIONS="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        e) EXTRA_FILES="$OPTARG" ;;
        E) EXTRA_DEFS="$OPTARG" ;;
        a) EXTRA_ARGS="$OPTARG" ;;
        P) ENABLE_PLOT=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check required arguments
if [ -z "$PROGRAM" ] || [ -z "$REAL" ] || [ -z "$VERIFICARLO_PRECISION" ] || [ -z "$VERIFICARLO_MCAMODE" ]; then
    echo "Error: Missing required arguments"
    usage
fi

# Validate precision type
case "${REAL}" in
    FLOAT|DOUBLE) ;;
    *)
        echo "Error: Invalid precision type '${REAL}'. Choose between [FLOAT | DOUBLE]"
        exit 1
        ;;
esac

# Validate MCA mode
case "${VERIFICARLO_MCAMODE}" in
    mca|pb|rr) ;;
    *)
        echo "Error: Invalid MCA mode '${VERIFICARLO_MCAMODE}'. Choose between [mca | pb | rr]"
        exit 1
        ;;
esac

# Check if source file exists
if [ ! -f "${PROGRAM}.c" ]; then
    echo "Error: Source file '${PROGRAM}.c' not found"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Print configuration
echo "=== Verificarlo Configuration ==="
echo "Program: ${PROGRAM}.c"
[ -n "$METHOD" ] && echo "Method: $METHOD"
echo "Precision Type: $REAL"
echo "Verificarlo Precision: $VERIFICARLO_PRECISION"
echo "MCA Mode: $VERIFICARLO_MCAMODE"
echo "Test Range: [$RANGE_START, $RANGE_END] with step $STEP"
echo "Iterations per value: $ITERATIONS"
echo "Output Directory: $OUTPUT_DIR"
[ -n "$EXTRA_FILES" ] && echo "Extra Files: $EXTRA_FILES"
[ -n "$EXTRA_DEFS" ] && echo "Extra Definitions: $EXTRA_DEFS"
[ -n "$EXTRA_ARGS" ] && echo "Extra Arguments: $EXTRA_ARGS"
echo "================================"

# Build compile command
COMPILE_CMD="verificarlo -D${REAL}"
[ -n "$EXTRA_DEFS" ] && COMPILE_CMD="$COMPILE_CMD $EXTRA_DEFS"
COMPILE_CMD="$COMPILE_CMD ${PROGRAM}.c"
[ -n "$EXTRA_FILES" ] && COMPILE_CMD="$COMPILE_CMD $EXTRA_FILES"
COMPILE_CMD="$COMPILE_CMD -o ${PROGRAM}_verificarlo -lm "

# Compile source code with verificarlo
echo "Compiling with: $COMPILE_CMD"
eval $COMPILE_CMD

# Set Verificarlo backend configuration
export VFC_BACKENDS="libinterflop_mca.so --precision-binary32=$VERIFICARLO_PRECISION --precision-binary64=$VERIFICARLO_PRECISION --mode $VERIFICARLO_MCAMODE"

# Generate output filename
if [ -n "$METHOD" ]; then
    OUTPUT_FILE="${OUTPUT_DIR}/${PROGRAM}-${METHOD}-${REAL}-vp${VERIFICARLO_PRECISION}-${VERIFICARLO_MCAMODE}.tab"
else
    OUTPUT_FILE="${OUTPUT_DIR}/${PROGRAM}-${REAL}-vp${VERIFICARLO_PRECISION}-${VERIFICARLO_MCAMODE}.tab"
fi

# Write header to output file
echo "i x result" > "$OUTPUT_FILE"

# Function to compare floating point numbers for seq
float_seq() {
    local start=$1
    local end=$2
    local step=$3

    python3 -c "
import numpy as np
for x in np.arange($start, $end + $step/2, $step):
    print(f'{x:.6f}')
"
}

# Build program command
build_program_cmd() {
    local x=$1
    local cmd="./${PROGRAM}_verificarlo $x"
    [ -n "$METHOD" ] && cmd="$cmd $METHOD"
    [ -n "$EXTRA_ARGS" ] && cmd="$cmd $EXTRA_ARGS"
    echo "$cmd"
}

# Run tests for all values in the specified range
echo "Running tests..."
total_values=$(float_seq "$RANGE_START" "$RANGE_END" "$STEP" | wc -l)
current=0

for x in $(float_seq "$RANGE_START" "$RANGE_END" "$STEP"); do
    current=$((current + 1))
    printf "\rProgress: %d/%d (%.1f%%)" "$current" "$total_values" "$(echo "scale=1; $current * 100 / $total_values" | bc)"

    for i in $(seq 1 "$ITERATIONS"); do
        # Build and run the program command
        cmd=$(build_program_cmd "$x")
        output=$(eval $cmd 2>&1)

        # Parse output - try different strategies
        # Strategy 1: Look for two numbers (x and result)
        result=$(echo "$output" | grep -E "^[[:space:]]*[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?[[:space:]]+[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?[[:space:]]*$" | tail -n 1 | awk '{print $2}')

        # Strategy 2: If no result, try just the last number on the last line
        if [ -z "$result" ]; then
            result=$(echo "$output" | tail -n 1 | grep -oE "[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?" | tail -n 1)
        fi

        # Strategy 3: If still no result, use the entire last line
        if [ -z "$result" ]; then
            result=$(echo "$output" | tail -n 1)
        fi

        echo "$i $x $result" >> "$OUTPUT_FILE"
    done
done

echo -e "\nTests completed. Results saved to: $OUTPUT_FILE"

# Generate summary statistics
echo -e "\n=== Summary Statistics ==="
echo "Total test points: $total_values"
echo "Total runs: $((total_values * ITERATIONS))"

# Basic statistics using awk
awk 'NR>1 {
    # Try to parse the third column as a number
    if ($3 ~ /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/) {
        sum += $3
        sumsq += $3 * $3
        count++
    }
}
END {
    if (count > 0) {
        mean = sum / count
        variance = (sumsq / count) - (mean * mean)
        if (variance < 0) variance = 0
        stddev = sqrt(variance)
        printf "Mean result: %.6e\n", mean
        printf "Std deviation: %.6e\n", stddev
        printf "Valid numeric results: %d/%d\n", count, NR-1
    } else {
        print "Warning: No valid numeric results found"
    }
}' "$OUTPUT_FILE"

# Plot results if requested and plot.py exists
if [ "$ENABLE_PLOT" = true ]; then
    if [ -f "./plot.py" ]; then
        echo -e "\nGenerating plot..."
        ./plot.py "$OUTPUT_FILE" "$VERIFICARLO_PRECISION" &
    else
        echo -e "\nWarning: plot.py not found in current directory. Skipping plot generation."
    fi
fi

# Clean up executable
rm -f "${PROGRAM}_verificarlo"

# Calculate and display execution time
SCRIPT_END=$(date +%s)
DURATION=$((SCRIPT_END - SCRIPT_START))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo -e "\n=== Execution Time ==="
if [ $MINUTES -gt 0 ]; then
    echo "Total time: ${MINUTES}m ${SECONDS}s"
else
    echo "Total time: ${SECONDS}s"
fi

echo -e "\nDone!"
