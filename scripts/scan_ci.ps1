$ErrorActionPreference = "Stop"

$failOn = $env:FLUTTERGUARD_FAIL_ON ?? "high"
$minScore = $env:FLUTTERGUARD_MIN_SCORE ?? "80"
$target = if ($args.Count -gt 0) { $args[0] } else { "." }

Write-Host "==> FlutterGuard CI Scan" -ForegroundColor Cyan
Write-Host "    Target:    $target"
Write-Host "    Fail-on:   $failOn"
Write-Host "    Min-score: $minScore"
Write-Host ""

flutterguard scan $target --format json --fail-on $failOn --min-score $minScore

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "All checks passed!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "CI gate failed! Check .flutterguard/report.json for details." -ForegroundColor Red
    exit 1
}
