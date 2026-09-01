#!/usr/bin/env bash
set -u

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <test-name>"
    exit 1
fi

TEST="$1"
BASE="/home/java8-flakesync/scripts"
OUT="/home/java8-flakesync/experiment_results/batch"
SAFE=$(echo "$TEST" | tr '/#:$[] ' '_')

S1="$OUT/${SAFE}_stage1.log"
S2="$OUT/${SAFE}_stage2.log"
BTRACE="$OUT/${SAFE}_barrier_tmp.log"
RESULTS="$BASE/Results-Barrier/Result.csv"
CSV="$OUT/candidate_metrics.csv"

# Preserve the barrier trace before another test can overwrite tmp-log.
if [[ -s "$BASE/tmp-log" ]]; then
    cp -f "$BASE/tmp-log" "$BTRACE"
fi

critical_tested_lines=$(
    grep -oE 'I am sequential jjj=[0-9]+' "$S2" 2>/dev/null |
    sed 's/.*=//' |
    awk '!seen[$0]++' |
    paste -sd';' -
)

critical_candidates=0
if [[ -n "$critical_tested_lines" ]]; then
    critical_candidates=$(awk -F';' '{print NF}' <<< "$critical_tested_lines")
fi

critical_success_lines=$(
    grep -oE 'Sequential EROOR / Failure Found at Line [0-9]+' "$S2" 2>/dev/null |
    grep -oE '[0-9]+$' |
    awk '!seen[$0]++' |
    paste -sd';' -
)

root_methods=$(
    grep 'combined location=' "$S2" 2>/dev/null |
    sed 's/.*combined location= *//' |
    awk '!seen[$0]++' |
    paste -sd';' -
)

root_method_count=0
if [[ -n "$root_methods" ]]; then
    root_method_count=$(awk -F';' '{print NF}' <<< "$root_methods")
fi

minimization_counts=$(
    grep -Eio '(locationCount|location count|locations size|size of.*location|number of.*location)[^0-9]*[0-9]+' "$S1" 2>/dev/null |
    grep -oE '[0-9]+$' |
    paste -sd';' -
)

result_line=$(
    awk -F',' -v t="$TEST" '$4==t {line=$0} END{print line}' "$RESULTS" 2>/dev/null
)

boundary_point=""
barrier_point=""
barrier_threshold=""
barrier_recorded_sec=""
barrier_success_line=""
barrier_success_class=""
barrier_trace_start=""
barrier_method_start=""
barrier_candidate_count=""
barrier_success_rank=""

if [[ -n "$result_line" ]]; then
    boundary_point=$(printf '%s\n' "$result_line" | awk -F',' '{print $5}')
    barrier_point=$(printf '%s\n' "$result_line" | awk -F',' '{print $6}')
    barrier_threshold=$(printf '%s\n' "$result_line" | awk -F',' '{print $7}')
    barrier_recorded_sec=$(printf '%s\n' "$result_line" | awk -F',' '{print $8}')

    if [[ "$barrier_point" =~ \#([0-9]+)$ ]]; then
        barrier_success_line="${BASH_REMATCH[1]}"
        barrier_success_class="${barrier_point%#*}"
    fi
fi

# Reconstruct exact number of attempted barrier lines.
# Each stack frame is searched max_line -> method_start.
# Stop when the reported successful barrier is reached.
if [[ -n "$barrier_success_line" && -s "$BTRACE" ]]; then
    total=0
    found=0

    while IFS='|' read -r cls max_line start_line; do
        [[ -z "$cls" || -z "$max_line" || -z "$start_line" ]] && continue

        if [[ "$cls" == "$barrier_success_class" ]] &&
           (( barrier_success_line <= max_line && barrier_success_line >= start_line )); then
            total=$((total + max_line - barrier_success_line + 1))
            barrier_trace_start="$max_line"
            barrier_method_start="$start_line"
            found=1
            break
        else
            total=$((total + max_line - start_line + 1))
        fi
    done < <(
        grep '^StackTrace item=' "$BTRACE" 2>/dev/null |
        sed -E 's/^StackTrace item=(.*)#([0-9]+),START LINE, st=====([0-9]+),.*/\1|\2|\3/'
    )

    if [[ $found -eq 1 ]]; then
        barrier_candidate_count="$total"
        barrier_success_rank="$total"
    fi
fi

HEADER='test,root_method_count,root_methods,critical_candidate_count,critical_tested_lines,critical_success_lines,minimization_counts,boundary_point,barrier_point,barrier_threshold,barrier_recorded_sec,barrier_trace_start_line,barrier_method_start_line,barrier_candidate_count,barrier_success_rank'

if [[ ! -f "$CSV" || "$(head -n 1 "$CSV")" != "$HEADER" ]]; then
    if [[ -f "$CSV" ]]; then
        cp "$CSV" "$CSV.legacy.$(date +%s)"
    fi
    echo "$HEADER" > "$CSV"
fi

# Replace an older row for this same test instead of creating duplicates.
tmp=$(mktemp)
awk -F',' -v q="\"$TEST\"" 'NR==1 || $1 != q' "$CSV" > "$tmp"
mv "$tmp" "$CSV"

printf '"%s",%s,"%s",%s,"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
    "$TEST" \
    "$root_method_count" \
    "$root_methods" \
    "$critical_candidates" \
    "$critical_tested_lines" \
    "$critical_success_lines" \
    "$minimization_counts" \
    "$boundary_point" \
    "$barrier_point" \
    "$barrier_threshold" \
    "$barrier_recorded_sec" \
    "$barrier_trace_start" \
    "$barrier_method_start" \
    "$barrier_candidate_count" \
    "$barrier_success_rank" >> "$CSV"

echo "Extracted metrics for: $TEST"
echo "Root methods:        $root_method_count"
echo "Critical candidates: $critical_candidates [$critical_tested_lines]"
echo "Critical successes:  [$critical_success_lines]"
echo "Barrier point:       $barrier_point"
echo "Barrier threshold:   $barrier_threshold"
echo "Barrier search:      $barrier_trace_start -> $barrier_success_line"
echo "Barrier candidates:  $barrier_candidate_count"
echo "Barrier rank:        $barrier_success_rank"
echo "Saved: $CSV"
