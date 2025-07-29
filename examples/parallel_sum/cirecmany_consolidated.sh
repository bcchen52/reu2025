#!/usr/bin/env bash
# ------------------------------------------------------------
# cirecmany_consolidated — build IR at multiple optimisation levels for N files
# and consolidate all results into a single file
#
#   Usage: ./cirecmany_consolidated <file1.cpp> [file2.cpp ...]
# ------------------------------------------------------------
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <source1.cpp> [source2.cpp ...]" >&2
  exit 1
fi

CLANG=/uufs/chpc.utah.edu/common/home/u1260704/Tools/llvm-clone/llvm/build-release/bin/clang
CIRE=/uufs/chpc.utah.edu/common/home/u1260704/Tools/CIRE/build-debug/bin/CIRE_LLVM
LEVELS=(O1 O2 O3 Os)
FASTMATH_FLAGS=("")
INPUT_BIN=/uufs/chpc.utah.edu/common/home/u6068923/reu2025/examples/parallel_sum/inputs/parallel_sum1.cire
# Create consolidated output file with timestamp
CONSOLIDATED_FILE="$HOME/cire_analysis_$(date +%Y%m%d_%H%M%S).txt"

module load gcc/13.1.0

# Initialize consolidated file with header
cat > "$CONSOLIDATED_FILE" << EOF
================================================================================
CIRE Floating-Point Error Analysis Report
Generated: $(date)
Optimization Levels: ${LEVELS[*]}
================================================================================

EOF

echo "Starting analysis... Results will be saved to: $CONSOLIDATED_FILE"

for SRC in "$@"; do
  if [[ ! -f "$SRC" ]]; then
    echo "❌  File not found: $SRC" >&2
    echo "❌  File not found: $SRC" >> "$CONSOLIDATED_FILE"
    continue
  fi

  BASE="$(basename "$SRC")"          # e.g. sqrt1.cpp
  NAME="${BASE%.*}"                  # sqrt1

  # Add file header to consolidated output
  cat >> "$CONSOLIDATED_FILE" << EOF

################################################################################
SOURCE FILE: $SRC
################################################################################

EOF

  for OPT in "${LEVELS[@]}"; do
      for FM in "${FASTMATH_FLAGS[@]}"; do
	    FM_TAG=${FM#-}
	    TAG="${OPT}${FM_TAG:+.${FM_TAG}}"
	    LL="$HOME/${NAME}_${TAG}.ll"
	    OUT="$HOME/${NAME}_${TAG}.result"

	    # Add optimization level header
	    echo "=== OPTIMIZATION LEVEL: $OPT ===" >> "$CONSOLIDATED_FILE"
	    echo "File: $BASE | Optimization: -$OPT | Generated: $(date)" >> "$CONSOLIDATED_FILE"
	    echo "" >> "$CONSOLIDATED_FILE"

	    # --- compile to bit‑code ---
	    "$CLANG" "-${OPT}" $FM \
	             -fno-unroll-loops \
                     -fno-slp-vectorize \
                     -fno-vectorize \
                     -fno-optimize-sibling-calls \
                     -fno-math-errno -fno-builtin -fno-trapping-math \
                     -D__NO_MATH_INLINES \
	             -S -emit-llvm \
		     "$SRC" -o "$LL"

	    # pick first function in the module

	    FUNC=$(grep -m1 -oP 'define\s+.*?@(\w+)' "$LL" \
	       | sed -E 's/.*@([A-Za-z0-9_]+).*/\1/')

	    if [[ -z "$FUNC" ]]; then
	      echo "[cirecmany] no function detected" > "$OUT"
	      echo "⚠️   Skipped $LL — no function symbols" >&2
	      echo "ERROR: No function symbols detected" >> "$CONSOLIDATED_FILE"
	      echo "" >> "$CONSOLIDATED_FILE"
	      continue
	    fi

	    echo "Function analyzed: $FUNC" >> "$CONSOLIDATED_FILE"
	    echo "----------------------------------------" >> "$CONSOLIDATED_FILE"

	    # --- run CIRE_LLVM; survive crashes ---
	    CIRE_ARGS=( "$LL" --function "$FUNC" --input "$INPUT_BIN" --debug-level 1 )

	    if "$CIRE" "${CIRE_ARGS[@]}" > "$OUT" 2>&1; then
	      echo "✅  $OUT (opt ${OPT})"
	      # Append CIRE results to consolidated file
	      cat "$OUT" >> "$CONSOLIDATED_FILE"
	    else
	      echo "❌  CIRE seg‑faulted on ${NAME} at ${OPT}" >&2
	      echo "[cirecmany] CIRE_LLVM crashed (opt ${OPT})" >> "$OUT"
	      echo "ERROR: CIRE_LLVM crashed during analysis" >> "$CONSOLIDATED_FILE"
	      # Still include the error message in consolidated file
	      cat "$OUT" >> "$CONSOLIDATED_FILE"
	    fi

	    echo "" >> "$CONSOLIDATED_FILE"
	    echo "----------------------------------------" >> "$CONSOLIDATED_FILE"
	    echo "" >> "$CONSOLIDATED_FILE"
  	done
    done
done

# Add summary footer
cat >> "$CONSOLIDATED_FILE" << EOF

================================================================================
ANALYSIS COMPLETE
Total files processed: $#
Optimization levels tested: ${LEVELS[*]}
Completed: $(date)
================================================================================
EOF

echo ""
echo "✅  Analysis complete! Consolidated results saved to:"
echo "    $CONSOLIDATED_FILE"
echo ""
echo "You can view the results with:"
echo "    less $CONSOLIDATED_FILE"
echo "    cat $CONSOLIDATED_FILE"
