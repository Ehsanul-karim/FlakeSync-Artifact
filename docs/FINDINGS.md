# Findings and Current Research Status

## 1. Where runtime is spent

The three measured stages are:

1. delay injection and minimization;
2. root-method discovery plus individual critical-line search;
3. barrier search.

For Wasp, barrier search took 262.351 seconds, or 47.9% of the 548.0-second wrapper total. For Achilles, the combined root + critical phase took 2698.157 seconds, or 41.6% of the 6484.169-second total. For Uniffle, minimization was slightly largest at 299.019 seconds, although root + critical search (274.267 seconds) was much larger than barrier processing (56.326 seconds). The successful Delight retry took 130.006 seconds in Stage 1, 254.832 seconds in Stage 2, and 101.922 seconds in Stage 3; Stage 2 accounted for 52.3% of its 486.789-second total. RxJava2 Extras took 198.839 seconds in Stage 1, 121.262 seconds in Stage 2, and 120.663 seconds in Stage 3; minimization accounted for 45.1% of its 440.796-second total.

Therefore, there is no single stage that dominates every test. In aggregate for the five completed wrapper runs, Stage 2 was the largest component, but Wasp demonstrates that barrier search can be the test-specific bottleneck.

The later Luwak investigation was intentionally stopped during Stage 3. Its checkpoint timings were approximately 244.410 seconds for Stage 1, 303.853 seconds for Stage 2, and 2977.620 seconds in Stage 3 before interruption. Barrier search therefore accounted for 84.5% of the 3525.883-second partial run. These wrapper values are derived from timestamped artifacts; exact Stage-2 subphase markers were preserved.

### Separated Stage 2

The initial runner measured Stage 2 as one wrapper. I later added timing markers around root-method discovery and `analyzeRootMethod.sh`, which performs the individual critical-line scan.

One completed Wasp rerun recorded:

- root-method discovery: 181.840 s;
- individual critical-line search: 171.096 s;
- Stage-2 wrapper: 353.026 s;
- unassigned wrapper overhead: 0.090 s.

Root discovery was only 10.744 seconds larger in this rerun, so neither subphase overwhelmingly dominated Wasp Stage 2. These values should not be added to the earlier full-run table: they come from a separate rerun.

The detailed Achilles rerun did not complete the individual critical-line phase. Root processing was observed to take roughly 22 minutes, but the exact generated timing CSV was not preserved; this observation is intentionally not treated as a precise result.

The Luwak run recorded 118.373 seconds for root-method discovery and 185.355 seconds for individual critical-line search. The Stage-2 wrapper was approximately 303.853 seconds, leaving about 0.125 seconds of unassigned overhead.

The successful Delight retry recorded 64.696 seconds for root-method discovery and 190.084 seconds for individual critical-line search. Its 254.832-second Stage-2 wrapper left 0.052 seconds of overhead, and the individual line scan consumed 74.6% of Stage 2.

RxJava2 Extras recorded 56.802 seconds for root-method discovery and 64.412 seconds for individual critical-line search. Its 121.262-second Stage-2 wrapper left 0.048 seconds of overhead; the subphases were comparatively balanced.

## 2. Candidates explored before success

### Wasp

Critical candidates were tested in the order 308, 309, 310. Lines 308 and 310 reproduced the failure, so the first successful critical candidate ranked 1/3.

Barrier search started at failing assertion line 109 and walked backward to line 87. The successful barrier was candidate 23/23, after 22 unsuccessful candidates.

### Achilles

Critical candidates were 156, 159, 162, 163, 164, and 165. Lines 159, 162, and 163 reproduced the failure, so the first success ranked 2/6.

Barrier search walked backward from `ControlConnection#232` to `ControlConnection#207`. The successful barrier was candidate 26/26, after 25 unsuccessful candidates.

### Uniffle

FlakeSync detected failure at the beginning of the root region (`GrpcThreadPoolExecutor#177`) and did not run an individual critical-line sequence. The later barrier step did not produce a valid repair. It is therefore recorded as zero executed individual critical candidates and no successful barrier candidate, not as a completed barrier ranking result.

### Luwak

The fresh run identified `PartitionMatcher$MatcherWorker#call`. Lines 131, 133, 135, and 138 all reproduced the failure, making line 131 the first successful critical candidate at rank 1/4.

BarrierSearch completed 93 threshold-1 candidates without success before manual interruption: `ConcurrentMatcherTestBase` lines 113 through 98, followed by `java.lang.reflect.Method` lines 498 through 422. The JDK reflection frame inherited method-start line 98, creating a 401-line candidate range. This is evidence of an expensive search-path artifact, not evidence that no Luwak repair exists. No fresh successful barrier location was produced.

### Delight Nashorn Sandbox

The first attempt minimized to `JsEvaluator#59`, but the injected delay did not reproduce the failure in Stage 2. On the successful retry, minimization selected `ThreadMonitor#180`, and root discovery identified `JsEvaluator#run`.

Critical candidates 53, 54, 59, 67, and 68 all reproduced the failure, so the first success ranked 1/5. BarrierSearch walked backward from `NashornSandboxImpl#241` to the successful line 233, which ranked 9/9 after eight unsuccessful candidates.

### RxJava2 Extras

The only executed critical candidate, `Flowables$4#306`, reproduced the failure and ranked 1/1. Three JUnit assertion frames were present in the failure trace but had no resolved method-start lines, so BarrierSearch executed no candidates in them. In the project test frame, it tried lines 69, 68, and 67; line 67 repaired the test at rank 3/3.

Across Wasp, Achilles, Delight, and RxJava2 Extras, every completed barrier search found its successful location last: ranks 23/23, 26/26, 9/9, and 3/3 respectively.

## 3. Signals that may help candidate ranking

The Wasp evidence is concrete:

- critical line 308 performs `running.put(t, r)`, directly updating shared executor state;
- successful barrier line 87 is an assertion immediately after a polling loop;
- the loop checks an asynchronously updated counter and calls `Thread.sleep`;
- the failure later occurs at line 109 when the expected asynchronous progress has not completed.

The Achilles critical region lies in asynchronous Cassandra startup, and the successful barrier lies in DataStax driver's control-connection path. Both are on concurrency-relevant execution paths rather than arbitrary application statements.

Luwak reinforces the critical-point signal: every executed critical candidate lies in `MatcherWorker.call`, which iterates match tasks on an executor worker. Its incomplete barrier run also exposes a negative ranking signal: JDK reflection frames are far removed from the project assertion and produced dozens of unsuccessful candidates, so project/test frames should be preferred and reflection infrastructure should be strongly deprioritized or excluded.

Delight supplies a particularly direct synchronization signal. `JsEvaluator#run` registers the worker thread, executes the script operation, and reports completion to `ThreadMonitor`; the successful barrier at `NashornSandboxImpl#233` calls `evaluator.runMonitor()` immediately after submitting that evaluator to the executor. Ranking the submit/monitor handoff above later exception-checking statements would have placed the successful barrier first instead of ninth.

RxJava2 Extras shows a similar test-side signal. Critical line 306 resets asynchronously cached state inside a scheduled worker. The successful barrier at test line 67 is the final `timed.subscribe()` immediately before the assertion at line 69 and after two sleep/reset cycles. Ranking subscription and lifecycle operations related to the critical state above the assertion itself would have reduced this search from three candidates to one.

Promising ranking features are therefore:

- writes to shared state in worker, callback, executor, or lifecycle methods;
- statements in threads present in the failure trace;
- assertions immediately following polling, waiting, sleeping, joining, or notification logic;
- proximity and data-flow relation to the failed assertion;
- previously discovered critical/root locations and their thread identities.

These are hypotheses supported by four completed examples across four projects. The sample remains small, but the repeated last-ranked barrier outcome provides concrete motivation for a ranking technique.

## 4. Multiple synchronization relationships

No concrete multi-synchronization failure case has been established. Wasp and Achilles each produced one successful critical-region/barrier relationship. A future experiment must first define evidence that a failure truly requires two or more synchronization relationships, then distinguish that condition from ordinary timeout, setup, and no-repair failures.

## Run-specific limitations

- Wasp's separated Stage-2 numbers were manually transcribed because the output directory was not backed up.
- Achilles has a complete original three-stage run, but its later separated Stage-2 rerun is incomplete.
- The Achilles minimized location uses a 1600 ms delay at `AchillesCassandraConfig#69`; the discovered root result uses a 25600 ms delay at `ServerStarter#163`.
- The raw `Results-Barrier/Result.csv` appends repeated headers and stores the Uniffle no-repair row in a malformed parenthesized form. The curated summary CSVs normalize those records without modifying the raw file.
- Runtime comparisons use wrapper wall-clock values unless a field is explicitly labeled as internal time.
- Luwak was externally stopped during Stage 3. Its Stage 1/Stage 2 outputs and 93 completed barrier-candidate logs are preserved, but it has no fresh barrier result and must remain classified as incomplete.
- Delight's first detailed attempt produced a minimized location that did not reproduce the failure in Stage 2. Only the successful retry is used for runtime and candidate rankings.
