# Uniffle Result

Status: all timing wrappers returned, but FlakeSync did not produce a valid repair.

- Stage times: 299.019 s / 274.267 s / 56.326 s.
- Failure was detected at the beginning of the root region (`GrpcThreadPoolExecutor#177`).
- No individual critical-line candidates or successful barrier candidate were recorded.

This case is useful for runtime comparison but must not be counted as a successful repair or barrier-ranking result.

The barrier trace found in the container backup was identical to the Achilles trace, indicating stale cross-run state, so it is deliberately excluded from this folder.
