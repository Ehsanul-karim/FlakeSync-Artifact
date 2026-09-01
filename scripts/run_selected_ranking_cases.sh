#!/usr/bin/env bash
set -u

if [[ $# -gt 3 ]]; then
    echo "Usage: $0 [timeout-per-test] [max-tests] [input-csv-name]"
    exit 1
fi

BASE="/home/java8-flakesync/scripts"
LIMIT="${1:-4h}"
MAX="${2:-0}"
INPUT_NAME="${3:-planned-ranking-cases.csv}"
INPUT="$BASE/data_list/$INPUT_NAME"

if [[ ! -s "$INPUT" ]]; then
    echo "Missing planned-case input: $INPUT"
    exit 1
fi

echo "Preparing offline delta-debugging checkouts."
bash "$BASE/prepare_selected_case_checkouts.sh"

echo "Running selected ranking cases with a $LIMIT limit per test."
echo "Completed detailed runs already present in timings.csv will be skipped."
bash "$BASE/run_detailed_timing_batch.sh" "$INPUT" "$MAX" "$LIMIT"
