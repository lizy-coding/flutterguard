[![pub package](https://img.shields.io/pub/v/flutterguard_cli.svg)](https://pub.dev/packages/flutterguard_cli)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

# flutterguard_cli

IoT Flutter project static analysis CLI for architecture enforcement, code quality, and CI gating.

**Platforms**: macOS / Windows / Linux — pure Dart, zero native dependencies.

## Quick Start

```bash
# Install globally
dart pub global activate flutterguard_cli

# Scan a Flutter project
flutterguard scan -p /path/to/flutter_project

# JSON output with CI gate
flutterguard scan -p . --format json --fail-on high --min-score 80
```

## Checks (8 rule IDs)

| Rule | Level | What it checks |
|------|-------|----------------|
| `large_file` | LOW | File line count |
| `large_class` | LOW | Class body line count |
| `large_build_method` | MEDIUM | `build()` method size |
| `lifecycle_resource_not_disposed` | MEDIUM | Undisposed `StreamSubscription`, `Timer`, `AnimationController`, `TextEditingController`, `ScrollController`, `FocusNode`, `MqttClient` (IoT), `BluetoothDevice` (IoT), `StreamController` |
| `layer_violation` | HIGH | Cross-layer architecture import violations |
| `module_violation` | HIGH | Cross-module architecture import violations |
| `circular_dependency` | MEDIUM | File-level import cycles |
| `missing_const_constructor` | LOW | Widget classes missing `const` constructor |

## Configuration

Create `flutterguard.yaml` in your project root:

```yaml
rules:
  large_file:
    enabled: true
    maxLines: 500
  lifecycle_resource:
    enabled: true

architecture:
  layers:
    - name: presentation
      path: lib/presentation/**
      allowed_deps: [domain, core]
    - name: domain
      path: lib/domain/**
      allowed_deps: [core]
  modules:
    - name: device_mqtt
      path: lib/device/mqtt/**
      allowed_deps: [domain, core]
  detect_cycles: true
```

If no config file exists, defaults are used (all rules enabled, no architecture constraints).

## CLI Reference

```
flutterguard scan [options]
  -p, --path       Project path (default: .)
  -c, --config     Config file (default: flutterguard.yaml)
  -f, --format     table | json (default: table)
  -o, --output     Output directory (default: .flutterguard)
  -v, --verbose    Show detailed context
  --fail-on        CI gate: none | high | medium | low
  --min-score      Minimum score threshold 0-100
```

Exit codes: `0` success, `1` CI gate failed, `2` scan error.

## Scoring

```
score = max(0, 100 - HIGH*10 - MEDIUM*4 - LOW*1)
```

| Score | Rating |
|-------|--------|
| 80-100 | Excellent |
| 50-79 | Needs review |
| 0-49 | Needs action |

## CI Integration

```yaml
# GitHub Actions
- uses: dart-lang/setup-dart@v1
  with:
    sdk: 3.3.0
- run: dart pub global activate flutterguard_cli
- run: flutterguard scan -p . --format json --fail-on high --min-score 80
```

## Requirements

- Dart SDK >=3.3.0
- Supported OS: macOS, Windows, Linux

## Further Reading

- [Full Usage Guide](https://github.com/lizy-coding/flutterguard/blob/develop/docs/USAGE.md)
- [Windows Compatibility](https://github.com/lizy-coding/flutterguard/blob/develop/docs/WINDOWS_ASSESSMENT.md)
- [Specification](https://github.com/lizy-coding/flutterguard/blob/develop/docs/FLUTTERGUARD_SPEC.md)

## License

MIT
