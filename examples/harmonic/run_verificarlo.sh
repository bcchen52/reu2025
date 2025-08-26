#!/bin/bash
# Verificarlo runner script for programs with multiple inputs
# Supports 1, 2, or 3 input variables with various test patterns

set -e
export LC_ALL=C

# Record start time
SCRIPT_START=$(date +%s)

# Function to display usage
usage() {
    echo "Usage: $0 -p PROGRAM -t TYPE -v VPRECISION -M MODE -n NINPUTS [options]"
    echo ""
    echo "Required arguments:"
    echo "  -p PROGRAM      : C source file to compile (without .c extension)"
    echo "  -t TYPE         : Precision type [FLOAT | DOUBLE]"
    echo "  -v VPRECISION   : MCA Virtual Precision (positive integer)"
    echo "  -M MODE         : MCA Mode [mca | pb | rr]"
    echo "  -n NINPUTS      : Number of inputs (1, 2, or 3)"
    echo ""
    echo "Optional arguments:"
    echo "  -r RANGE        : Test range as 'start:end' for all variables (default: '-1.0:1.0')"
    echo "  -R RANGES       : Individual ranges as 'x0=start:end,x1=start:end,x2=start:end'"
    echo "                    Example: -R 'x0=-10:10,x1=-5:5,x2=0:20'"
    echo "  -s STEP         : Step size for all variables (default: 0.5)"
    echo "  -S STEPS        : Individual steps as 'x0=step,x1=step,x2=step'"
    echo "                    Example: -S 'x0=0.5,x1=1.0,x2=2.0'"
    echo "  -i ITERATIONS   : Number of iterations per test value (default: 20)"
    echo "  -o OUTPUT_DIR   : Output directory for results (default: './results')"
    echo "  -e EXTRA_FILES  : Additional source files to compile (space-separated)"
    echo "  -O OPTIMIZE     : Optimization flags (e.g., '-O3 -ffast-math')"
    echo "  -P              : Enable plotting (requires custom plot script)"
    echo "  -F FIXED        : Fixed values for some inputs (format: 'var=value,var=value')"
    echo "                    e.g., -F 'x1=0.0,x2=1.0' to fix x1 and x2"
    echo "  -T TEST         : Test pattern [grid | diagonal | random | fixed]"
    echo "                    grid: test all combinations (default)"
    echo "                    diagonal: x0=x1=x2"
    echo "                    random: random values in range"
    echo "                    fixed: use -F to fix some variables"
    echo ""
    echo "Examples:"
    echo "  # Different ranges for each variable:"
    echo "  $0 -p softmax -t DOUBLE -v 53 -M mca -n 3 -R 'x0=-10:10,x1=-5:5,x2=0:20' -s 0.5"
    echo ""
    echo "  # Different ranges and steps:"
    echo "  $0 -p softmax -t DOUBLE -v 53 -M mca -n 3 -R 'x0=-10:10,x1=-5:5,x2=0:20' -S 'x0=0.5,x1=1.0,x2=2.0'"
    echo ""
    echo "  # Mix of global and individual settings:"
    echo "  $0 -p myfunc -t FLOAT -v 24 -M pb -n 2 -r '-2:2' -S 'x0=0.1,x1=0.5'"
    exit 1
}

# Default values
RANGE_START="-1.0"
RANGE_END="1.0"
STEP="0.5"
ITERATIONS="20"
OUTPUT_DIR="./results"
EXTRA_FILES=""
OPTIMIZATION=""
ENABLE_PLOT=false
NINPUTS=""
FIXED_VALUES=""
TEST_PATTERN="grid"
INDIVIDUAL_RANGES=""
INDIVIDUAL_STEPS=""

# Parse command line arguments
while getopts "p:t:v:M:n:r:R:s:S:i:o:e:O:F:T:Ph" opt; do
    case $opt in
        p) PROGRAM="$OPTARG" ;;
        t) REAL="$OPTARG" ;;
        v) VERIFICARLO_PRECISION="$OPTARG" ;;
        M) VERIFICARLO_MCAMODE="$OPTARG" ;;
        n) NINPUTS="$OPTARG" ;;
        r)
            IFS=':' read -r RANGE_START RANGE_END <<< "$OPTARG"
            ;;
        R) INDIVIDUAL_RANGES="$OPTARG" ;;
        s) STEP="$OPTARG" ;;
        S) INDIVIDUAL_STEPS="$OPTARG" ;;
        i) ITERATIONS="$OPTARG" ;;
        o) OUTPUT_DIR="$OPTARG" ;;
        e) EXTRA_FILES="$OPTARG" ;;
        O) OPTIMIZATION="$OPTARG" ;;
        F) FIXED_VALUES="$OPTARG" ;;
        T) TEST_PATTERN="$OPTARG" ;;
        P) ENABLE_PLOT=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Check required arguments
if [ -z "$PROGRAM" ] || [ -z "$REAL" ] || [ -z "$VERIFICARLO_PRECISION" ] || [ -z "$VERIFICARLO_MCAMODE" ] || [ -z "$NINPUTS" ]; then
    echo "Error: Missing required arguments"
    usage
fi

# Validate number of inputs
case "${NINPUTS}" in
    1|2|3) ;;
    *)
        echo "Error: Number of inputs must be 1, 2, or 3"
        exit 1
        ;;
esac

# Validate test pattern
case "${TEST_PATTERN}" in
    grid|diagonal|random|fixed) ;;
    *)
        echo "Error: Invalid test pattern '${TEST_PATTERN}'"
        exit 1
        ;;
esac

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

# Parse fixed values
declare -A fixed_vars
if [ -n "$FIXED_VALUES" ]; then
    IFS=',' read -ra FIXED_PAIRS <<< "$FIXED_VALUES"
    for pair in "${FIXED_PAIRS[@]}"; do
        IFS='=' read -r var value <<< "$pair"
        fixed_vars[$var]=$value
    done
fi

# Parse individual ranges
declare -A range_start
declare -A range_end
range_start[x0]=$RANGE_START
range_start[x1]=$RANGE_START
range_start[x2]=$RANGE_START
range_end[x0]=$RANGE_END
range_end[x1]=$RANGE_END
range_end[x2]=$RANGE_END

if [ -n "$INDIVIDUAL_RANGES" ]; then
    IFS=',' read -ra RANGE_PAIRS <<< "$INDIVIDUAL_RANGES"
    for pair in "${RANGE_PAIRS[@]}"; do
        IFS='=' read -r var range <<< "$pair"
        IFS=':' read -r start end <<< "$range"
        range_start[$var]=$start
        range_end[$var]=$end
    done
fi

# Parse individual steps
declare -A step_size
step_size[x0]=$STEP
step_size[x1]=$STEP
step_size[x2]=$STEP

if [ -n "$INDIVIDUAL_STEPS" ]; then
    IFS=',' read -ra STEP_PAIRS <<< "$INDIVIDUAL_STEPS"
    for pair in "${STEP_PAIRS[@]}"; do
        IFS='=' read -r var step <<< "$pair"
        step_size[$var]=$step
    done
fi

# Print configuration
echo "=== Verificarlo Configuration ==="
echo "Program: ${PROGRAM}.c"
echo "Number of inputs: $NINPUTS"
echo "Test pattern: $TEST_PATTERN"
echo "Precision Type: $REAL"
echo "Verificarlo Precision: $VERIFICARLO_PRECISION"
echo "MCA Mode: $VERIFICARLO_MCAMODE"
if [ -n "$INDIVIDUAL_RANGES" ]; then
    echo "Variable ranges:"
    [ -z "${fixed_vars[x0]}" ] && echo "  x0: [${range_start[x0]}, ${range_end[x0]}] step ${step_size[x0]}"
    [ $NINPUTS -ge 2 ] && [ -z "${fixed_vars[x1]}" ] && echo "  x1: [${range_start[x1]}, ${range_end[x1]}] step ${step_size[x1]}"
    [ $NINPUTS -ge 3 ] && [ -z "${fixed_vars[x2]}" ] && echo "  x2: [${range_start[x2]}, ${range_end[x2]}] step ${step_size[x2]}"
else
    echo "Test Range: [$RANGE_START, $RANGE_END] with step $STEP"
fi
echo "Iterations per value: $ITERATIONS"
echo "Output Directory: $OUTPUT_DIR"
[ -n "$OPTIMIZATION" ] && echo "Optimization: $OPTIMIZATION"
[ -n "$FIXED_VALUES" ] && echo "Fixed values: $FIXED_VALUES"
echo "================================"

# Build compile command
COMPILE_CMD="verificarlo -D${REAL}"
[ -n "$OPTIMIZATION" ] && COMPILE_CMD="$COMPILE_CMD $OPTIMIZATION"
COMPILE_CMD="$COMPILE_CMD ${PROGRAM}.c"
[ -n "$EXTRA_FILES" ] && COMPILE_CMD="$COMPILE_CMD $EXTRA_FILES"
COMPILE_CMD="$COMPILE_CMD -o ${PROGRAM}_verificarlo -lm"

# Compile source code with verificarlo
echo "Compiling with: $COMPILE_CMD"
eval $COMPILE_CMD

# Set Verificarlo backend configuration
export VFC_BACKENDS="libinterflop_mca.so --precision-binary32=$VERIFICARLO_PRECISION --precision-binary64=$VERIFICARLO_PRECISION --mode $VERIFICARLO_MCAMODE"

# Generate output filename
OUTPUT_FILE="${OUTPUT_DIR}/${PROGRAM}-${NINPUTS}inputs-${TEST_PATTERN}-${REAL}-vp${VERIFICARLO_PRECISION}-${VERIFICARLO_MCAMODE}.tab"

# Write header to output file based on number of inputs
case $NINPUTS in
    1) echo "i x0 result" > "$OUTPUT_FILE" ;;
    2) echo "i x0 x1 result" > "$OUTPUT_FILE" ;;
    3) echo "i x0 x1 x2 result" > "$OUTPUT_FILE" ;;
esac

# Function to generate floating point sequence with custom range and step
float_seq_custom() {
    local var=$1
    local start=${range_start[$var]}
    local end=${range_end[$var]}
    local step=${step_size[$var]}
    
    python3 -c "
import numpy as np
for x in np.arange($start, $end + $step/2, $step):
    print(f'{x:.6f}')
"
}

# Function to generate random float in range for a variable
random_float_var() {
    local var=$1
    local start=${range_start[$var]}
    local end=${range_end[$var]}
    
    python3 -c "
import random
print(f'{random.uniform($start, $end):.6f}')
"
}

# Function to get value (fixed or from sequence)
get_value() {
    local var_name=$1
    local seq_value=$2
    
    if [ -n "${fixed_vars[$var_name]}" ]; then
        echo "${fixed_vars[$var_name]}"
    else
        echo "$seq_value"
    fi
}

# Function to run the program and parse output
run_test() {
    local x0=$1
    local x1=$2
    local x2=$3
    local iter=$4
    
    # Build command based on number of inputs
    case $NINPUTS in
        1) cmd="./${PROGRAM}_verificarlo $x0" ;;
        2) cmd="./${PROGRAM}_verificarlo $x0 $x1" ;;
        3) cmd="./${PROGRAM}_verificarlo $x0 $x1 $x2" ;;
    esac
    
    # Run command and capture output
    output=$(eval $cmd 2>&1)
    
    # Try to extract the result - look for the last number on the last line
    result=$(echo "$output" | tail -n 1 | grep -oE "[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?" | tail -n 1)
    
    # If no result found, use the entire last line
    [ -z "$result" ] && result=$(echo "$output" | tail -n 1)
    
    # Write to file based on number of inputs
    case $NINPUTS in
        1) echo "$iter $x0 $result" >> "$OUTPUT_FILE" ;;
        2) echo "$iter $x0 $x1 $result" >> "$OUTPUT_FILE" ;;
        3) echo "$iter $x0 $x1 $x2 $result" >> "$OUTPUT_FILE" ;;
    esac
}

# Main testing loop
echo "Running tests..."
total_tests=0

case $TEST_PATTERN in
    grid)
        # Calculate total number of tests for progress
        if [ $NINPUTS -eq 1 ]; then
            n_points=$(float_seq_custom "x0" | wc -l)
            total_tests=$((n_points * ITERATIONS))
        elif [ $NINPUTS -eq 2 ]; then
            # Account for fixed variables
            [ -z "${fixed_vars[x0]}" ] && mult_x0=$(float_seq_custom "x0" | wc -l) || mult_x0=1
            [ -z "${fixed_vars[x1]}" ] && mult_x1=$(float_seq_custom "x1" | wc -l) || mult_x1=1
            total_tests=$((mult_x0 * mult_x1 * ITERATIONS))
        else
            # Account for fixed variables
            [ -z "${fixed_vars[x0]}" ] && mult_x0=$(float_seq_custom "x0" | wc -l) || mult_x0=1
            [ -z "${fixed_vars[x1]}" ] && mult_x1=$(float_seq_custom "x1" | wc -l) || mult_x1=1
            [ -z "${fixed_vars[x2]}" ] && mult_x2=$(float_seq_custom "x2" | wc -l) || mult_x2=1
            total_tests=$((mult_x0 * mult_x1 * mult_x2 * ITERATIONS))
        fi
        
        current=0
        
        # Grid pattern: test all combinations
        # Generate sequences only for non-fixed variables
        if [ -n "${fixed_vars[x0]}" ]; then
            x0_values="${fixed_vars[x0]}"
        else
            x0_values=$(float_seq_custom "x0")
        fi
        
        for x0 in $x0_values; do
            if [ $NINPUTS -eq 1 ]; then
                for i in $(seq 1 "$ITERATIONS"); do
                    current=$((current + 1))
                    printf "\rProgress: %d/%d (%d%%)" "$current" "$total_tests" $((current * 100 / total_tests))
                    run_test "$x0" "" "" "$i"
                done
            else
                # Generate sequences only for non-fixed variables
                if [ -n "${fixed_vars[x1]}" ]; then
                    x1_values="${fixed_vars[x1]}"
                else
                    x1_values=$(float_seq_custom "x1")
                fi
                
                for x1 in $x1_values; do
                    if [ $NINPUTS -eq 2 ]; then
                        for i in $(seq 1 "$ITERATIONS"); do
                            current=$((current + 1))
                            printf "\rProgress: %d/%d (%d%%)" "$current" "$total_tests" $((current * 100 / total_tests))
                            run_test "$x0" "$x1" "" "$i"
                        done
                    else
                        # Generate sequences only for non-fixed variables
                        if [ -n "${fixed_vars[x2]}" ]; then
                            x2_values="${fixed_vars[x2]}"
                        else
                            x2_values=$(float_seq_custom "x2")
                        fi
                        
                        for x2 in $x2_values; do
                            for i in $(seq 1 "$ITERATIONS"); do
                                current=$((current + 1))
                                printf "\rProgress: %d/%d (%d%%)" "$current" "$total_tests" $((current * 100 / total_tests))
                                run_test "$x0" "$x1" "$x2" "$i"
                            done
                        done
                    fi
                done
            fi
        done
        ;;
        
    diagonal)
        # Diagonal pattern: all inputs equal
        # Use the x0 range for all variables
        n_points=$(float_seq_custom "x0" | wc -l)
        total_tests=$((n_points * ITERATIONS))
        current=0
        
        for x in $(float_seq_custom "x0"); do
            for i in $(seq 1 "$ITERATIONS"); do
                current=$((current + 1))
                printf "\rProgress: %d/%d (%d%%)" "$current" "$total_tests" $((current * 100 / total_tests))
                
                case $NINPUTS in
                    1) run_test "$x" "" "" "$i" ;;
                    2) run_test "$x" "$x" "" "$i" ;;
                    3) run_test "$x" "$x" "$x" "$i" ;;
                esac
            done
        done
        ;;
        
    random)
        # Random pattern: random values in range
        # For random, ITERATIONS becomes total number of random tests
        total_tests=$ITERATIONS
        
        for i in $(seq 1 "$ITERATIONS"); do
            printf "\rProgress: %d/%d (%d%%)" "$i" "$total_tests" $((i * 100 / total_tests))
            
            x0=$(get_value "x0" "$(random_float_var "x0")")
            
            if [ $NINPUTS -ge 2 ]; then
                x1=$(get_value "x1" "$(random_float_var "x1")")
            else
                x1=""
            fi
            
            if [ $NINPUTS -eq 3 ]; then
                x2=$(get_value "x2" "$(random_float_var "x2")")
            else
                x2=""
            fi
            
            run_test "$x0" "$x1" "$x2" "$i"
        done
        ;;
esac

echo -e "\nTests completed. Results saved to: $OUTPUT_FILE"

# Generate summary statistics
echo -e "\n=== Summary Statistics ==="
echo "Test pattern: $TEST_PATTERN"
echo "Total tests: $total_tests"

# Basic statistics using awk
awk -v ninputs=$NINPUTS '
NR>1 {
    result_col = ninputs + 2  # i + inputs + result
    if ($result_col ~ /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/) {
        sum += $result_col
        sumsq += $result_col * $result_col
        count++
        if (count == 1 || $result_col < min) min = $result_col
        if (count == 1 || $result_col > max) max = $result_col
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
        printf "Min result: %.6e\n", min
        printf "Max result: %.6e\n", max
        printf "Valid numeric results: %d/%d\n", count, NR-1
    } else {
        print "Warning: No valid numeric results found"
    }
}' "$OUTPUT_FILE"

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
