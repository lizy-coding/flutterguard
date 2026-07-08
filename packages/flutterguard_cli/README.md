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

# Create and validate a starter config
flutterguard init
flutterguard config doctor

# JSON output with CI gate
flutterguard scan -p . --format json --fail-on high --min-score 80

# Baseline existing issues before enforcing CI
flutterguard baseline create .
flutterguard scan . --baseline .flutterguard/baseline.json --fail-on high

# GitHub Code Scanning output
flutterguard scan . --format sarif --baseline .flutterguard/baseline.json
```

## Checks

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
| `device_lifecycle` | HIGH | Unbalanced device init/teardown pairs |
| `mqtt_connection` | HIGH | MQTT connect/disconnect and broker URL checks |
| `iot_security` | HIGH | Hardcoded secrets, cleartext MQTT/HTTP, insecure BLE patterns |
| `ble_scanning` | MEDIUM | BLE scan/stop and timeout checks |
| `pubspec_security` | MEDIUM | Unbounded, deprecated, or outdated dependency checks |

## Configuration

Create `flutterguard.yaml` in your project root:

Start without config, then run `flutterguard init` only when you need custom
thresholds, excludes, CI gates, or explicit architecture boundaries. Use
`flutterguard config print` to inspect merged defaults and
`flutterguard config doctor` before enabling CI gates.

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

If no config file exists, defaults are used (all default rules enabled, no architecture constraints).

## CLI Reference

```
flutterguard scan [<path>] [options]
  -p, --path       Project path (default: .)
  -c, --config     Config file (default: flutterguard.yaml)
  -f, --format     table | json | sarif (default: table)
  -o, --output     Output directory (default: .flutterguard)
  -v, --verbose    Show detailed context
  --changed-only   Only scan changed Dart files
  --base           Git base ref for changed-only mode
  --baseline       Baseline JSON file for existing issues
  --fail-on        CI gate: none | high | medium | low
  --min-score      Minimum score threshold 0-100

flutterguard baseline create [<path>] [--output .flutterguard/baseline.json]
flutterguard init [--with-architecture] [--force]
flutterguard config print
flutterguard config doctor
flutterguard rules [--format table|json]
flutterguard explain <rule-id>
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

Recommended adoption order:

```bash
flutterguard config doctor
flutterguard baseline create .
flutterguard scan . --baseline .flutterguard/baseline.json --format json --fail-on high
```

```yaml
# GitHub Actions
- uses: dart-lang/setup-dart@v1
  with:
    sdk: 3.3.0
- run: dart pub global activate flutterguard_cli
- run: flutterguard scan . --format json --baseline .flutterguard/baseline.json --fail-on high --min-score 80
```

For GitHub Code Scanning:

```yaml
- run: flutterguard scan . --format sarif --baseline .flutterguard/baseline.json
- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: .flutterguard/report.sarif
```

Known false positives can be suppressed on the same line or the next line:

```dart
// flutterguard: ignore missing_const_constructor
// flutterguard: ignore iot_security, mqtt_connection
// flutterguard: ignore all
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
