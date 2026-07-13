$ErrorActionPreference = "Stop"

$failOn = $env:FLUTTERGUARD_FAIL_ON ?? "high"
$minScore = $env:FLUTTERGUARD_MIN_SCORE ?? "80"
$rootDir = Split-Path -Parent $PSScriptRoot
$target = if ($args.Count -gt 0) { $args[0] } else { Join-Path $rootDir "examples\scan_demo" }
$launcher = Join-Path $PSScriptRoot "flutterguard-dev.ps1"

Write-Host "==> FlutterGuard CI Scan" -ForegroundColor Cyan
Write-Host "    Target:    $target"
Write-Host "    Fail-on:   $failOn"
Write-Host "    Min-score: $minScore"
Write-Host ""

& $launcher scan $target --format json --fail-on $failOn --min-score $minScore
$status = $LASTEXITCODE

if ($status -eq 0) {
    Write-Host ""
    Write-Host "All checks passed!" -ForegroundColor Green
} else {
    Write-Host ""
    if ($status -eq 1) {
        Write-Host "CI gate failed! Check $target/.flutterguard/report.json for details." -ForegroundColor Red
    } else {
        Write-Host "FlutterGuard scan setup failed with exit code $status." -ForegroundColor Red
    }
    exit $status
}
