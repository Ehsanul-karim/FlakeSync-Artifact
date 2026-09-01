#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <single-test-csv>"
    exit 1
fi

INPUT="$1"
BASE="/home/java8-flakesync/scripts"
OUT="/home/java8-flakesync/experiment_results/batch"
mkdir -p "$OUT"

line=$(grep -v '^#' "$INPUT" | head -n 1)

if [[ -z "$line" ]]; then
    echo "No test found in $INPUT"
    exit 1
fi

test_name=$(echo "$line" | cut -d',' -f4 | sed 's;\[;\\[;g' | sed 's;\\;.;')
safe_name=$(echo "$test_name" | tr '/#:$[] ' '_')

echo "TEST=$test_name"

cd "$BASE" || exit 1

now_ns() {
    date +%s%N
}

seconds_between() {
    awk -v start="$1" -v end="$2" 'BEGIN { printf "%.3f", (end-start)/1000000000 }'
}

# ---------- Stage 1 ----------
echo "===== STAGE 1: delay injection + minimization ====="
s1_start=$(now_ns)

bash delay_injection_and_minimized_locations.sh "$INPUT" \
    > "$OUT/${safe_name}_stage1.log" 2>&1
s1_rc=$?

s1_end=$(now_ns)
s1_sec=$(seconds_between "$s1_start" "$s1_end")

if [[ $s1_rc -ne 0 ]]; then
    echo "Stage 1 failed. See $OUT/${safe_name}_stage1.log"
    exit $s1_rc
fi

# ---------- Stage 2 ----------
echo "===== STAGE 2: root method + critical point ====="
s2_start=$(now_ns)

bash root_method_and_critical_point_search.sh \
    "Results-Minimizer/${test_name}_Actual_Location.csv" tmp \
    > "$OUT/${safe_name}_stage2.log" 2>&1
s2_rc=$?

s2_end=$(now_ns)
s2_sec=$(seconds_between "$s2_start" "$s2_end")

if [[ $s2_rc -ne 0 ]]; then
    echo "Stage 2 failed. See $OUT/${safe_name}_stage2.log"
    exit $s2_rc
fi

# ---------- Stage 3 ----------
echo "===== STAGE 3: barrier search ====="
s3_start=$(now_ns)

bash barrier_point_search.sh \
    "Results-Boundary/Boundary-${test_name}-Result.csv" \
    > "$OUT/${safe_name}_stage3.log" 2>&1
s3_rc=$?

s3_end=$(now_ns)
s3_sec=$(seconds_between "$s3_start" "$s3_end")

if [[ $s3_rc -ne 0 ]]; then
    echo "Stage 3 failed. See $OUT/${safe_name}_stage3.log"
    exit $s3_rc
fi

total_sec=$(awk -v a="$s1_sec" -v b="$s2_sec" -v c="$s3_sec" \
    'BEGIN { printf "%.3f", a+b+c }')

METRICS="$OUT/stage_runtimes.csv"

if [[ ! -f "$METRICS" ]]; then
    echo "test,stage1_sec,stage2_sec,stage3_sec,total_sec" > "$METRICS"
fi

echo "\"$test_name\",$s1_sec,$s2_sec,$s3_sec,$total_sec" >> "$METRICS"

echo
echo "===== COMPLETE ====="
echo "Stage 1: $s1_sec sec"
echo "Stage 2: $s2_sec sec"
echo "Stage 3: $s3_sec sec"
echo "Total:   $total_sec sec"
echo "Logs:    $OUT"
echo "Metrics: $METRICS"

echo
echo "===== EXTRACTING CANDIDATE METRICS ====="
bash /home/java8-flakesync/scripts/extract_flakesync_metrics.sh "$test_name"
# Preserve barrier-search trace
cp -f "$BASE/tmp-log" "$OUT/${safe_name}_barrier_tmp.log" 2>/dev/null || true
