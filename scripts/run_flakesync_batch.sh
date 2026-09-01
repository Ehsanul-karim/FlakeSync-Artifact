#!/usr/bin/env bash
set -u

if [[ $# -lt 1 || $# -gt 2 ]]; then
    echo "Usage: $0 <input-csv> [max-tests]"
    exit 1
fi

INPUT="$1"
MAX="${2:-0}"

BASE="/home/java8-flakesync/scripts"
OUT="/home/java8-flakesync/experiment_results/batch"
WORK="$OUT/inputs"
PROGRESS="$OUT/batch_progress.csv"
RUNTIMES="$OUT/stage_runtimes.csv"

mkdir -p "$WORK"

if [[ ! -f "$PROGRESS" ]]; then
    echo 'test,status,start_time,end_time' > "$PROGRESS"
fi

count=0

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^# ]] && continue

    test_name=$(echo "$line" | cut -d',' -f4)

    if [[ -z "$test_name" ]]; then
        continue
    fi

    # Skip tests whose runtime was already recorded successfully.
    if [[ -f "$RUNTIMES" ]] && grep -Fq "\"$test_name\"," "$RUNTIMES"; then
        echo "SKIP already completed: $test_name"
        continue
    fi

    if [[ "$MAX" -gt 0 && "$count" -ge "$MAX" ]]; then
        break
    fi

    safe=$(echo "$test_name" | tr '/#:$[] ' '_')
    one="$WORK/${safe}.csv"

    printf '%s\n' "$line" > "$one"

    start=$(date -Iseconds)

    echo
    echo "============================================================"
    echo "RUNNING: $test_name"
    echo "============================================================"

    timeout 2h "$BASE/run_instrumented_flakesync.sh" "$one"
    rc=$?

    if [[ $rc -eq 124 ]]; then
        status="TIMEOUT"
    elif [[ $rc -ne 0 ]]; then
        status="FAILED"
    else
        result_line=$(awk -F',' -v t="$test_name" '$4==t {line=$0} END{print line}' "$BASE/Results-Barrier/Result.csv" 2>/dev/null)

        if [[ -n "$result_line" ]] &&
           [[ "$result_line" != *"not-works"* ]] &&
           [[ "$result_line" != *",0,1,FALSE"* ]]; then
            status="REPAIRED"
        else
            status="NOT_REPAIRED"
        fi
    fi

    end=$(date -Iseconds)

    printf '"%s",%s,"%s","%s"\n' \
        "$test_name" "$status" "$start" "$end" >> "$PROGRESS"

    count=$((count + 1))

    echo "CHECKPOINT: $test_name -> $status"
done < "$INPUT"

echo
echo "Batch finished."
echo "Tests attempted this run: $count"
echo "Progress: $PROGRESS"
echo "Runtimes: $RUNTIMES"
