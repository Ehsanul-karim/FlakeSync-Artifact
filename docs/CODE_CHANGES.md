# Code Added or Modified

The scripts in this repository are meant to be placed in the original FlakeSync Docker artifact's `/home/java8-flakesync/scripts/` directory.

| Script | Type | Purpose |
|---|---|---|
| `run_instrumented_flakesync.sh` | Added | Runs Stages 1–3, records wall-clock stage times, saves stage logs, and invokes metric extraction. |
| `extract_flakesync_metrics.sh` | Added | Extracts root methods, tested/successful critical lines, barrier location, threshold, and exact barrier rank from logs and the preserved barrier trace. |
| `run_flakesync_batch.sh` | Added | Runs input rows independently, applies a two-hour limit, checkpoints status, and skips tests already present in the timing file. |
| `run_detailed_timing.sh` | Added | Performs a full run while separating root-method time from individual critical-line time and archiving pre-existing append-only outputs. |
| `run_detailed_timing_batch.sh` | Added | Applies the detailed runner to a batch with configurable count and timeout. |
| `run_stage2_smoke_timing.sh` | Added | Measures only the separated Stage-2 phases when a minimized-location CSV already exists. |
| `prepare_selected_case_checkouts.sh` | Added | Creates offline delta-debugging checkouts for the selected ranking cases from repositories cached in the artifact. |
| `run_selected_ranking_cases.sh` | Added | Runs the selected cases as a resumable detailed batch with a configurable per-test limit. |
| `run_selected_ranking_cases.ps1` | Added | Host-side Docker wrapper that installs inputs/scripts, runs the batch, and copies timestamped results back. |
| `root_method_and_critical_point_search.sh` | Instrumented upstream script | Emits `FLAKESYNC_ROOT_METHOD_SECONDS`, `FLAKESYNC_CRITICAL_LINE_SECONDS`, and the critical-line exit code without changing candidate order or success criteria. |

## Output contracts

The whole-stage runner writes under:

```text
/home/java8-flakesync/experiment_results/batch/
```

Its main files are `stage_runtimes.csv`, `candidate_metrics.csv`, per-stage logs, and a preserved barrier `tmp-log` per test.

The separated runner writes under:

```text
/home/java8-flakesync/experiment_results/separated_stage2_timing/
```

`timings.csv` contains full-run splits. `stage2_smoke_timings.csv` contains Stage-2-only runs. Each timestamped run directory stores its input, logs, timing metadata, pre-existing output backup, and generated output snapshot.

The selected-case copies of `timings.csv` and `batch_progress.csv` are retained
in the repository as `results/generated/detailed-stage2-timings.csv` and
`results/generated/detailed-batch-progress.csv`.

## Known code limitations

- Paths intentionally match the original Docker artifact and are not portable without editing `BASE`/`OUT`.
- The original artifact appends to some CSVs. The detailed runners archive and clear only the current test's per-test outputs before timing, but the earlier whole-stage runner does not.
- `run_flakesync_batch.sh` should be treated as experimental orchestration. Verify a `REPAIRED` status against the generated barrier row before using it in a large study.
- The metric extractor depends on current log phrases such as `I am sequential jjj=` and `StackTrace item=`; upstream text changes can break extraction.
