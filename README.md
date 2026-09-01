# FlakeSync Runtime and Candidate-Search Investigation

This repository records my investigation of the FlakeSync artifact. The work focuses on two questions: where FlakeSync spends its runtime, and how many critical/barrier candidates it evaluates before finding a successful location.

This is an investigation companion, not a copy of the complete FlakeSync implementation. The original Docker artifact is required to reproduce the runs; the scripts here are additions or instrumented replacements that should be copied into `/home/java8-flakesync/scripts/` in that artifact.

## Main findings

| Test | Stage 1: delay + minimization | Stage 2: root + critical | Stage 3: barrier | Main observation |
|---|---:|---:|---:|---|
| Wasp | 142.264 s | 143.355 s | 262.351 s | Barrier search was largest (47.9%). |
| Achilles | 2051.023 s | 2698.157 s | 1734.989 s | Root + critical search was largest (41.6%). |
| Uniffle | 299.019 s | 274.267 s | 56.326 s | Minimization was largest; the run produced no valid barrier repair. |

The bottleneck varies by test. Across these runs, the combined root-method and critical-line phase is the largest component overall, while Wasp is specifically barrier-search dominated.

A later Wasp rerun separated Stage 2 into **181.840 s for root-method discovery** and **171.096 s for individual critical-line search**, with **353.026 s wrapper time**. These figures were recorded manually because the generated separated-timing directory was not copied back from the container. The corresponding Achilles rerun did not complete the critical-line phase, so no complete split is reported for Achilles.

Candidate order provides the clearest optimization signal:

- Wasp critical search: 3 candidates; the first successful location, line 308, ranked 1/3.
- Wasp barrier search: 23 candidates; the successful barrier, line 87, ranked 23/23.
- Achilles critical search: 6 candidates; the first successful location, line 159, ranked 2/6.
- Achilles barrier search: 26 candidates; the successful barrier, line 207, ranked 26/26.

In both completed barrier searches, FlakeSync's backward line-by-line order found the successful barrier last. This is preliminary evidence—not yet a cross-project general conclusion—that source- and trace-aware ranking could reduce expensive confirmation runs.

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

## What remains incomplete

- The detailed Achilles rerun reached root-method processing but did not finish the individual critical-line phase.
- Java-WebSocket was stopped during Stage 1 because its 639 initial candidates made the run too long.
- HTTP Core could not start because its project checkout was missing from `projects-For-Delta`.
- Uniffle reached the beginning-of-root failure case but did not yield a valid barrier repair.
- Luwak, Delight Nashorn Sandbox, and RxJava2 Extras are selected in `data/inputs/planned-ranking-cases.csv` but have not been executed in this investigation.
- No concrete test has yet been identified where FlakeSync fails specifically because multiple critical–barrier synchronization relationships are required.
- The ranking observations currently come from only two completed barrier searches and need validation on more tests.

## Interpretation boundary

The CSVs distinguish wrapper time from FlakeSync's internal recorded time. Candidate counts describe executed confirmation candidates, not every syntactically possible source line. Blank fields mean the phase was not completed or no trustworthy value was preserved; they are not zeros.
