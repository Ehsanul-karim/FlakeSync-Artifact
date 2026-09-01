# Findings and Current Research Status

## 1. Where runtime is spent

The three measured stages are:

1. delay injection and minimization;
2. root-method discovery plus individual critical-line search;
3. barrier search.

For Wasp, barrier search took 262.351 seconds, or 47.9% of the 548.0-second wrapper total. For Achilles, the combined root + critical phase took 2698.157 seconds, or 41.6% of the 6484.169-second total. For Uniffle, minimization was slightly largest at 299.019 seconds, although root + critical search (274.267 seconds) was much larger than barrier processing (56.326 seconds).

Therefore, there is no single stage that dominates every test. In aggregate for the three measured runs, Stage 2 was the largest component, but Wasp demonstrates that barrier search can be the test-specific bottleneck.

### Separated Stage 2

The initial runner measured Stage 2 as one wrapper. I later added timing markers around root-method discovery and `analyzeRootMethod.sh`, which performs the individual critical-line scan.

One completed Wasp rerun recorded:

- root-method discovery: 181.840 s;
- individual critical-line search: 171.096 s;
- Stage-2 wrapper: 353.026 s;
- unassigned wrapper overhead: 0.090 s.

Root discovery was only 10.744 seconds larger in this rerun, so neither subphase overwhelmingly dominated Wasp Stage 2. These values should not be added to the earlier full-run table: they come from a separate rerun.

The detailed Achilles rerun did not complete the individual critical-line phase. Root processing was observed to take roughly 22 minutes, but the exact generated timing CSV was not preserved; this observation is intentionally not treated as a precise result.

## 2. Candidates explored before success

### Wasp

Critical candidates were tested in the order 308, 309, 310. Lines 308 and 310 reproduced the failure, so the first successful critical candidate ranked 1/3.

Barrier search started at failing assertion line 109 and walked backward to line 87. The successful barrier was candidate 23/23, after 22 unsuccessful candidates.

### Achilles

Critical candidates were 156, 159, 162, 163, 164, and 165. Lines 159, 162, and 163 reproduced the failure, so the first success ranked 2/6.

Barrier search walked backward from `ControlConnection#232` to `ControlConnection#207`. The successful barrier was candidate 26/26, after 25 unsuccessful candidates.

### Uniffle

FlakeSync detected failure at the beginning of the root region (`GrpcThreadPoolExecutor#177`) and did not run an individual critical-line sequence. The later barrier step did not produce a valid repair. It is therefore recorded as zero executed individual critical candidates and no successful barrier candidate, not as a completed barrier ranking result.

## 3. Signals that may help candidate ranking

The Wasp evidence is concrete:

- critical line 308 performs `running.put(t, r)`, directly updating shared executor state;
- successful barrier line 87 is an assertion immediately after a polling loop;
- the loop checks an asynchronously updated counter and calls `Thread.sleep`;
- the failure later occurs at line 109 when the expected asynchronous progress has not completed.

The Achilles critical region lies in asynchronous Cassandra startup, and the successful barrier lies in DataStax driver's control-connection path. Both are on concurrency-relevant execution paths rather than arbitrary application statements.

Promising ranking features are therefore:

- writes to shared state in worker, callback, executor, or lifecycle methods;
- statements in threads present in the failure trace;
- assertions immediately following polling, waiting, sleeping, joining, or notification logic;
- proximity and data-flow relation to the failed assertion;
- previously discovered critical/root locations and their thread identities.

These are hypotheses supported by two completed examples. They are not yet shown to generalize consistently across multiple projects.

## 4. Multiple synchronization relationships

No concrete multi-synchronization failure case has been established. Wasp and Achilles each produced one successful critical-region/barrier relationship. A future experiment must first define evidence that a failure truly requires two or more synchronization relationships, then distinguish that condition from ordinary timeout, setup, and no-repair failures.

## Run-specific limitations

- Wasp's separated Stage-2 numbers were manually transcribed because the output directory was not backed up.
- Achilles has a complete original three-stage run, but its later separated Stage-2 rerun is incomplete.
- The Achilles minimized location uses a 1600 ms delay at `AchillesCassandraConfig#69`; the discovered root result uses a 25600 ms delay at `ServerStarter#163`.
- The raw `Results-Barrier/Result.csv` appends repeated headers and stores the Uniffle no-repair row in a malformed parenthesized form. The curated summary CSVs normalize those records without modifying the raw file.
- Runtime comparisons use wrapper wall-clock values unless a field is explicitly labeled as internal time.

