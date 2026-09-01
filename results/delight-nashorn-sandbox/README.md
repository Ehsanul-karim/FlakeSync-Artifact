# Delight Nashorn Sandbox Investigation

Test: `delight.nashornsandbox.TestGetFunction#test`

The first detailed attempt completed Stage 1 but could not reproduce its newly
minimized `JsEvaluator#59` failure in Stage 2. Its key artifacts are retained
under `raw/failed-stage2-attempt/`.

The retry completed successfully and repaired the test in 486.789 seconds:

- Stage 1: 130.006 seconds.
- root-method discovery: 64.696 seconds.
- individual critical-line search: 190.084 seconds.
- Stage-2 wrapper: 254.832 seconds.
- Stage 3: 101.922 seconds.

The retry minimized to `ThreadMonitor#180` with a 100 ms delay and identified
`JsEvaluator#run` as the root method. Critical candidates 53, 54, 59, 67, and
68 all reproduced the failure, so the first success ranked 1/5. FlakeSync
reported the critical region as lines 53 through 68.

BarrierSearch tested `NashornSandboxImpl` lines 241 down through 233 and found
line 233 at rank 9/9 with threshold 1. Line 233 calls `evaluator.runMonitor()`
immediately after line 232 submits that evaluator to the executor, directly
connecting the barrier to the asynchronous worker's monitored lifecycle.

`raw/` contains the timing metadata, stage logs, minimized/root/critical CSVs,
barrier result and trace, and all nine barrier-candidate logs.
