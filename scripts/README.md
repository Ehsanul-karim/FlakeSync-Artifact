# Investigation Scripts

These files extend or instrument the scripts already present in the original FlakeSync Docker image. Copy them to `/home/java8-flakesync/scripts/`; do not try to run this directory as a standalone implementation.

Recommended entry points:

- `run_instrumented_flakesync.sh`: original three-stage timing.
- `run_detailed_timing.sh`: full timing with Stage 2 split.
- `run_stage2_smoke_timing.sh`: Stage-2-only timing from an existing minimized result.
- `run_flakesync_batch.sh` and `run_detailed_timing_batch.sh`: batch orchestration.

`root_method_and_critical_point_search.sh` is the only included upstream script replacement. It adds timing markers required by the detailed runners.

Run shell syntax checks after copying:

```bash
bash -n /home/java8-flakesync/scripts/*.sh
```

