# Upstream Baseline

`upstream-expected-results/` is one unchanged copy of the result data that was already present in the FlakeSync Docker artifact before this investigation.

The workspace contained two full baseline snapshots named “Existing Initial Container” and “Latest Session Container.” SHA-256 comparison found all 440 relative files identical, with no changed or unique file in either copy. The duplicate snapshot was therefore removed from the Git repository.

Folder names were normalized, but the generated filenames and file contents were preserved:

- `locations/`
- `minimizer-results/`
- `boundary-results/`
- `barrier-results/`

These files are reference data and must not be confused with the new runs under `results/`.

