#!/bin/bash
# Verificarlo runner script with parallelization support
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
    echo "  -j JOBS         : Number of parallel jobs (default: number of CPU cores)"
    echo "  -b BATCH_SIZE   : Number of tests per batch for parallelization (default: auto)"
    echo "  -E ENGINE       : Parallelization engine [gnu_parallel | xargs | none] (default: auto-detect)"
    echo ""
    echo "Examples:"
    echo "  # Run with 8 parallel jobs:"
    echo "  $0 -p harmonic0 -t DOUBLE -v 53 -M mca -n 2 -r '-1:1' -j 8"
    echo ""
    echo "  # Different ranges with parallelization:"
    echo "  $0 -p softmax -t DOUBLE -v 53 -M mca -n 3 -R 'x0=-10:10,x1=-5:5,x2=0:20' -s 0.5 -j 16"
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
PARALLEL_JOBS=""
BATCH_SIZE=""
PARALLEL_ENGINE=""

# Parse command line arguments
while getopts "p:t:v:M:n:r:R:s:S:i:o:e:O:F:T:j:b:E:Ph" opt; do
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
        j) PARALLEL_JOBS="$OPTARG" ;;
        b) BATCH_SIZE="$OPTARG" ;;
        E) PARALLEL_ENGINE="$OPTARG" ;;
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

# Detect parallelization engine if not specified
if [ -z "$PARALLEL_ENGINE" ]; then
    if command -v parallel &> /dev/null; then
        PARALLEL_ENGINE="gnu_parallel"
    elif command -v xargs &> /dev/null; then
        PARALLEL_ENGINE="xargs"
    else
        PARALLEL_ENGINE="none"
    fi
fi

# Validate parallel engine
case "${PARALLEL_ENGINE}" in
    gnu_parallel)
        if ! command -v parallel &> /dev/null; then
            echo "Error: GNU Parallel not found. Install it or choose a different engine"
            echo "To install: apt-get install parallel (Debian/Ubuntu) or brew install parallel (Mac)"
            exit 1
        fi
        ;;
    xargs)
        if ! command -v xargs &> /dev/null; then
            echo "Error: xargs not found"
            exit 1
        fi
        ;;
    none)
        echo "Note: Running in sequential mode (no parallelization)"
        ;;
    *)
        echo "Error: Invalid parallel engine '${PARALLEL_ENGINE}'"
        exit 1
        ;;
esac

# Set default number of parallel jobs if not specified
if [ -z "$PARALLEL_JOBS" ]; then
    if [ "$PARALLEL_ENGINE" != "none" ]; then
        # Try to detect number of CPU cores
        if command -v nproc &> /dev/null; then
            PARALLEL_JOBS=$(nproc)
        elif command -v sysctl &> /dev/null; then
            PARALLEL_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
        else
            PARALLEL_JOBS=4
        fi
    else
        PARALLEL_JOBS=1
    fi
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
echo "Parallelization: $PARALLEL_ENGINE with $PARALLEL_JOBS jobs"
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

# Export variables for parallel execution
export VFC_BACKENDS="libinterflop_mca.so --precision-binary32=$VERIFICARLO_PRECISION --precision-binary64=$VERIFICARLO_PRECISION --mode $VERIFICARLO_MCAMODE"
export PROGRAM
export NINPUTS
export OUTPUT_DIR

# Generate output filename
OUTPUT_FILE="${OUTPUT_DIR}/${PROGRAM}-${NINPUTS}inputs-${TEST_PATTERN}-${REAL}-vp${VERIFICARLO_PRECISION}-${VERIFICARLO_MCAMODE}.tab"
TEMP_DIR="${OUTPUT_DIR}/temp_$$"
mkdir -p "$TEMP_DIR"

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

# Worker function for parallel execution
run_batch() {
    local batch_file=$1
    local output_file=$2
    
    while IFS=' ' read -r iter x0 x1 x2; do
        # Build command based on number of inputs
        case $NINPUTS in
            1) cmd="./${PROGRAM}_verificarlo $x0" ;;
            2) cmd="./${PROGRAM}_verificarlo $x0 $x1" ;;
            3) cmd="./${PROGRAM}_verificarlo $x0 $x1 $x2" ;;
        esac
        
        # Run command and capture output
        output=$(eval $cmd 2>&1)
        
        # Try to extract the result
        result=$(echo "$output" | tail -n 1 | grep -oE "[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?" | tail -n 1)
        [ -z "$result" ] && result=$(echo "$output" | tail -n 1)
        
        # Write to output file based on number of inputs
        case $NINPUTS in
            1) echo "$iter $x0 $result" ;;
            2) echo "$iter $x0 $x1 $result" ;;
            3) echo "$iter $x0 $x1 $x2 $result" ;;
        esac
    done < "$batch_file" >> "$output_file"
}

export -f run_batch
export -f get_value

# Generate test cases file
TEST_CASES_FILE="${TEMP_DIR}/test_cases.txt"
> "$TEST_CASES_FILE"

echo "Generating test cases..."

case $TEST_PATTERN in
    grid)
        # Generate all test cases
        if [ -n "${fixed_vars[x0]}" ]; then
            x0_values="${fixed_vars[x0]}"
        else
            x0_values=$(float_seq_custom "x0")
        fi
        
        for x0 in $x0_values; do
            if [ $NINPUTS -eq 1 ]; then
                for i in $(seq 1 "$ITERATIONS"); do
                    echo "$i $x0 - -" >> "$TEST_CASES_FILE"
                done
            else
                if [ -n "${fixed_vars[x1]}" ]; then
                    x1_values="${fixed_vars[x1]}"
                else
                    x1_values=$(float_seq_custom "x1")
                fi
                
                for x1 in $x1_values; do
                    if [ $NINPUTS -eq 2 ]; then
                        for i in $(seq 1 "$ITERATIONS"); do
                            echo "$i $x0 $x1 -" >> "$TEST_CASES_FILE"
                        done
                    else
                        if [ -n "${fixed_vars[x2]}" ]; then
                            x2_values="${fixed_vars[x2]}"
                        else
                            x2_values=$(float_seq_custom "x2")
                        fi
                        
                        for x2 in $x2_values; do
                            for i in $(seq 1 "$ITERATIONS"); do
                                echo "$i $x0 $x1 $x2" >> "$TEST_CASES_FILE"
                            done
                        done
                    fi
                done
            fi
        done
        ;;
        
    diagonal)
        for x in $(float_seq_custom "x0"); do
            for i in $(seq 1 "$ITERATIONS"); do
                case $NINPUTS in
                    1) echo "$i $x - -" >> "$TEST_CASES_FILE" ;;
                    2) echo "$i $x $x -" >> "$TEST_CASES_FILE" ;;
                    3) echo "$i $x $x $x" >> "$TEST_CASES_FILE" ;;
                esac
            done
        done
        ;;
        
    random)
        for i in $(seq 1 "$ITERATIONS"); do
            x0=$(get_value "x0" "$(random_float_var "x0")")
            
            if [ $NINPUTS -ge 2 ]; then
                x1=$(get_value "x1" "$(random_float_var "x1")")
            else
                x1="-"
            fi
            
            if [ $NINPUTS -eq 3 ]; then
                x2=$(get_value "x2" "$(random_float_var "x2")")
            else
                x2="-"
            fi
            
            echo "$i $x0 $x1 $x2" >> "$TEST_CASES_FILE"
        done
        ;;
esac

total_tests=$(wc -l < "$TEST_CASES_FILE")
echo "Total tests to run: $total_tests"

# Split test cases into batches for parallel processing
if [ -z "$BATCH_SIZE" ]; then
    BATCH_SIZE=$((total_tests / (PARALLEL_JOBS * 10) + 1))
    [ $BATCH_SIZE -lt 10 ] && BATCH_SIZE=10
fi

split -l $BATCH_SIZE "$TEST_CASES_FILE" "${TEMP_DIR}/batch_"

echo "Running tests with $PARALLEL_ENGINE ($PARALLEL_JOBS parallel jobs)..."

# Progress monitoring in background
(
    while true; do
        sleep 2
        if [ -d "$TEMP_DIR" ]; then
            completed=$(cat ${TEMP_DIR}/output_* 2>/dev/null | wc -l)
            if [ $completed -gt 0 ]; then
                printf "\rProgress: %d/%d (%d%%)" "$completed" "$total_tests" $((completed * 100 / total_tests))
            fi
        else
            break
        fi
    done
) &
PROGRESS_PID=$!

# Run parallel execution based on engine
case $PARALLEL_ENGINE in
    gnu_parallel)
        ls ${TEMP_DIR}/batch_* | parallel -j $PARALLEL_JOBS --bar run_batch {} ${TEMP_DIR}/output_{#}.txt
        ;;
    xargs)
        ls ${TEMP_DIR}/batch_* | xargs -P $PARALLEL_JOBS -I {} bash -c 'run_batch "$1" "${1/batch_/output_}.txt"' -- {}
        ;;
    none)
        for batch in ${TEMP_DIR}/batch_*; do
            output_file="${batch/batch_/output_}.txt"
            run_batch "$batch" "$output_file"
        done
        ;;
esac

# Stop progress monitoring
kill $PROGRESS_PID 2>/dev/null
wait $PROGRESS_PID 2>/dev/null

echo -e "\nCombining results..."

# Combine all output files in order
for output in ${TEMP_DIR}/output_*.txt; do
    if [ -f "$output" ]; then
        cat "$output" >> "$OUTPUT_FILE"
    fi
done

echo "Tests completed. Results saved to: $OUTPUT_FILE"

# Generate summary statistics
echo -e "\n=== Summary Statistics ==="
echo "Test pattern: $TEST_PATTERN"
echo "Total tests: $total_tests"
echo "Parallel jobs used: $PARALLEL_JOBS"

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

# Clean up
rm -rf "$TEMP_DIR"
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