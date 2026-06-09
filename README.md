# FlutterGuard

> IoT Flutter project static analysis CLI for architecture enforcement, code quality, and CI gating.

[English](README.md) | [中文](README.zh.md)

FlutterGuard scans Flutter/Dart source code and reports architecture boundary breaches, lifecycle/resource leaks, dependency cycles, and size-related code quality issues. The active path is `packages/flutterguard_cli/`; the legacy runtime-tracing packages are archived under `archive/`.

**Platforms**: macOS, Windows, Linux — pure Dart CLI, no native dependencies.

**Docs**: [Usage Guide](docs/USAGE.md) | [Windows Assessment](docs/WINDOWS_ASSESSMENT.md) | [Spec](docs/FLUTTERGUARD_SPEC.md) | [Architecture](docs/ARCHITECTURE.md)

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

## Install

<details open>
<summary><b>macOS / Linux</b></summary>

```bash
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard

dart pub global activate melos
melos bootstrap

dart pub global activate --source path packages/flutterguard_cli
flutterguard --help
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard

dart pub global activate melos
melos bootstrap

dart pub global activate --source path packages/flutterguard_cli
flutterguard --help
```

> Windows users may need `%USERPROFILE%\AppData\Local\Pub\Cache\bin` on `PATH` after global activation.
</details>

### Compile a native binary

<details open>
<summary><b>macOS / Linux</b></summary>

```bash
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
./flutterguard --help
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard.exe
.\flutterguard.exe --help
```
</details>

## Quick Start

```bash
# Scan a Flutter project (all platforms)
flutterguard scan -p /path/to/project     # macOS / Linux
flutterguard scan -p D:\path\to\project   # Windows

# Write JSON report and fail on HIGH issues
flutterguard scan -p . --format json --fail-on high

# Show help
flutterguard --help
```

### Demo target

```bash
flutterguard scan -p examples/scan_demo
```

## CLI

Commands:

- `flutterguard scan`
- `flutterguard --help`
- `flutterguard --version`

Scan options:

| Flag | Meaning | Default |
|------|---------|---------|
| `-p`, `--path` | Project path to scan | `.` |
| `-c`, `--config` | Config file path inside the project root | `flutterguard.yaml` |
| `-f`, `--format` | Output format: `table` or `json` | `table` |
| `-o`, `--output` | Output directory for generated reports | `.flutterguard` |
| `-v`, `--verbose` | Show issue detail in terminal output | off |
| `--fail-on` | CI gate threshold: `none`, `high`, `medium`, `low` | `none` |
| `--min-score` | Minimum acceptable score, 0-100 | unset |

Exit codes:

- `0` success
- `1` gate failed
- `2` scan error or invalid input

## Configuration

Create `flutterguard.yaml` in the project root:

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

Notes:

- If `flutterguard.yaml` is missing, defaults are used.
- Architecture rules require explicit `layers` and `modules`; they do not auto-discover boundaries.
- `layer_violation` and `module_violation` only work when the relevant declarations are present.

## Checks

FlutterGuard currently emits these issue IDs:

| Rule ID | Level | Domain | Priority | What it checks |
|---------|-------|--------|----------|----------------|
| `large_file` | LOW | standards | P2 | File line count over `maxLines` |
| `large_class` | LOW | standards | P2 | Class body line count over `maxLines` |
| `large_build_method` | MEDIUM | performance | P1 | `build()` method line count over `maxLines` |
| `lifecycle_resource_not_disposed` | MEDIUM | performance | P1 | Undisposed `StreamSubscription`, `Timer`, `AnimationController`, `TextEditingController`, `ScrollController`, `FocusNode`, `MqttClient`, `BluetoothDevice`, `StreamController` |
| `layer_violation` | HIGH | architecture | P0 | Importing across forbidden architecture layers |
| `module_violation` | HIGH | architecture | P0 | Importing across forbidden business modules |
| `circular_dependency` | MEDIUM | architecture | P1 | File-level import cycles |
| `missing_const_constructor` | LOW | standards | P2 | Widget classes missing a `const` constructor |

## Output

### Terminal table

Default output is a colored terminal report grouped by domain. It shows the overall score, file count, issue count, and per-issue detail.

### JSON report

`--format json` writes `.flutterguard/report.json` under the output directory. The terminal summary is still printed to stdout.

Example shape:

```json
{
  "version": "1.0.0",
  "generatedAt": "2026-05-20T00:00:00.000Z",
  "projectPath": "/absolute/path",
  "score": 85,
  "summary": {
    "total": 3,
    "high": 1,
    "medium": 1,
    "low": 1,
    "byDomain": {
      "architecture": { "high": 1, "medium": 0, "low": 0, "total": 1 }
    }
  },
  "issues": []
}
```

## Scoring

```text
score = max(0, 100 - high*10 - medium*4 - low*1)
```

| Score | Rating |
|-------|--------|
| 80-100 | 优秀 (Excellent) |
| 50-79 | 需关注 (Needs review) |
| 0-49 | 需整改 (Needs action) |

## CI Integration

```bash
flutterguard scan -p . --format json --fail-on high
flutterguard scan -p . --format json --min-score 80
flutterguard scan -p . --fail-on low
```

## Repository Layout

```text
flutterguard/
├── packages/
│   └── flutterguard_cli/   Active CLI implementation
├── archive/                Frozen legacy runtime-tracing packages
└── examples/
    └── scan_demo/          Demo scan target
```

## Development

```bash
# macOS / Linux
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub global activate melos
melos bootstrap

# Windows
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub global activate melos
melos bootstrap

# Common commands
dart run melos run analyze
dart run melos run test:cli
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
```

## Troubleshooting

### Windows: "API key required" error

This means the shell is resolving an old globally-installed binary instead of this repository's static-analysis CLI. Run the local binary directly:

```powershell
.\flutterguard.exe scan -p D:\path\to\project
```

Or reinstall:

```powershell
dart pub global deactivate flutterguard_cli
dart pub global activate --source path packages\flutterguard_cli
```

### Windows: garbled or invisible terminal colors

Use **Windows Terminal** (built into Windows 10/11) instead of legacy `cmd.exe`. Legacy terminals may show raw ANSI escape codes.

### glob patterns: always use forward slashes

In `flutterguard.yaml`, use `/` for all path patterns regardless of platform:

```yaml
# Correct
path: lib/presentation/**

# Wrong (even on Windows)
path: lib\presentation\**
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
