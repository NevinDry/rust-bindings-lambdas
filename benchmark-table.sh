#!/usr/bin/env bash
# Usage: benchmark-table.sh <results-file>
# Each line in results-file: emoji|label|total_ms|fib_ms

RESULTS_FILE="$1"

BOLD="\033[1m"
CYAN="\033[36m"
YELLOW="\033[33m"
GREEN="\033[32m"
RESET="\033[0m"

COL_LABEL=24
COL_MS=12

# Each row visual width = 1+2+7+2+24+2+15+2+15+2+1 = 73  → inner = 71 dashes
BORDER="───────────────────────────────────────────────────────────────────────"

# Sort results by fib only time (col 4) ascending
SORTED=$(sort -t'|' -k4 -n "$RESULTS_FILE")

echo ""
echo -e "${BOLD}${CYAN}┌${BORDER}┐${RESET}"
# Header: 11 spaces = 2 (margin) + 7 (emoji visual) + 2 (sep) — matching data rows
printf "${BOLD}${CYAN}│${RESET}           %-${COL_LABEL}s  %${COL_MS}s ms  %${COL_MS}s ms  ${CYAN}│${RESET}\n" \
  "Language" "invocation" "fib only"
echo -e "${BOLD}${CYAN}├${BORDER}┤${RESET}"

RANK=0
while IFS='|' read -r emoji label total_ms rust_ms; do
  RANK=$(( RANK + 1 ))

  if [[ $RANK -eq 1 ]]; then
    COLOR="${GREEN}${BOLD}"
    MEDAL=" 🥇"
  elif [[ $RANK -eq 2 ]]; then
    COLOR="${YELLOW}${BOLD}"
    MEDAL=" 🥈"
  elif [[ $RANK -eq 3 ]]; then
    COLOR=""
    MEDAL=" 🥉"
  else
    COLOR="${RESET}"
    MEDAL="   "
  fi

  # Print emoji raw (always 7 visual cols: 2 double-wide emojis + medal)
  # then printf for the rest — avoids printf miscounting emoji width
  printf "${CYAN}│${RESET}  "
  printf "%s  " "${emoji}${MEDAL}"
  printf "${COLOR}%-${COL_LABEL}s${RESET}  %${COL_MS}s ms  %${COL_MS}s ms  ${CYAN}│${RESET}\n" \
    "$label" "$total_ms" "$rust_ms"
done <<< "$SORTED"

echo -e "${BOLD}${CYAN}└${BORDER}┘${RESET}"
echo ""
