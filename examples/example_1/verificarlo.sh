#!/usr/bin/env bash
# verificarlo_runner.sh — Analyze numerical error under various optimization levels
# Usage: ./verificarlo_runner.sh <file1.c> [file2.c ...]

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <source1.c> [source2.c ...]" >&2
  exit 1
fi

# Optimization levels to test
LEVELS=(O1 O2 O3 Os)

# Create output directory and consolidated file
OUTDIR="$HOME/verificarlo_outputs"
mkdir -p "$OUTDIR"
CONSOLIDATED_FILE="$OUTDIR/verificarlo_report_$(date +%Y%m%d_%H%M%S).txt"

# Verificarlo environment config
export VFC_BACKENDS="libinterflop_mca.so --precision-binary64 53"
export VFC_BACKENDS_SILENT_LOAD="True"
export VFC_BACKENDS_LOGGER="False"

# Header for the report
cat > "$CONSOLIDATED_FILE" << EOF
================================================================================
Verificarlo Floating-Point Analysis Report
Generated: $(date)
Optimization Levels: ${LEVELS[*]}
================================================================================
EOF

# Loop over input files
for SRC in "$@"; do
  if [[ ! -f "$SRC" ]]; then
    echo "❌ File not found: $SRC" >&2
    echo "❌ File not found: $SRC" >> "$CONSOLIDATED_FILE"
    continue
  fi

  BASE="$(basename "$SRC")"
  NAME="${BASE%.*}"

  echo -e "\n################################################################################" >> "$CONSOLIDATED_FILE"
  echo "SOURCE FILE: $SRC" >> "$CONSOLIDATED_FILE"
  echo "################################################################################" >> "$CONSOLIDATED_FILE"

  for OPT in "${LEVELS[@]}"; do
    EXE="$OUTDIR/${NAME}_${OPT}.exe"
    OUT="$OUTDIR/${NAME}_${OPT}.result"

    # Compile with verificarlo at the current optimization level
    verificarlo-c "$SRC" -o "$EXE" "-${OPT}"

    echo -e "\n=== OPTIMIZATION LEVEL: $OPT ===" >> "$CONSOLIDATED_FILE"
    echo "Compiled Binary: $EXE" >> "$CONSOLIDATED_FILE"
    echo "Compiled At: $(date)" >> "$CONSOLIDATED_FILE"

    {
      echo "Input Output"
      for z in $(seq -1.0 0.01 1.0); do
        # Make sure each call is robust, even if function fails
        printf "%.2f " "$z"
        "$EXE" "$z" || echo "ERROR"
      done
    } > "$OUT"

    cat "$OUT" >> "$CONSOLIDATED_FILE"
    echo -e "\n----------------------------------------" >> "$CONSOLIDATED_FILE"
  done
done

# Footer
cat >> "$CONSOLIDATED_FILE" << EOF

================================================================================
ANALYSIS COMPLETE
Files processed: $#
Optimization levels tested: ${LEVELS[*]}
Finished: $(date)
Output Directory: $OUTDIR
================================================================================
EOF

echo -e "\n✅ Verificarlo analysis complete!"
echo "Results saved to:"
echo "  $CONSOLIDATED_FILE"