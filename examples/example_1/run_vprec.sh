#!/bin/bash
# Generalized Verificarlo VPREC runner script for numerical programs
# VPREC is deterministic, so only one run per test value is needed

set -e
export LC_ALL=C

# Record start time
SCRIPT_START=$(date +%s)

# Function to display usage
usage() {
    echo "Usage: $0 -p PROGRAM -t TYPE -P PRESET|CUSTOM [-m METHOD] [-r RANGE] [-s STEP] [-o OUTPUT_DIR] [-e EXTRA_FILES]"
    echo ""
    echo "Required arguments:"
    echo "  -p PROGRAM      : C source file to compile (without .c extension)"
    echo "  -t TYPE         : Precision type [FLOAT | DOUBLE]"
    echo "  -P PRESET       : VPREC preset or CUSTOM"
    echo "                    Presets: binary16, binary32, bfloat16, tensorfloat, fp24, PXR24"
    echo "                    Use CUSTOM for manual precision/range settings"
    echo ""
    echo "Optional arguments:"
    echo "  -m METHOD       : Method/algorithm to use (only if program requires it)"
    echo "  -r RANGE        : Test range as 'start:end' (default: '0.0:1.0')"
    echo "  -s STEP         : Step size for test values (default: 0.01)"
    echo "  -o OUTPUT_DIR   : Output directory for results (default: './vprec_results')"
    echo "  -e EXTRA_FILES  : Additional source files to compile (space-separated)"
    echo "  -E EXTRA_DEFS   : Additional preprocessor definitions (space-separated)"
    echo "  -b PRECISION    : Binary precision bits (only with -P CUSTOM)"
    echo "  -R RANGE_BITS   : Range/exponent bits (only with -P CUSTOM)"
    echo "  -T TARGET       : Target format: binary32 or binary64 (default: binary64)"
    echo "  -O OPTIMIZE     : Optimization flags (e.g., '-O3 -ffast-math')"
    echo "  -V              : Enable plotting (requires plot_vprec.py)"
    echo "  -a ARGS         : Additional arguments to pass to the program"
    echo ""
    echo "Examples:"
    echo "  # Using preset:"
    echo "  $0 -p tchebychev -m HORNER -t DOUBLE -P binary32"
    echo ""
    echo "  # Using custom precision (10 bits):"
    echo "  $0 -p myfunction -t DOUBLE -P CUSTOM -b 10"
    echo ""
    echo "  # With custom precision and range:"
    echo "  $0 -p myfunction -t DOUBLE -P CUSTOM -b 10 -R 8"
    echo ""
    echo "  # With optimization:"
    echo "  $0 -p program -t FLOAT -P bfloat16 -O '-O3 -ffast-math'"
    exit 1
}

# Default values
RANGE_START="-1.0"
RANGE_END="1.0"
STEP="0.01"
OUTPUT_DIR="./vprec_results"
EXTRA_FILES=""
EXTRA_DEFS=""
METHOD=""
EXTRA_ARGS=""
PRECISION_BITS=""
RANGE_BITS=""
TARGET_FORMAT="binary64"
OPTIMIZATION=""
ENABLE_PLOT=false

# Parse command line arguments
while getopts "p:m:t:P:r:s:o:e:E:b:R:T:O:a:Vh" opt; do
    case $opt in
        p) PROGRAM="$OPTARG" ;;
        m) METHOD="$OPTARG" ;;
        t) REAL="$OPTARG" ;;
        P) VPREC_PRESET="$OPTARG" ;;
        r)
            IFS=':' read -r RANGE_START RANGE_END <<< "$OPTARG"
            ;;
        s) STEP="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        e) EXTRA_FILES="$OPTARG" ;;
        E) EXTRA_DEFS="$OPTARG" ;;
        b) PRECISION_BITS="$OPTARG" ;;
        R) RANGE_BITS="$OPTARG" ;;
        T) TARGET_FORMAT="$OPTARG" ;;
        O) OPTIMIZATION="$OPTARG" ;;
        a) EXTRA_ARGS="$OPTARG" ;;
        V) ENABLE_PLOT=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check required arguments
if [ -z "$PROGRAM" ] || [ -z "$REAL" ] || [ -z "$VPREC_PRESET" ]; then
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

# Validate VPREC preset
if [ "$VPREC_PRESET" = "CUSTOM" ]; then
    if [ -z "$PRECISION_BITS" ]; then
        echo "Error: CUSTOM preset requires -b PRECISION argument"
        exit 1
    fi
else
    # Validate known presets
    case "${VPREC_PRESET}" in
        binary16|binary32|bfloat16|tensorfloat|fp24|PXR24) ;;
        *)
            echo "Error: Unknown preset '${VPREC_PRESET}'"
            echo "Valid presets: binary16, binary32, bfloat16, tensorfloat, fp24, PXR24, or CUSTOM"
            exit 1
            ;;
    esac
fi

# Validate target format
case "${TARGET_FORMAT}" in
    binary32|binary64) ;;
    *)
        echo "Error: Invalid target format '${TARGET_FORMAT}'. Choose between [binary32 | binary64]"
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
echo "=== Verificarlo VPREC Configuration ==="
echo "Program: ${PROGRAM}.c"
[ -n "$METHOD" ] && echo "Method: $METHOD"
echo "Precision Type: $REAL"
if [ "$VPREC_PRESET" = "CUSTOM" ]; then
    echo "VPREC Mode: Custom"
    echo "Precision bits: $PRECISION_BITS"
    [ -n "$RANGE_BITS" ] && echo "Range bits: $RANGE_BITS"
else
    echo "VPREC Preset: $VPREC_PRESET"
fi
echo "Target Format: $TARGET_FORMAT"
echo "Test Range: [$RANGE_START, $RANGE_END] with step $STEP"
echo "Output Directory: $OUTPUT_DIR"
[ -n "$OPTIMIZATION" ] && echo "Optimization: $OPTIMIZATION"
[ -n "$EXTRA_FILES" ] && echo "Extra Files: $EXTRA_FILES"
[ -n "$EXTRA_DEFS" ] && echo "Extra Definitions: $EXTRA_DEFS"
[ -n "$EXTRA_ARGS" ] && echo "Extra Arguments: $EXTRA_ARGS"
echo "======================================="

# Build compile command
COMPILE_CMD="verificarlo -D${REAL}"
[ -n "$OPTIMIZATION" ] && COMPILE_CMD="$COMPILE_CMD $OPTIMIZATION"
[ -n "$EXTRA_DEFS" ] && COMPILE_CMD="$COMPILE_CMD $EXTRA_DEFS"
COMPILE_CMD="$COMPILE_CMD ${PROGRAM}.c"
[ -n "$EXTRA_FILES" ] && COMPILE_CMD="$COMPILE_CMD $EXTRA_FILES"
COMPILE_CMD="$COMPILE_CMD -o ${PROGRAM}_vprec -lm"

# Compile source code with verificarlo
echo "Compiling with: $COMPILE_CMD"
eval $COMPILE_CMD

# Set Verificarlo VPREC backend configuration
if [ "$VPREC_PRESET" = "CUSTOM" ]; then
    VFC_BACKENDS="libinterflop_vprec.so"
    if [ "$TARGET_FORMAT" = "binary64" ]; then
        VFC_BACKENDS="$VFC_BACKENDS --precision-binary64=$PRECISION_BITS"
        [ -n "$RANGE_BITS" ] && VFC_BACKENDS="$VFC_BACKENDS --range-binary64=$RANGE_BITS"
    else
        VFC_BACKENDS="$VFC_BACKENDS --precision-binary32=$PRECISION_BITS"
        [ -n "$RANGE_BITS" ] && VFC_BACKENDS="$VFC_BACKENDS --range-binary32=$RANGE_BITS"
    fi
else
    VFC_BACKENDS="libinterflop_vprec.so --preset=$VPREC_PRESET"
fi
export VFC_BACKENDS

echo "VPREC Backend: $VFC_BACKENDS"

# Generate output filename
if [ "$VPREC_PRESET" = "CUSTOM" ]; then
    PRESET_NAME="custom_p${PRECISION_BITS}"
    [ -n "$RANGE_BITS" ] && PRESET_NAME="${PRESET_NAME}_r${RANGE_BITS}"
else
    PRESET_NAME="$VPREC_PRESET"
fi

if [ -n "$METHOD" ]; then
    OUTPUT_FILE="${OUTPUT_DIR}/vprec${PROGRAM}-${METHOD}-${REAL}-${PRESET_NAME}.tab"
else
    OUTPUT_FILE="${OUTPUT_DIR}/vprec${PROGRAM}-${REAL}-${PRESET_NAME}.tab"
fi

# Write header to output file
echo "i x result" > "$OUTPUT_FILE"

# Function to generate floating point sequence
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
    local cmd="./${PROGRAM}_vprec $x"
    [ -n "$METHOD" ] && cmd="$cmd $METHOD"
    [ -n "$EXTRA_ARGS" ] && cmd="$cmd $EXTRA_ARGS"
    echo "$cmd"
}

# Run tests for all values in the specified range
echo "Running VPREC tests (deterministic - single run per value)..."
total_values=$(float_seq "$RANGE_START" "$RANGE_END" "$STEP" | wc -l)
current=0

for x in $(float_seq "$RANGE_START" "$RANGE_END" "$STEP"); do
    current=$((current + 1))
    # Simple progress without bc
    percent=$((current * 100 / total_values))
    printf "\rProgress: %d/%d (%d%%)" "$current" "$total_values" "$percent"
    
    # Build and run the program command
    cmd=$(build_program_cmd "$x")
    output=$(eval $cmd 2>&1)
    
    # Parse output - same strategies as MCA script
    # Strategy 1: Look for two numbers (x and result)
    result=$(echo "$output" | grep -E "^[[:space:]]*[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?[[:space:]]+[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?[[:space:]]*$" | tail -n 1 | awk '{print $2}')
    
    # Strategy 2: Extract from specific format if needed
    if [ -z "$result" ]; then
        result=$(echo "$output" | grep -oE "sqrt\(x\)[[:space:]]*=[[:space:]]*[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?" | sed 's/.*=[[:space:]]*//')
    fi
    
    # Strategy 3: Try just the last number on the last line
    if [ -z "$result" ]; then
        result=$(echo "$output" | tail -n 1 | grep -oE "[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?" | tail -n 1)
    fi
    
    # Strategy 4: If still no result, use the entire last line
    if [ -z "$result" ]; then
        result=$(echo "$output" | tail -n 1)
    fi
    
    # VPREC is deterministic, so we only need one run per x value (i=1)
    echo "1 $x $result" >> "$OUTPUT_FILE"
done

echo -e "\nTests completed. Results saved to: $OUTPUT_FILE"

# Generate summary statistics
echo -e "\n=== Summary Statistics ==="
echo "Total test points: $total_values"
echo "Backend configuration: $VFC_BACKENDS"

# Basic statistics using awk
awk 'NR>1 {
    if ($3 ~ /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/) {
        values[NR-1] = $3
        x_vals[NR-1] = $2
        sum += $3
        count++
        if (NR == 2 || $3 < min) min = $3
        if (NR == 2 || $3 > max) max = $3
    }
}
END {
    if (count > 0) {
        mean = sum / count
        printf "Mean result: %.6e\n", mean
        printf "Min result: %.6e\n", min
        printf "Max result: %.6e\n", max
        printf "Valid results: %d/%d\n", count, NR-1
    } else {
        print "Warning: No valid numeric results found"
    }
}' "$OUTPUT_FILE"

# Plot results if requested
if [ "$ENABLE_PLOT" = true ]; then
    if [ -f "./plot_vprec.py" ]; then
        echo -e "\nGenerating plot..."
        ./plot_vprec.py "$OUTPUT_FILE" "$PRESET_NAME" &
    else
        echo -e "\nWarning: plot_vprec.py not found. Skipping plot generation."
    fi
fi

# Clean up executable
rm -f "${PROGRAM}_vprec"

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
