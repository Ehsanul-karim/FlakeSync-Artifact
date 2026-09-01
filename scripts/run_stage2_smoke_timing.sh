#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <single-test-csv>"
    exit 1
fi

INPUT="$1"
BASE="/home/java8-flakesync/scripts"
OUT="/home/java8-flakesync/experiment_results/separated_stage2_timing"
MASTER="$OUT/stage2_smoke_timings.csv"

line=$(grep -v '^#' "$INPUT" | grep -v '^$' | head -n 1)
test_name=$(echo "$line" | cut -d',' -f4 | sed 's;\[;\\[;g' | sed 's;\\;.;')
safe_name=$(echo "$test_name" | tr '/#:$[] ' '_')
actual="$BASE/Results-Minimizer/${test_name}_Actual_Location.csv"

if [[ -z "$line" || ! -s "$actual" ]]; then
    echo "Missing input row or existing minimized location: $actual"
    exit 1
fi

run_stamp=$(date -u +%Y%m%dT%H%M%SZ)
run_dir="$OUT/smoke-runs/$safe_name/$run_stamp"
mkdir -p "$run_dir/outputs" "$run_dir/preexisting"
cp "$INPUT" "$run_dir/input.csv"

# FlakeSync appends these per-test files. Archive and clear them so this smoke
# run measures exactly one fresh root-method result and one fresh line scan.
for generated in \
    "$BASE/Results-Boundary/${test_name}-Result.csv" \
    "$BASE/Results-Boundary/Boundary-${test_name}-Result.csv"; do
    if [[ -f "$generated" ]]; then
        cp "$generated" "$run_dir/preexisting/"
        rm -f "$generated"
    fi
done

start=$(date +%s%N)
cd "$BASE" || exit 1
bash root_method_and_critical_point_search.sh "$actual" tmp > "$run_dir/stage2.log" 2>&1
rc=$?
end=$(date +%s%N)
stage2_sec=$(awk -v start="$start" -v end="$end" 'BEGIN { printf "%.3f", (end-start)/1000000000 }')
root_sec=$(grep '^FLAKESYNC_ROOT_METHOD_SECONDS=' "$run_dir/stage2.log" | tail -n 1 | cut -d= -f2)
critical_sec=$(grep '^FLAKESYNC_CRITICAL_LINE_SECONDS=' "$run_dir/stage2.log" | tail -n 1 | cut -d= -f2)

cp -a "$BASE/Results-Boundary" "$run_dir/outputs/" 2>/dev/null || true

status="COMPLETED"
if [[ $rc -ne 0 || -z "$root_sec" || -z "$critical_sec" ]]; then
    status="FAILED"
fi

if [[ ! -f "$MASTER" ]]; then
    echo 'test,status,root_method_sec,critical_line_sec,stage2_total_sec,completed_at,run_directory' > "$MASTER"
fi
printf '"%s",%s,%s,%s,%s,"%s","%s"\n' \
    "$test_name" "$status" "$root_sec" "$critical_sec" "$stage2_sec" \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$run_dir" >> "$MASTER"

{
    echo "test=$test_name"
    echo "status=$status"
    echo "root_method_sec=$root_sec"
    echo "critical_line_sec=$critical_sec"
    echo "stage2_total_sec=$stage2_sec"
} > "$run_dir/timing.env"

echo "$status: $test_name"
echo "Root method:   $root_sec sec"
echo "Critical line: $critical_sec sec"
echo "Stage 2 total: $stage2_sec sec"
echo "Run directory: $run_dir"

[[ "$status" == "COMPLETED" ]]
