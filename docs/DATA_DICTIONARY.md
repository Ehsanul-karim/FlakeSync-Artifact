# Summary CSV Data Dictionary

## `stage-runtimes.csv`

Each row is one full wrapper run.

- `run_id`: repository-local identifier; reruns must use distinct IDs.
- `test_id`: short project label used across summary files.
- `status`: `COMPLETED`, `NO_REPAIR`, `ABANDONED`, or `SETUP_FAILED`.
- `stage1_sec`: delay injection plus minimization wall-clock time.
- `stage2_root_plus_critical_sec`: combined root-method and critical-line wall-clock time.
- `stage3_barrier_sec`: barrier-stage wrapper wall-clock time.
- `total_sec`: sum of the three stages.
- `slowest_stage`: largest measured wrapper stage.
- `notes`: interpretation or incompleteness warning.

## `stage2-breakdown.csv`

Each row is a later run using the detailed Stage-2 instrumentation.

- `measurement_quality`: `RECORDED_MANUALLY`, `CSV_PRESERVED`, or `INCOMPLETE_OBSERVATION`.
- `root_method_sec`: root discovery including its setup and confirmation executions.
- `critical_line_sec`: time inside the individual line scan.
- `stage2_wrapper_sec`: wall-clock time around the complete Stage-2 script.
- `unassigned_overhead_sec`: wrapper minus the two measured subphases.
- Empty numeric cells mean a trustworthy exact value was not preserved.

## `candidate-search.csv`

Each row describes one search phase for one test.

- `candidates_tested`: confirmation candidates actually executed.
- `successful_candidates`: count of candidates that reproduced the desired outcome.
- `first_success_rank`: one-based position of the first successful candidate.
- `reported_location`: first critical success, successful barrier, or beginning-of-root location.
- `candidate_order`: semicolon-separated executed line numbers where available.
- `result`: `SUCCESS`, `BEGINNING_OF_ROOT_FAILURE`, or `NO_VALID_REPAIR`.

For a backward search from line 232 through 207 inclusive, `candidates_tested` is `232 - 207 + 1 = 26`.

## `run-status.csv`

This is the authoritative scope table. It prevents a selected input, a partially run test, or a no-repair execution from being mistaken for a completed successful repair.

## Original generated aggregates

`results/generated/` preserves the CSVs emitted during the experiments:

- `stage-runtimes.csv`: original wrapper timings for Achilles and Uniffle;
- `candidate-metrics.csv`: extractor output for Achilles and Uniffle;
- `wasp-metrics.csv`: the earlier Wasp timing and candidate record;
- `batch-progress.csv`: status recorded by the early batch runner.

The early batch runner wrote `SUCCESS` when the wrapper returned successfully, even when a valid repair was absent. Use `results/summary/run-status.csv` for the reviewed outcome. The curated summaries also combine the separately stored Wasp record with the later batch records and normalize blank/no-repair fields.
