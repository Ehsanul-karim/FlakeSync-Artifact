#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <single-test-csv>"
    exit 1
fi

INPUT="$1"
BASE="/home/java8-flakesync/scripts"
OUT="/home/java8-flakesync/experiment_results/separated_stage2_timing"
RUNS="$OUT/runs"
MASTER="$OUT/timings.csv"

line=$(grep -v '^#' "$INPUT" | grep -v '^$' | head -n 1)
if [[ -z "$line" ]]; then
    echo "No test found in $INPUT"
    exit 1
fi

test_name=$(echo "$line" | cut -d',' -f4 | sed 's;\[;\\[;g' | sed 's;\\;.;')
safe_name=$(echo "$test_name" | tr '/#:$[] ' '_')
run_stamp=$(date -u +%Y%m%dT%H%M%SZ)
run_dir="$RUNS/$safe_name/$run_stamp"
mkdir -p "$run_dir"
cp "$INPUT" "$run_dir/input.csv"

# The artifact appends per-test outputs. Preserve any old copies, then remove
# only this test's generated files so every timed phase consumes one fresh row.
mkdir -p "$run_dir/preexisting"
for generated in \
    "$BASE/Results-Minimizer/${test_name}.csv" \
    "$BASE/Results-Minimizer/${test_name}_Actual_Location.csv" \
    "$BASE/Results-Boundary/${test_name}-Result.csv" \
    "$BASE/Results-Boundary/Boundary-${test_name}-Result.csv"; do
    if [[ -f "$generated" ]]; then
        cp "$generated" "$run_dir/preexisting/"
        rm -f "$generated"
    fi
done

now_ns() {
    date +%s%N
}

seconds_between() {
    awk -v start="$1" -v end="$2" 'BEGIN { printf "%.3f", (end-start)/1000000000 }'
}

csv_quote() {
    printf '%s' "$1" | sed 's/"/""/g'
}

write_record() {
    local status="$1"
    local repair_outcome="$2"
    local stage1="$3"
    local root="$4"
    local critical="$5"
    local stage2="$6"
    local barrier="$7"
    local total="$8"
    local completed_at
    completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    if [[ ! -f "$MASTER" ]]; then
        echo 'test,status,repair_outcome,stage1_sec,root_method_sec,critical_line_sec,stage2_total_sec,barrier_sec,total_sec,completed_at,run_directory' > "$MASTER"
    fi

    printf '"%s",%s,%s,%s,%s,%s,%s,%s,%s,"%s","%s"\n' \
        "$(csv_quote "$test_name")" "$status" "$repair_outcome" "$stage1" "$root" "$critical" \
        "$stage2" "$barrier" "$total" "$completed_at" "$run_dir" >> "$MASTER"

    {
        echo "test=$test_name"
        echo "status=$status"
        echo "repair_outcome=$repair_outcome"
        echo "stage1_sec=$stage1"
        echo "root_method_sec=$root"
        echo "critical_line_sec=$critical"
        echo "stage2_total_sec=$stage2"
        echo "barrier_sec=$barrier"
        echo "total_sec=$total"
        echo "completed_at=$completed_at"
    } > "$run_dir/timing.env"
}

copy_outputs() {
    mkdir -p "$run_dir/outputs"
    cp -a "$BASE/Results-Minimizer" "$run_dir/outputs/" 2>/dev/null || true
    cp -a "$BASE/Results-Boundary" "$run_dir/outputs/" 2>/dev/null || true
    cp -a "$BASE/Results-Barrier" "$run_dir/outputs/" 2>/dev/null || true
    cp -f "$BASE/tmp-log" "$run_dir/barrier_tmp.log" 2>/dev/null || true
}

cd "$BASE" || exit 1
overall_start=$(now_ns)
stage1_sec=""
root_method_sec=""
critical_line_sec=""
stage2_sec=""
barrier_sec=""

echo "===== STAGE 1: delay injection + minimization ====="
start=$(now_ns)
bash delay_injection_and_minimized_locations.sh "$INPUT" > "$run_dir/stage1.log" 2>&1
rc=$?
end=$(now_ns)
stage1_sec=$(seconds_between "$start" "$end")
if [[ $rc -ne 0 ]]; then
    total_sec=$(seconds_between "$overall_start" "$end")
    copy_outputs
    write_record "STAGE1_FAILED" "UNKNOWN" "$stage1_sec" "" "" "" "" "$total_sec"
    exit $rc
fi

echo "===== STAGE 2A: root-method search ====="
echo "===== STAGE 2B: individual critical-line search ====="
start=$(now_ns)
bash root_method_and_critical_point_search.sh \
    "Results-Minimizer/${test_name}_Actual_Location.csv" tmp \
    > "$run_dir/stage2.log" 2>&1
rc=$?
end=$(now_ns)
stage2_sec=$(seconds_between "$start" "$end")
root_method_sec=$(grep '^FLAKESYNC_ROOT_METHOD_SECONDS=' "$run_dir/stage2.log" | tail -n 1 | cut -d= -f2)
critical_line_sec=$(grep '^FLAKESYNC_CRITICAL_LINE_SECONDS=' "$run_dir/stage2.log" | tail -n 1 | cut -d= -f2)
if [[ $rc -ne 0 || -z "$root_method_sec" || -z "$critical_line_sec" ]]; then
    total_sec=$(seconds_between "$overall_start" "$end")
    copy_outputs
    write_record "STAGE2_FAILED" "UNKNOWN" "$stage1_sec" "$root_method_sec" "$critical_line_sec" "$stage2_sec" "" "$total_sec"
    exit 2
fi

echo "===== STAGE 3: barrier search ====="
start=$(now_ns)
bash barrier_point_search.sh \
    "Results-Boundary/Boundary-${test_name}-Result.csv" \
    > "$run_dir/stage3.log" 2>&1
rc=$?
end=$(now_ns)
barrier_sec=$(seconds_between "$start" "$end")
total_sec=$(seconds_between "$overall_start" "$end")

copy_outputs
if [[ $rc -ne 0 ]]; then
    write_record "STAGE3_FAILED" "UNKNOWN" "$stage1_sec" "$root_method_sec" "$critical_line_sec" "$stage2_sec" "$barrier_sec" "$total_sec"
    exit $rc
fi

result_line=$(awk -F',' -v t="$test_name" '$4==t {line=$0} END{print line}' "$BASE/Results-Barrier/Result.csv" 2>/dev/null)
repair_outcome="NO_REPAIR"
if [[ -n "$result_line" ]] &&
   [[ "$result_line" != *"not-works"* ]] &&
   [[ "$(printf '%s\n' "$result_line" | awk -F',' '{print $6}')" != "0" ]] &&
   [[ -n "$(printf '%s\n' "$result_line" | awk -F',' '{print $6}')" ]]; then
    repair_outcome="REPAIRED"
fi

write_record "COMPLETED" "$repair_outcome" "$stage1_sec" "$root_method_sec" "$critical_line_sec" "$stage2_sec" "$barrier_sec" "$total_sec"

echo "COMPLETE: $test_name"
echo "Stage 1:       $stage1_sec sec"
echo "Root method:   $root_method_sec sec"
echo "Critical line: $critical_line_sec sec"
echo "Stage 2 total: $stage2_sec sec"
echo "Barrier:       $barrier_sec sec"
echo "Total:         $total_sec sec"
echo "Repair:        $repair_outcome"
echo "Run directory: $run_dir"
echo "Master CSV:    $MASTER"
