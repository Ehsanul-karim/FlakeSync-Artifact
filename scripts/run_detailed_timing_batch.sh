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
TIMINGS="$OUT/timings.csv"
mkdir -p "$WORK"

if [[ ! -f "$PROGRESS" ]]; then
    echo 'test,status,started_at,finished_at' > "$PROGRESS"
fi

count=0
failures=0
while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    [[ "$MAX" -gt 0 && "$count" -ge "$MAX" ]] && break

    test_name=$(echo "$line" | cut -d',' -f4)

    # Make interrupted batches safely resumable. A completed detailed run is
    # authoritative even if an earlier batch-progress row says otherwise.
    if [[ -f "$TIMINGS" ]] &&
       awk -F',' -v t="$test_name" '$1 == "\"" t "\"" && $2 == "COMPLETED" { found=1 } END { exit !found }' "$TIMINGS"; then
        echo "SKIP already completed: $test_name"
        continue
    fi

    safe_name=$(echo "$test_name" | tr '/#:$[] ' '_')
    one="$WORK/${safe_name}.csv"
    printf '%s\n' "$line" > "$one"
    started=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    echo "RUNNING: $test_name"
    timeout --kill-after=30s "$LIMIT" bash "$BASE/run_detailed_timing.sh" "$one"
    rc=$?

    if [[ $rc -eq 0 ]]; then
        status="COMPLETED"
    elif [[ $rc -eq 124 ]]; then
        status="TIMEOUT"
    else
        status="FAILED_$rc"
        failures=$((failures + 1))
    fi

    finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    printf '"%s",%s,"%s","%s"\n' "$test_name" "$status" "$started" "$finished" >> "$PROGRESS"
    echo "FINISHED: $test_name -> $status"
    count=$((count + 1))
done < "$INPUT"

echo "Batch attempts: $count"
echo "Progress: $PROGRESS"
echo "Timings:  $OUT/timings.csv"

if [[ "$failures" -gt 0 ]]; then
    echo "Unsuccessful attempts: $failures" >&2
    exit 1
fi
