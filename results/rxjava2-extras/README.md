# RxJava2 Extras Investigation

Test: `com.github.davidmoten.rx2.FlowablesTest#testCache`

The detailed run completed successfully and repaired the test in 440.796 seconds:

- Stage 1: 198.839 seconds.
- root-method discovery: 56.802 seconds.
- individual critical-line search: 64.412 seconds.
- Stage-2 wrapper: 121.262 seconds.
- Stage 3: 120.663 seconds.

The run minimized to `Flowables$4#306` with an 800 ms delay and identified the
anonymous `Flowables$4#run` worker as the root method. Line 306 was the only
executed critical candidate and reproduced the failure, ranking 1/1.

BarrierSearch encountered three JUnit frames for which no method-start line was
resolved, so it executed no candidates in those frames. In the project test
frame it tested lines 69, 68, and 67, finding the successful barrier at line 67
with threshold 1 and rank 3/3. Line 67 is `timed.subscribe()`, immediately before
the assertion at line 69 and after the reset/sleep sequence that controls the
asynchronous cache lifecycle.

`raw/` contains the timing metadata, stage logs, minimized/root/critical CSVs,
barrier result and trace, all three executed barrier-candidate logs, and the
method-search logs for the skipped JUnit frames.
