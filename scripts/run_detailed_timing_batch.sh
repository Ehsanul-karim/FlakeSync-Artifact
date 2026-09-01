#!/usr/bin/env bash
set -u

if [[ $# -lt 1 || $# -gt 3 ]]; then
    echo "Usage: $0 <input-csv> [max-tests] [timeout-per-test]"
    exit 1
fi

INPUT="$1"
MAX="${2:-0}"
LIMIT="${3:-2h}"
BASE="/home/java8-flakesync/scripts"
OUT="/home/java8-flakesync/experiment_results/separated_stage2_timing"
WORK="$OUT/batch-inputs"
PROGRESS="$OUT/batch_progress.csv"
mkdir -p "$WORK"

if [[ ! -f "$PROGRESS" ]]; then
    echo 'test,status,started_at,finished_at' > "$PROGRESS"
fi

count=0
while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    [[ "$MAX" -gt 0 && "$count" -ge "$MAX" ]] && break

    test_name=$(echo "$line" | cut -d',' -f4)
    safe_name=$(echo "$test_name" | tr '/#:$[] ' '_')
    one="$WORK/${safe_name}.csv"
    printf '%s\n' "$line" > "$one"
    started=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    echo "RUNNING: $test_name"
    timeout "$LIMIT" bash "$BASE/run_detailed_timing.sh" "$one"
    rc=$?

    if [[ $rc -eq 0 ]]; then
        status="COMPLETED"
    elif [[ $rc -eq 124 ]]; then
        status="TIMEOUT"
    else
        status="FAILED_$rc"
    fi

    finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '"%s",%s,"%s","%s"\n' "$test_name" "$status" "$started" "$finished" >> "$PROGRESS"
    echo "FINISHED: $test_name -> $status"
    count=$((count + 1))
done < "$INPUT"

echo "Batch attempts: $count"
echo "Progress: $PROGRESS"
echo "Timings:  $OUT/timings.csv"
