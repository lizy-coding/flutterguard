$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$src = Join-Path $rootDir "packages\flutterguard_cli\bin\flutterguard.dart"
$out = Join-Path $rootDir "flutterguard.exe"

Write-Host "==> Compiling FlutterGuard CLI..." -ForegroundColor Cyan
dart compile exe $src -o $out

if (Test-Path $out) {
    Write-Host "==> Done: $out" -ForegroundColor Green
    & $out --version
} else {
    Write-Host "==> Error: compilation failed" -ForegroundColor Red
    exit 1
}
