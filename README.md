# FlakeSync Runtime and Candidate-Search Investigation

This repository records my investigation of the FlakeSync artifact. The work focuses on two questions: where FlakeSync spends its runtime, and how many critical/barrier candidates it evaluates before finding a successful location.

This is an investigation companion, not a copy of the complete FlakeSync implementation. The original Docker artifact is required to reproduce the runs; the scripts here are additions or instrumented replacements that should be copied into `/home/java8-flakesync/scripts/` in that artifact.

## Main findings

| Test | Stage 1: delay + minimization | Stage 2: root + critical | Stage 3: barrier | Main observation |
|---|---:|---:|---:|---|
| Wasp | 142.264 s | 143.355 s | 262.351 s | Barrier search was largest (47.9%). |
| Achilles | 2051.023 s | 2698.157 s | 1734.989 s | Root + critical search was largest (41.6%). |
| Uniffle | 299.019 s | 274.267 s | 56.326 s | Minimization was largest; the run produced no valid barrier repair. |
| Luwak (stopped) | ~244.410 s | ~303.853 s | ~2977.620 s | Barrier search consumed 84.5% before the run was stopped without a repair. |
| Delight Nashorn Sandbox | 130.006 s | 254.832 s | 101.922 s | Individual critical-line search dominated Stage 2; repair succeeded. |
| RxJava2 Extras | 198.839 s | 121.262 s | 120.663 s | Minimization was largest (45.1%); repair succeeded. |

The bottleneck varies by test. Across the five completed wrappers, the combined root-method and critical-line phase is the largest component overall, while Wasp is specifically barrier-search dominated. The incomplete Luwak checkpoint was overwhelmingly barrier-search dominated.

A later Wasp rerun separated Stage 2 into **181.840 s for root-method discovery** and **171.096 s for individual critical-line search**, with **353.026 s wrapper time**. These figures were recorded manually because the generated separated-timing directory was not copied back from the container. The corresponding Achilles rerun did not complete the critical-line phase, so no complete split is reported for Achilles.

The later Luwak run preserved **118.373 s for root-method discovery** and **185.355 s for individual critical-line search**. Its barrier search was manually stopped after 93 unsuccessful threshold-1 candidates and approximately 2977.620 seconds, so Luwak is an incomplete run rather than a no-repair conclusion. Wrapper values are derived from timestamped artifacts because external termination occurred before the runner wrote its final timing row.

The successful Delight retry separated Stage 2 into **64.696 s for root-method discovery** and **190.084 s for individual critical-line search**, with **254.832 s wrapper time**. Individual line search consumed 74.6% of its Stage 2.

RxJava2 Extras separated Stage 2 into **56.802 s for root-method discovery** and **64.412 s for individual critical-line search**, with **121.262 s wrapper time**. The two subphases were comparatively balanced.

Candidate order provides the clearest optimization signal:

- Wasp critical search: 3 candidates; the first successful location, line 308, ranked 1/3.
- Wasp barrier search: 23 candidates; the successful barrier, line 87, ranked 23/23.
- Achilles critical search: 6 candidates; the first successful location, line 159, ranked 2/6.
- Achilles barrier search: 26 candidates; the successful barrier, line 207, ranked 26/26.
- Luwak critical search: 4 candidates, all successful; line 131 ranked 1/4.
- Luwak barrier search: 93 candidates completed with no success before manual interruption.
- Delight critical search: 5 candidates, all successful; line 53 ranked 1/5.
- Delight barrier search: 9 candidates; the successful barrier, line 233, ranked 9/9.
- RxJava2 Extras critical search: 1 candidate; line 306 ranked 1/1.
- RxJava2 Extras barrier search: 3 executed candidates; line 67 ranked 3/3.

In all four completed barrier searches, FlakeSync's backward line-by-line order found the successful barrier last. This is preliminary cross-project evidence—not yet a broad general conclusion—that source- and trace-aware ranking could reduce expensive confirmation runs.

## What I added

- Whole-stage and separated Stage-2 timing runners.
- A batch runner with per-test time limits and progress recording.
- Automatic extraction of root, critical-line, and barrier candidate metrics.
- Preservation of stage logs and barrier traces for auditability.
- Consolidated, human-readable timing, candidate, and run-status CSVs.

See [docs/CODE_CHANGES.md](docs/CODE_CHANGES.md) for the role of each script and [docs/FINDINGS.md](docs/FINDINGS.md) for the full analysis.

## Repository layout

```text
.
|-- baseline/                  # One unchanged copy of upstream expected outputs
|-- data/inputs/               # Reproduction inputs and selected future cases
|-- docs/                      # Findings, code changes, and CSV definitions
|-- results/
|   |-- summary/               # Start here: clean cross-test CSVs
|   |-- generated/             # Original aggregate CSVs produced by the scripts
|   |-- wasp/raw/              # Completed-run logs and generated artifacts
|   |-- achilles/raw/          # Completed-run logs and generated artifacts
|   |-- uniffle/raw/           # Completed but not repaired
|   |-- luwak/raw/             # Stage 1/2 complete; Stage 3 stopped with logs preserved
|   |-- delight-nashorn-sandbox/raw/ # Completed retry and candidate evidence
|   |-- rxjava2-extras/raw/    # Completed-run logs and candidate evidence
|   `-- incomplete/            # Stopped or setup-failed attempts
`-- scripts/                   # My instrumentation and orchestration code
```

The numbered `old/new/latest` directories were removed. Two full expected-result snapshots were exact duplicates, so only one is retained under `baseline/`. Handoff notes, personal mail history, papers, container home directories, Maven caches, checked-out projects, and the 1.45 GB Docker archive are intentionally excluded.

## Start with these files

- [results/summary/stage-runtimes.csv](results/summary/stage-runtimes.csv): wrapper runtime for the three main FlakeSync stages.
- [results/summary/stage2-breakdown.csv](results/summary/stage2-breakdown.csv): separate root-method and critical-line timing attempts.
- [results/summary/candidate-search.csv](results/summary/candidate-search.csv): candidate counts, successful ranks, and locations.
- [results/summary/run-status.csv](results/summary/run-status.csv): completed, incomplete, failed, and planned cases.
- [results/generated/](results/generated/): original machine-generated aggregate CSVs retained for provenance.
- [docs/DATA_DICTIONARY.md](docs/DATA_DICTIONARY.md): what every summary column means.

## Reproduction

Requirements: Docker, the original `flakesync-artifact:latest` image, approximately 8 GB RAM, and the artifact's Java 8 environment.

Copy these scripts over the artifact's script directory:

```bash
docker cp scripts/. flakesync-work:/home/java8-flakesync/scripts/
docker cp data/inputs/. flakesync-work:/home/java8-flakesync/scripts/data_list/
```

Run one test with whole-stage timing:

```bash
bash /home/java8-flakesync/scripts/run_instrumented_flakesync.sh \
  /home/java8-flakesync/scripts/data_list/wasp.csv
```

Run a complete timing pass with Stage 2 separated:

```bash
bash /home/java8-flakesync/scripts/run_detailed_timing.sh \
  /home/java8-flakesync/scripts/data_list/wasp.csv
```

Run only the Stage-2 split using an existing minimized-location result:

```bash
bash /home/java8-flakesync/scripts/run_stage2_smoke_timing.sh \
  /home/java8-flakesync/scripts/data_list/wasp.csv
```

Runtime varies because builds and flaky-test executions are nondeterministic. A complete Achilles run took about 108 minutes in this environment.

## Remaining limitations and selected-case outcomes

- The detailed Achilles rerun reached root-method processing but did not finish the individual critical-line phase.
- Java-WebSocket was stopped during Stage 1 because its 639 initial candidates made the run too long.
- HTTP Core could not start because its project checkout was missing from `projects-For-Delta`.
- Uniffle reached the beginning-of-root failure case but did not yield a valid barrier repair.
- Luwak completed Stage 1 and Stage 2 but was stopped during Stage 3 after 93 unsuccessful threshold-1 barrier candidates.
- No concrete test has yet been identified where FlakeSync fails specifically because multiple critical–barrier synchronization relationships are required.
- Luwak remains incomplete.
- The ranking observations currently come from four completed barrier searches and need validation on more tests. and better ranking strategy.

## Interpretation boundary

The CSVs distinguish wrapper time from FlakeSync's internal recorded time. Candidate counts describe executed confirmation candidates, not every syntactically possible source line. Blank fields mean the phase was not completed or no trustworthy value was preserved; they are not zeros.
