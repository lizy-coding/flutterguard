# FlutterGuard Configuration Strategy

FlutterGuard should be easy to start and precise when a project needs stricter
architecture gates. The recommended product strategy is: use short CLI responses
for immediate next steps, and keep this dedicated guide for the complete mental
model.

## Decision

Use both surfaces, with different responsibilities:

| Surface | Purpose | Content |
|---------|---------|---------|
| CLI help and scan responses | Immediate action | The next command, likely fix, and the shortest config path |
| Dedicated configuration guide | Full explanation | Configuration levels, architecture examples, CI patterns, and troubleshooting |

Do not put the full manual into CLI output. CLI text should answer "what should
I do next?" in a few lines. The guide should answer "how should this be
configured for my project?"

## Configuration Levels

### Level 0: Zero Config

Best for first scans and demos.

```bash
flutterguard scan
flutterguard scan ./my_flutter_app
```

Behavior:

- Scans `lib/**`
- Excludes generated/freezed/mock files
- Runs all default non-boundary rules
- Does not enforce layers/modules unless they are declared

Use this level when the user wants a quick signal and has not agreed on project
architecture boundaries yet. No YAML file is required.

### Level 1: Basic Project Config

Best for normal local development.

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

Use this level when teams want stable thresholds or custom excludes.

Create it with:

```bash
flutterguard init
flutterguard config doctor
```

### Level 2: CI Gate Config

Best for pull requests and release checks.

```bash
flutterguard scan . --format json --fail-on high --min-score 80
```

Recommended policy:

- Start with `--fail-on high`
- Add `--min-score 80` once the baseline is clean enough
- Avoid `--fail-on low` early in adoption because it can create noisy rollouts
- Run `flutterguard config doctor` before adding CI gates

### Level 3: Architecture Config

Best when the project has agreed boundaries.

Create a starter template with:

```bash
flutterguard init --with-architecture
```

```yaml
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
    - name: mqtt_feature
      path: lib/features/mqtt/**
      allowed_deps: [shared]
    - name: ble_feature
      path: lib/features/ble/**
      allowed_deps: [shared]
    - name: shared
      path: lib/shared/**
      allowed_deps: []

  detect_cycles: true
  layer_violation:
    enabled: true
  module_violation:
    enabled: true
```

Important distinction:

- `architecture.layers[].allowed_deps` must reference layer names.
- `architecture.modules[].allowed_deps` must reference module names.
- Layers describe technical direction such as presentation/domain/data/core.
- Modules describe business or feature isolation such as mqtt/ble/shared.

## CLI Response Policy

CLI responses should stay short and operational:

- `--help`: show common commands, option summary, and the four-level config path
- no files found: mention project path plus include/exclude patterns
- config parse error: show the failing config key and expected value type
- CI gate failure: show the failing threshold and direct the user to JSON output

Avoid long explanations in command output. Point to this guide when the user
needs examples or architecture detail.

## Config Tooling

The core configuration helpers are available as CLI commands:

- `flutterguard init`: write a minimal `flutterguard.yaml`
- `flutterguard init --with-architecture`: write a layered/module template
- `flutterguard config print`: show the merged effective config
- `flutterguard config doctor`: validate globs, unknown deps, empty matches, and
  architecture overlap

These commands are preferable to adding more prose to `scan`, because they keep
scan output focused while still making configuration discoverable.
