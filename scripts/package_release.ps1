$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $PSScriptRoot
$pubspec = Join-Path $rootDir "packages\flutterguard_cli\pubspec.yaml"
$versionLine = Select-String -Path $pubspec -Pattern "^version:" | Select-Object -First 1
$version = ($versionLine.Line -split "\s+")[1]
$src = Join-Path $rootDir "packages\flutterguard_cli\bin\flutterguard.dart"
$dist = Join-Path $rootDir "dist"
$name = "flutterguard-$version-windows-x64"
$outDir = Join-Path $dist $name
$bin = Join-Path $outDir "flutterguard.exe"
$archive = Join-Path $dist "$name.zip"

if (Test-Path $outDir) {
    Remove-Item -Recurse -Force $outDir
}
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

dart compile exe $src -o $bin
& $bin --version

if (Test-Path $archive) {
    Remove-Item -Force $archive
}
Compress-Archive -Path $outDir -DestinationPath $archive
Write-Host "Release artifact: $archive"
