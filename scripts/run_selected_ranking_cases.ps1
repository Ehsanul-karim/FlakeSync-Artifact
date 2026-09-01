param(
    [string]$Container = "flakesync-work",
    [string]$TimeoutPerTest = "4h",
    [int]$MaxTests = 0,
    [ValidateSet("planned-ranking-cases.csv", "luwak.csv", "delight-nashorn-sandbox.csv", "rxjava2-extras.csv")]
    [string]$InputFile = "planned-ranking-cases.csv"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$importRoot = Join-Path $repoRoot "results\imported\separated_stage2_timing"

$running = docker inspect --format '{{.State.Running}}' $Container 2>$null
if ($LASTEXITCODE -ne 0 -or $running -ne "true") {
    throw "Docker container '$Container' is not running."
}

docker cp "$PSScriptRoot/." "${Container}:/home/java8-flakesync/scripts/"
if ($LASTEXITCODE -ne 0) { throw "Failed to copy investigation scripts." }

docker cp "$(Join-Path $repoRoot 'data\inputs')/." "${Container}:/home/java8-flakesync/scripts/data_list/"
if ($LASTEXITCODE -ne 0) { throw "Failed to copy input CSV files." }

docker exec $Container bash -n /home/java8-flakesync/scripts/prepare_selected_case_checkouts.sh /home/java8-flakesync/scripts/run_selected_ranking_cases.sh /home/java8-flakesync/scripts/run_detailed_timing_batch.sh /home/java8-flakesync/scripts/run_detailed_timing.sh /home/java8-flakesync/scripts/root_method_and_critical_point_search.sh
if ($LASTEXITCODE -ne 0) { throw "A container-side shell script failed syntax validation." }

try {
    docker exec $Container bash /home/java8-flakesync/scripts/run_selected_ranking_cases.sh $TimeoutPerTest $MaxTests $InputFile
    if ($LASTEXITCODE -ne 0) { throw "The selected-case runner exited with code $LASTEXITCODE." }
}
finally {
    New-Item -ItemType Directory -Force -Path $importRoot | Out-Null
    docker cp "${Container}:/home/java8-flakesync/experiment_results/separated_stage2_timing/." $importRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not copy container results into '$importRoot'."
    }
}

Write-Host "Container results copied to $importRoot"
