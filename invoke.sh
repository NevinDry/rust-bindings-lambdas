#!/usr/bin/env bash
# Usage: ./invoke.sh <function-name> <emoji> <label> <payload-file>
# Example: ./invoke.sh devoxx-python 🐍 "Python" payload.json

set -e

FN_NAME="$1"
EMOJI="$2"
LABEL="$3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAYLOAD_FILE="${SCRIPT_DIR}/$4"
TMPFILE=$(mktemp /tmp/lambda-result-XXXX.json)
BAR_WIDTH=50

# Colors
BOLD="\033[1m"
DIM="\033[2m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"

echo ""
echo -e "${BOLD}${EMOJI}  ${LABEL} Lambda — ${FN_NAME}${RESET}"
echo ""

# Launch invoke in background
aws lambda invoke \
  --function-name "$FN_NAME" \
  --payload "file://${PAYLOAD_FILE}" \
  --cli-binary-format raw-in-base64-out \
  "$TMPFILE" > /dev/null 2>&1 &
PID=$!

# Track elapsed time with a growing progress bar
START_NS=$(date +%s%N)

while kill -0 "$PID" 2>/dev/null; do
  ELAPSED_MS=$(( ($(date +%s%N) - START_NS) / 1000000 ))
  FILLED=$(( ELAPSED_MS / 100 ))
  [[ $FILLED -gt $BAR_WIDTH ]] && FILLED=$BAR_WIDTH
  EMPTY=$(( BAR_WIDTH - FILLED ))

  BAR=$(printf '█%.0s' $(seq 1 $FILLED 2>/dev/null) )
  SPACE=$(printf '░%.0s' $(seq 1 $EMPTY 2>/dev/null) )

  printf "\r  ${CYAN}⏱${RESET}  ${BOLD}%5d ms${RESET}  ${YELLOW}[${BAR}${DIM}${SPACE}${RESET}${YELLOW}]${RESET}" "$ELAPSED_MS"
  sleep 0.05
done

wait "$PID"

# Final time
ELAPSED_MS=$(( ($(date +%s%N) - START_NS) / 1000000 ))
FILLED=$(( ELAPSED_MS / 100 ))
[[ $FILLED -gt $BAR_WIDTH ]] && FILLED=$BAR_WIDTH
EMPTY=$(( BAR_WIDTH - FILLED ))

BAR=$(printf '█%.0s' $(seq 1 $FILLED 2>/dev/null) )
SPACE=$(printf '░%.0s' $(seq 1 $EMPTY 2>/dev/null) )

printf "\r  ${CYAN}⏱${RESET}  ${BOLD}%5d ms${RESET}  ${YELLOW}[${BAR}${DIM}${SPACE}${RESET}${YELLOW}]${RESET}" "$ELAPSED_MS"
echo ""

# Parse and display result
BODY=$(cat "$TMPFILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(json.loads(d['body']),indent=2))" 2>/dev/null || cat "$TMPFILE")

echo ""
echo -e "  ${GREEN}✅ Result:${RESET}"
echo "$BODY" | sed 's/^/     /'
echo ""

# Append result to shared benchmark file if set
if [[ -n "$BENCHMARK_FILE" ]]; then
  RUST_MS=$(cat "$TMPFILE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.loads(d['body']).get('elapsed_ms','?'))" 2>/dev/null || echo '?')
  echo "${EMOJI}|${LABEL}|${ELAPSED_MS}|${RUST_MS}" >> "$BENCHMARK_FILE"
fi

rm -f "$TMPFILE"
