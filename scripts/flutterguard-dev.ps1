$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $PSScriptRoot
$entrypoint = Join-Path $rootDir "packages\flutterguard_cli\bin\flutterguard.dart"
dart $entrypoint @args
