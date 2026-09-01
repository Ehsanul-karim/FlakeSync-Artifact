# Luwak Investigation

Test: `uk.co.flax.luwak.matchers.TestPartitionMatcher#testParallelSlowLog`

The detailed run started at 2026-09-01 15:43:04 UTC and was stopped by the
investigator at 16:41:50 UTC after 58.765 minutes. Stage 1 and both separated
Stage-2 subphases completed. Stage 3 did not find a barrier before it was
stopped, so this run must not be reported as a completed repair.

Checkpoint timings derived from the timestamped run artifacts are:

- Stage 1: approximately 244.410 seconds.
- root-method discovery: 118.373 seconds (instrumented marker).
- individual critical-line search: 185.355 seconds (instrumented marker).
- Stage-2 wrapper: approximately 303.853 seconds.
- Stage 3 before interruption: approximately 2977.620 seconds.
- total elapsed before interruption: approximately 3525.883 seconds.

Stage 2 identified `PartitionMatcher$MatcherWorker#call` and a critical region
from line 131 through line 138. The executed critical candidates were 131, 133,
135, and 138; all four reproduced the failure.

Stage 3 completed 93 unsuccessful threshold-1 candidates: test lines 113 down
through 98, followed by `java.lang.reflect.Method` lines 498 down through 422.
It was stopped before candidate 421. The search had entered JDK reflection code
with an inherited method-start value of 98, creating a very large and low-value
candidate range. No fresh `Results-Barrier/Result.csv` row was generated.

`raw/` contains the stage logs, generated minimizer/boundary CSVs, barrier trace,
and all 93 completed per-candidate barrier logs. `partial-timing.env` and
`candidate-summary.txt` record the reviewed checkpoint in compact form.
