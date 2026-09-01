# Investigation Scripts

These files extend or instrument the scripts already present in the original FlakeSync Docker image. Copy them to `/home/java8-flakesync/scripts/`; do not try to run this directory as a standalone implementation.

Recommended entry points:

- `run_instrumented_flakesync.sh`: original three-stage timing.
- `run_detailed_timing.sh`: full timing with Stage 2 split.
- `run_stage2_smoke_timing.sh`: Stage-2-only timing from an existing minimized result.
- `run_flakesync_batch.sh` and `run_detailed_timing_batch.sh`: batch orchestration.
- `run_selected_ranking_cases.sh`: resumable detailed batch for the three cases in
  `planned-ranking-cases.csv` (four-hour default limit per test).
- `prepare_selected_case_checkouts.sh`: makes fresh delta-debugging checkouts
  from the artifact's cached repositories, avoiding a dependency on GitHub access.
- `run_selected_ranking_cases.ps1`: host-side Docker wrapper that installs the
  scripts/inputs, validates shell syntax, runs the batch, and copies results back.

`root_method_and_critical_point_search.sh` is the only included upstream script replacement. It adds timing markers required by the detailed runners.

Run shell syntax checks after copying:

```bash
bash -n /home/java8-flakesync/scripts/*.sh
```

From PowerShell on the host, run all selected ranking cases and copy the raw
results into `results/imported/separated_stage2_timing/`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_selected_ranking_cases.ps1
```

The batch is resumable: tests with a `COMPLETED` row in the detailed timing CSV
are skipped. To attempt only the next pending test, pass `-MaxTests 1`.

To bypass an incomplete earlier case and run one named input explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_selected_ranking_cases.ps1 `
  -InputFile delight-nashorn-sandbox.csv -MaxTests 1
```
