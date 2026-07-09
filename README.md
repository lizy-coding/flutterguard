# FlutterGuard

> IoT Flutter project static analysis CLI for architecture enforcement, code quality, and CI gating.

[English](README.md) | [中文](README.zh.md)

FlutterGuard scans Flutter/Dart source code and reports architecture boundary breaches, lifecycle/resource leaks, dependency cycles, and size-related code quality issues. The active path is `packages/flutterguard_cli/`; the legacy runtime-tracing packages are archived under `archive/`.

**Platforms**: macOS, Windows, Linux — pure Dart CLI, no native dependencies.

**Docs**: [Usage Guide](docs/USAGE.md) | [Configuration Strategy](CONFIGURATION_STRATEGY.md) | [Windows Assessment](docs/WINDOWS_ASSESSMENT.md) | [Spec](docs/FLUTTERGUARD_SPEC.md) | [Architecture](docs/ARCHITECTURE.md)

## What It Is

- A CLI for static analysis of Flutter/Dart projects
- A YAML-driven architecture enforcement tool
- An IoT/smart-home aware rule set for Flutter codebases
- A CI gate that can fail builds on severity thresholds or score thresholds

## What It Is Not

- Not a runtime observability or APM SDK
- Not a crash reporter
- Not a general-purpose Dart linter
- Not a web dashboard or Flutter widget library
- Does not require an API key and does not upload APKs

## Requirements

- Dart SDK 3.3.0 or newer
- `melos` for workspace bootstrap when running from source
- Supported OS: macOS, Windows, Linux

---

## Install

### Option A: pub.dev install (recommended)

<details open>
<summary><b>macOS / Linux</b></summary>

```bash
dart pub global activate flutterguard_cli

# Verify
flutterguard --version
```

Ensure `$HOME/.pub-cache/bin` is on your `PATH`:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"   # add to ~/.zshrc or ~/.bashrc
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
dart pub global activate flutterguard_cli

# Verify
flutterguard --version
```

If the command is not found, ensure `%USERPROFILE%\AppData\Local\Pub\Cache\bin` is on your `PATH`:

```powershell
$env:Path += ";$env:USERPROFILE\AppData\Local\Pub\Cache\bin"
```
</details>

### Option B: GitHub Release binary (no Dart SDK at runtime)

Download the matching binary from the GitHub Releases page, then run it
directly:

<details open>
<summary><b>macOS / Linux</b></summary>

```bash
chmod +x flutterguard
./flutterguard --version
./flutterguard scan .
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
.\flutterguard.exe --version
.\flutterguard.exe scan .
```
</details>

### Option C: source checkout for development

Use the local launcher when you want to run the current checkout without
installing or replacing the global `flutterguard` command.

<details>
<summary><b>macOS / Linux</b></summary>

```bash
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub get
./scripts/flutterguard-dev --version
./scripts/flutterguard-dev scan .
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub get
.\scripts\flutterguard-dev.ps1 --version
.\scripts\flutterguard-dev.ps1 scan .
```
</details>

---

## Quick Start

```bash
# Scan the current directory
flutterguard scan

# Create and validate a starter config
flutterguard init --profile migration
flutterguard config doctor
flutterguard doctor install

# Inspect the merged effective config
flutterguard config print

# Scan a specific project
flutterguard scan ./my_flutter_app          # macOS / Linux
flutterguard scan .\my_flutter_app          # Windows

# Scan with explicit path flag
flutterguard scan -p /path/to/project       # macOS / Linux
flutterguard scan -p D:\path\to\project     # Windows

# JSON output with CI gate
flutterguard scan . --format json --fail-on high

# Baseline existing issues before enabling a hard CI gate
flutterguard baseline create .
flutterguard baseline stats
flutterguard baseline check . --baseline .flutterguard/baseline.json --no-growth
flutterguard scan . --baseline .flutterguard/baseline.json --fail-on high

# GitHub Code Scanning output
flutterguard scan . --format sarif --baseline .flutterguard/baseline.json

# Export one finding for false-positive feedback
flutterguard issue export --rule mqtt_connection --file lib/device/mqtt.dart --line 42

# Show help
flutterguard --help
flutterguard scan --help
```

### Demo target

```bash
flutterguard scan examples/scan_demo
```

---

## CLI Reference

Commands:

| Command | Description |
|---------|-------------|
| `flutterguard scan [<path>]` | Scan a project (path defaults to current directory) |
| `flutterguard baseline create [<path>]` | Create a baseline JSON file for existing issues |
| `flutterguard baseline stats` | Show baseline fingerprint counts |
| `flutterguard baseline prune [<path>]` | Remove fixed issues from a baseline |
| `flutterguard baseline check [<path>] --no-growth` | Fail when current issues are missing from baseline |
| `flutterguard doctor install` | Diagnose executable version and PATH conflicts |
| `flutterguard init` | Create a starter `flutterguard.yaml` |
| `flutterguard init --profile migration` | Create a starter config from a profile |
| `flutterguard init --with-architecture` | Create config with architecture layer/module templates |
| `flutterguard config print` | Print the merged effective configuration |
| `flutterguard config doctor` | Validate config, globs, and architecture references |
| `flutterguard issue export` | Export one issue as a local feedback JSON bundle |
| `flutterguard rules` | List available rules |
| `flutterguard explain <rule-id>` | Explain one rule |
| `flutterguard --help` / `-h` | Show usage |
| `flutterguard --version` / `-V` | Show version |

### Scan options

| Flag | Short | Default | Description |
|------|-------|---------|-------------|
| `<path>` | — | `.` | Positional project path (optional, before options) |
| `--path` | `-p` | `.` | Project path to scan (overridden by positional `<path>`) |
| `--config` | `-c` | `flutterguard.yaml` | Config file path |
| `--format` | `-f` | `table` | Output format: `table`, `json`, or `sarif` |
| `--output` | `-o` | `.flutterguard` | Output directory for reports |
| `--verbose` | `-v` | off | Show detailed output with code context |
| `--no-color` | — | off | Disable ANSI terminal colors |
| `--changed-only` | — | off | Only scan Dart files changed since `--base` |
| `--base` | — | `main` | Git base ref for `--changed-only` |
| `--baseline` | — | unset | Baseline JSON file used to hide existing issues |
| `--fail-on` | — | `none` | CI gate: `none` / `high` / `medium` / `low` |
| `--min-score` | — | unset | Minimum score threshold 0–100 |
| `--help` | `-h` | — | Show scan usage |

### Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success (includes help/version output and no-files-found) |
| `1` | CI gate failed (issues at/above `--fail-on` level, or score below `--min-score`) |
| `2` | Scan error (bad path, config parse error) |

### Path resolution

FlutterGuard auto-discovers the project root by walking up from the current directory, looking for `flutterguard.yaml`, `pubspec.yaml`, or a `lib/` directory. If none are found, it falls back to the current directory.

The `--config` path is resolved with this priority:
1. Absolute path (`-c /path/to/config.yaml`) — used as-is
2. Relative path matching a file from CWD (`-c my_config.yaml`) — resolved from CWD
3. Relative path matching a file from the project root — fallback

---

## Configuration

Create `flutterguard.yaml` in your project root.

Recommended strategy:

1. Start with zero config: `flutterguard scan`.
2. Run `flutterguard init` when you need custom thresholds or excludes.
3. Use `flutterguard config print` to inspect merged defaults.
4. Use `flutterguard config doctor` before enabling CI gates.
5. Add architecture layers/modules only after project boundaries are agreed.

For the full decision model, see [Configuration Strategy](CONFIGURATION_STRATEGY.md).

### Basic config (for most users)

```yaml
include:
  - lib/**

exclude:
  - lib/generated/**
  - lib/**.g.dart
  - lib/**.freezed.dart
  - lib/**.mocks.dart

rules:
  large_file:
    enabled: true
    maxLines: 500
  large_class:
    enabled: true
    maxLines: 300
  large_build_method:
    enabled: true
    maxLines: 80
  lifecycle_resource:
    enabled: true
  missing_const_constructor:
    enabled: true
  device_lifecycle:
    enabled: true
  mqtt_connection:
    enabled: true
  ble_scanning:
    enabled: true
    maxScanDurationMs: 10000
  iot_security:
    enabled: true
    requireTls: true
  pubspec_security:
    enabled: true
```

### Full config (with architecture enforcement)

```yaml
# ... include/exclude/rules from basic config above ...

architecture:
  layers:
    - name: presentation
      path: lib/presentation/**
      allowed_deps: [domain, core]
    - name: domain
      path: lib/domain/**
      allowed_deps: [core]
    - name: data
      path: lib/data/**
      allowed_deps: [domain, core]
    - name: core
      path: lib/core/**
      allowed_deps: []

  modules:
    - name: device_mqtt
      path: lib/device/mqtt/**
      allowed_deps: [domain, core]
    - name: device_ble
      path: lib/device/ble/**
      allowed_deps: [domain, core]

  detect_cycles: true
  layer_violation:
    enabled: true
  module_violation:
    enabled: true
```

> **Important**: Architecture rules (`layer_violation`, `module_violation`, `circular_dependency`) require explicit `architecture.layers`, `architecture.modules`, and/or `architecture.detect_cycles` declarations in your config. They do not auto-discover project boundaries.

> **Glob patterns**: Always use forward slashes (`/`) in YAML config, even on Windows. Do not use backslashes.

---

## Rules

| Rule ID | Level | Domain | Priority | What it checks | Config required |
|---------|-------|--------|----------|----------------|-----------------|
| `large_file` | LOW | standards | P2 | File line count over `maxLines` | — |
| `large_class` | LOW | standards | P2 | Class body line count over `maxLines` | — |
| `large_build_method` | MEDIUM | performance | P1 | `build()` method line count over `maxLines` | — |
| `lifecycle_resource_not_disposed` | MEDIUM | performance | P1 | Undisposed StreamSubscription, Timer, AnimationController, TextEditingController, ScrollController, FocusNode, MqttClient, BluetoothDevice, StreamController | — |
| `missing_const_constructor` | LOW | standards | P2 | Widget classes missing a `const` constructor | — |
| `layer_violation` | HIGH | architecture | P0 | Importing across forbidden architecture layers | `architecture.layers` * |
| `module_violation` | HIGH | architecture | P0 | Importing across forbidden business modules | `architecture.modules` * |
| `circular_dependency` | MEDIUM | architecture | P1 | File-level import cycles | `architecture.detect_cycles` * |
| `device_lifecycle` | HIGH | architecture | P0 | Unbalanced init/teardown pairs (initState↔dispose, connect↔disconnect, etc.) | — |
| `mqtt_connection` | HIGH | architecture | P0 | MQTT connect/disconnect pairing, hardcoded broker URLs | — |
| `iot_security` | HIGH | architecture | P0 | Hardcoded credentials, cleartext MQTT/HTTP, insecure BLE | `rules.iot_security.requireTls` |
| `ble_scanning` | MEDIUM | architecture | P1 | BLE startScan/stopScan pairing, scan timeout | `rules.ble_scanning.maxScanDurationMs` |
| `pubspec_security` | MEDIUM | standards | P2 | Unbounded deps, deprecated packages, outdated IoT dependencies | — |

<sub>* Requires explicit YAML configuration to activate.</sub>

---

## Output

### Terminal table (default)

Colored terminal report grouped by domain. Shows overall score, file count, issue count, and per-issue detail.

### JSON report

`--format json` writes `.flutterguard/report.json` under the output directory.

Example shape:

```json
{
  "version": "1.0.0",
  "generatedAt": "2026-06-09T12:00:00.000Z",
  "projectPath": "/path/to/project",
  "score": 85,
  "summary": {
    "total": 3,
    "high": 1,
    "medium": 1,
    "low": 1,
    "suppressed": 0,
    "suppressedByBaseline": 0,
    "byDomain": {
      "architecture": { "high": 1, "medium": 0, "low": 0, "total": 1 }
    }
  },
  "issues": []
}
```

### SARIF report

`--format sarif` writes `.flutterguard/report.sarif` for GitHub Code Scanning. High, medium, and low map to SARIF `error`, `warning`, and `note`.

### Suppression and baseline

Use source suppression for known false positives:

```dart
// flutterguard: ignore missing_const_constructor
// flutterguard: ignore iot_security, mqtt_connection
// flutterguard: ignore all
```

Suppression applies only to the comment line and the following line.

Recommended CI adoption order:

```bash
flutterguard config doctor
flutterguard baseline create .
flutterguard baseline check . --baseline .flutterguard/baseline.json --no-growth
flutterguard scan . --baseline .flutterguard/baseline.json --format json --fail-on high
```

## Scoring

```
score = max(0, 100 - high×10 - medium×4 - low×1)
```

| Score | Rating |
|-------|--------|
| 80–100 | Excellent |
| 50–79 | Needs review |
| 0–49 | Needs action |

---

## CI Integration

### GitHub Actions

```yaml
name: FlutterGuard

on: [push, pull_request]

jobs:
  scan:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: 3.3.0
      - name: Install FlutterGuard
        run: dart pub global activate flutterguard_cli
      - name: Scan
        run: flutterguard scan . --format json --baseline .flutterguard/baseline.json --fail-on high --min-score 80
```

### GitHub Code Scanning

```yaml
name: FlutterGuard SARIF

on: [push, pull_request]

jobs:
  code-scanning:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: 3.3.0
      - run: dart pub global activate flutterguard_cli
      - run: flutterguard scan . --format sarif --baseline .flutterguard/baseline.json
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: .flutterguard/report.sarif
```

### GitLab CI

```yaml
flutterguard:
  image: dart:3.3.0
  script:
    - dart pub global activate flutterguard_cli
    - flutterguard scan . --format json --fail-on high --min-score 80
  artifacts:
    paths:
      - .flutterguard/report.json
    when: always
```

### pre-commit hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: flutterguard
        name: FlutterGuard scan
        entry: flutterguard scan . --fail-on high
        language: system
        pass_filenames: false
        always_run: true
```

### Local scripts

<details>
<summary><b>macOS / Linux</b></summary>

```bash
#!/usr/bin/env bash
# scan_ci.sh
flutterguard scan . --format json --fail-on high --min-score 80
if [ $? -eq 0 ]; then
    echo "All checks passed!"
else
    echo "CI gate failed! Check .flutterguard/report.json for details."
    exit 1
fi
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
# scan_ci.ps1
$ErrorActionPreference = "Stop"
flutterguard scan . --format json --fail-on high --min-score 80

if ($LASTEXITCODE -eq 0) {
    Write-Host "All checks passed!" -ForegroundColor Green
} else {
    Write-Host "CI gate failed! Check .flutterguard/report.json for details." -ForegroundColor Red
    exit 1
}
```
</details>

---

## Troubleshooting

### Windows: ANSI colors show as raw escape codes

Use **Windows Terminal** (built into Windows 10/11) instead of legacy `cmd.exe`. Alternatively, add `--no-color` to disable ANSI output:

```powershell
flutterguard scan . --no-color
```

### Windows: "API key required" error

This means the shell is resolving an old globally-installed binary instead of this repository's static-analysis CLI. Run the local binary directly:

```powershell
.\flutterguard.exe scan .
```

Or reinstall:

```powershell
dart pub global deactivate flutterguard_cli
dart pub global activate flutterguard_cli
```

### Windows: garbled Chinese output

```powershell
# In PowerShell, set UTF-8 output encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# Or use Windows Terminal (recommended) which defaults to UTF-8
```

### Glob patterns: always use forward slashes

In `flutterguard.yaml`, use `/` for all path patterns regardless of platform:

```yaml
# Correct
path: lib/presentation/**

# Wrong (even on Windows)
path: lib\presentation\**
```

---

## Repository Layout

```
flutterguard/
├── packages/
│   └── flutterguard_cli/   Active CLI implementation
├── archive/                Frozen legacy runtime-tracing packages
└── examples/
    └── scan_demo/          Demo scan target
```

## Development

```bash
# All platforms
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub get
dart pub global activate melos
melos bootstrap

# Common commands
dart run melos run analyze     # Static analysis
dart run melos run test:cli    # Run tests
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
```

## Further Reading

| Document | Content |
|----------|---------|
| [docs/USAGE.md](docs/USAGE.md) | Full usage guide (all platforms) |
| [docs/WINDOWS_ASSESSMENT.md](docs/WINDOWS_ASSESSMENT.md) | Windows compatibility assessment |
| [docs/FLUTTERGUARD_SPEC.md](docs/FLUTTERGUARD_SPEC.md) | Technical specification |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Architecture overview |

## License

MIT
