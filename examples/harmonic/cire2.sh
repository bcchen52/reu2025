#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <source>.c" >&2
  exit 1
fi

SRC="$1"
NAME="${SRC%.*}"
LL="${NAME}_O1.ll"

CLANG=/uufs/chpc.utah.edu/common/home/u1260704/Tools/llvm-clone/llvm/build-release/bin/clang
CIRE=/uufs/chpc.utah.edu/common/home/u1260704/Tools/CIRE/build-debug/bin/CIRE_LLVM

# 1) Compile only at -O1
"$CLANG" -O1 \
         -fno-unroll-loops \
         -fno-slp-vectorize \
         -fno-vectorize \
         -fno-optimize-sibling-calls \
         -fno-math-errno -fno-builtin -fno-trapping-math \
         -D__NO_MATH_INLINES \
         -S -emit-llvm \
         "$SRC" -o "$LL"

# 2) Extract your kernel's name
FUNC=$(grep -m1 -oP '^define\s+.*?@(\w+)' "$LL" \
       | sed -E 's/.*@([A-Za-z0-9_]+).*/\1/')
if [[ -z "$FUNC" ]]; then
  echo "❌  Couldn't find any function in $LL" >&2
  exit 1
fi
echo "✅  Compiled IR in $LL; function = $FUNC"

# 3) Prepare consolidated log
LOG="${NAME}_cire_grid_$(date +%Y%m%d_%H%M%S).txt"
cat > "$LOG" <<EOF
================================================================================
CIRE grid sweep for $NAME @ -O1
Function: $FUNC
Generated: $(date)
================================================================================

EOF

# 3) Prepare the two one‑column CSVs
OUTCSV="output_low.csv"
ERRCSV="errors.csv"
echo "low"   > "$OUTCSV"
echo "error" > "$ERRCSV"

# 4) Sweep x0,x1
STEP=0.01
for x0 in $(seq 0.00 $STEP 0.99); do
  for x1 in $(seq 0.00 $STEP 0.99); do
    # Build input
    x0_hi=$(awk -v lo="$x0" -v s="$STEP" 'BEGIN{printf("%.2f", lo + s)}')
    x1_hi=$(awk -v lo="$x1" -v s="$STEP" 'BEGIN{printf("%.2f", lo + s)}')
    INPUT_FILE=$(mktemp /tmp/${NAME}_x0_${x0}_x1_${x1}.cire.XXXX)
    cat > "$INPUT_FILE" <<EOF
INPUTS {
  x0 fl64 : ( ${x0}, ${x0_hi} );
  x1 fl64 : ( ${x1}, ${x1_hi} );
}
OUTPUTS { y0 fl64; }
EOF

    # Run CIRE and log
    CIRE_OUT=$(
      $CIRE "$LL" --function "$FUNC" --input "$INPUT_FILE" --debug-level 1 \
        2>&1 | tee -a "$LOG"
    )i
    CIRE_RC=${PIPESTATUS[0]}

    if [[ $CIRE_RC -eq 0 ]]; then
  if read output_lo err_hi < <(
    printf '%s\n' "$CIRE_OUT" | awk '
      # collect last square-bracket Output and first square-bracket Error
      /Output:/ { if (match($0,/Output:[[:space:]]*\[([^]]+)\]/,o)) split(o[1],A,",") }
      /Error:/  { if (!got && match($0,/Error:[[:space:]]*\[([^]]+)\]/,e)) { split(e[1],B,","); got=1 } }
      END {
        ol=A[1]; eh=B[2];
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",ol);
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",eh);
        if (ol=="") ol="0";      # default if no [] Output found
        if (eh=="") eh="0";      # default if no [] Error found
        print ol, eh;
      }'
  ); then
    :
  else
    output_lo=100000; err_hi=100000
  fi
else
  output_lo=0; err_hi=0
fi
    
    # Append just the requested columns
    echo "$output_lo" >> "$OUTCSV"
    echo "$err_hi"   >> "$ERRCSV"

    rm "$INPUT_FILE"
  done
done

echo "✅ Done! See consolidated results in $LOG"
