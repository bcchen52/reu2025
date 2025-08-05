#!/bin/bash
# Compile parallel_sum.c using Verificarlo
# Test parallel summation with MCA for numerical stability analysis

set -e
export LC_ALL=C

# Check all arguments
if [ "$#" -lt 8 ] || [ "$#" -gt 9 ]; then
  echo "usage: run.sh source.c type vprecision mode start end step iterations [output_dir]"
  echo "      source.c is the C source file to compile and test"
  echo "      type is the precision type [FLOAT | DOUBLE]"
  echo "      vprecision is the MCA Virtual Precision (a positive integer)"
  echo "      mode is MCA Mode, one of [ mca | pb | rr ]"
  echo "      start is the starting value for input range"
  echo "      end is the ending value for input range"
  echo "      step is the increment between values"
  echo "      iterations is the number of MCA runs per input value"
  echo "      output_dir is the output directory (optional, default: ./results)"
  echo ""
  echo "example: ./run.sh parallel_sum.c FLOAT 24 mca 0.0 10.0 0.5 20"
  echo "example: ./run.sh parallel_sum.c FLOAT 24 mca 0.0 10.0 0.5 20 ./my_results"
  exit 1
fi

SOURCE_FILE=$1
REAL=$2
VERIFICARLO_PRECISION=$3
VERIFICARLO_MCAMODE=$4
START=$5
END=$6
STEP=$7
ITERATIONS=$8
OUTPUT_DIR=${9:-"./results"}  # Default to ./results if not specified

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
	echo "Invalid MCA mode '${VERIFICARLO_MCAMODE}', choose between [mca | pb | rr]"
	exit 1
esac

# Validate numeric inputs
if ! [[ "$VERIFICARLO_PRECISION" =~ ^[0-9]+$ ]] || [ "$VERIFICARLO_PRECISION" -lt 1 ]; then
    echo "Error: vprecision must be a positive integer"
    exit 1
fi

# Print configuration
echo "=== Verificarlo Configuration ==="
echo "Source file: $SOURCE_FILE"
echo "Program name: $PROGRAM_NAME"
echo "Precision type: $REAL"
echo "Precision: $VERIFICARLO_PRECISION bits"
echo "MCA Mode: $VERIFICARLO_MCAMODE"
echo "Input range: [$START:$STEP:$END]"
echo "Iterations per value: $ITERATIONS"
echo "Output directory: $OUTPUT_DIR"
echo "================================"

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file '$SOURCE_FILE' not found!"
    exit 1
fi

# Extract program name from source file
PROGRAM_NAME=$(basename "$SOURCE_FILE" .c)

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Compile with verificarlo
echo "Compiling $SOURCE_FILE with Verificarlo..."
verificarlo -D${REAL} "$SOURCE_FILE" -o "$PROGRAM_NAME" -lm

# Set up MCA backend
export VFC_BACKENDS="libinterflop_mca.so --precision-binary32=$VERIFICARLO_PRECISION --precision-binary64=$VERIFICARLO_PRECISION --mode $VERIFICARLO_MCAMODE"

# Create output file with header
OUTPUT_FILE="$OUTPUT_DIR/${PROGRAM_NAME}-${REAL}-p${VERIFICARLO_PRECISION}-${VERIFICARLO_MCAMODE}.tab"

# Check if output file already exists
if [ -f "$OUTPUT_FILE" ]; then
    echo "Warning: Output file already exists: $OUTPUT_FILE"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted. Please rename or move the existing file."
        exit 1
    fi
fi

echo "Writing results to: $OUTPUT_FILE"
echo "# Verificarlo Analysis for $PROGRAM_NAME" > $OUTPUT_FILE
echo "# Source: $SOURCE_FILE" >> $OUTPUT_FILE
echo "# Type: $REAL, Precision: $VERIFICARLO_PRECISION, Mode: $VERIFICARLO_MCAMODE" >> $OUTPUT_FILE
echo "# Range: [$START:$STEP:$END], Iterations: $ITERATIONS" >> $OUTPUT_FILE
echo "i x result" >> $OUTPUT_FILE

# Run iterations
echo "Running MCA analysis..."

# Calculate total number of values for progress tracking
total_values=$(python3 -c "import math; print(int(math.floor(($END - $START) / $STEP) + 1))")
current=0

for x in $(seq $START $STEP $END); do
    current=$((current + 1))
    percent=$(python3 -c "print(f'{$current * 100 / $total_values:.1f}')")
    printf "\rProgress: %d/%d (%s%%) - Processing x=%s..." "$current" "$total_values" "$percent" "$x"
    
    for i in $(seq 1 $ITERATIONS); do
        result=$(./"$PROGRAM_NAME" $x 2>/dev/null)
        echo "$i $x $result" >> $OUTPUT_FILE
    done
done

echo -e "\nAnalysis complete!"

echo "Analysis complete!"
echo "Output file: $OUTPUT_FILE"

# Generate summary statistics
echo -e "\n=== Summary Statistics ==="
echo "Total test points: $total_values"
echo "Total MCA runs: $((total_values * ITERATIONS))"

# Calculate and display execution time
DURATION=$SECONDS
MINUTES=$((DURATION / 60))
SECONDS_REMAINING=$((DURATION % 60))

echo -e "\n=== Execution Time ==="
if [ $MINUTES -gt 0 ]; then
    echo "Total time: ${MINUTES}m ${SECONDS_REMAINING}s"
else
    echo "Total time: ${SECONDS_REMAINING}s"
fi

echo ""
echo "To plot results, run:"
echo "  ./plot_verificarlo.py $OUTPUT_FILE $VERIFICARLO_PRECISION"

# Clean up the compiled executable
echo -e "\nCleaning up..."
rm -f "$PROGRAM_NAME"

echo -e "\nDone!"
