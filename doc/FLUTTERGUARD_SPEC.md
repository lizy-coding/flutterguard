# FlutterGuard External Contract

Version: 0.7 / JSON schema 2.0.0

This document defines supported user-facing behavior. Internal classes and file
layout are documented in `ARCHITECTURE.md` and are not compatibility contracts.

## Identity and scope

FlutterGuard is a local static analysis CLI for IoT and smart-home Flutter
projects. It detects architecture boundary violations, lifecycle/resource
risks, IoT transport/security problems, and state-management maintainability
problems.

It is not a runtime SDK, observability agent, crash reporter, hosted service,
network proxy, widget library, or general formatting/style linter.

## Commands

```text
flutterguard scan [path] [options]
flutterguard baseline create [path] [options]
flutterguard config init [path] [options]
flutterguard config check [path] [options]
flutterguard rules [rule-id] [--format table|json]
```

Global options are `--help` and `--version`.

### Scan options

| Option | Contract |
|---|---|
| `--config`, `-c` | Explicit config; missing explicit files are errors |
| `--format`, `-f` | `table`, `json`, or `sarif`; default `table` |
| `--output`, `-o` | Report directory; default `.flutterguard` |
| `--verbose`, `-v` | Print diagnostics, detail, and evidence |
| `--no-color` | Disable ANSI colors |
| `--fail-on` | `none`, `high`, `medium`, or `low` |
| `--changed-only` | Restrict source rules to Git-changed Dart files |
| `--base` | Verified Git base ref; default `main` |
| `--baseline` | Hide findings present in a baseline file |

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Command succeeded and the severity gate passed |
| `1` | Severity gate or config check failed |
| `2` | Invalid arguments, project, config, baseline, or Git base |

## Project and files

Project discovery walks upward from the requested path and recognizes
`flutterguard.yaml`, `pubspec.yaml`, or `lib/`. Default source selection is:

```yaml
include: [lib/**]
exclude:
  - lib/generated/**
  - lib/**.g.dart
  - lib/**.freezed.dart
  - lib/**.mocks.dart
```

An ordinary full scan with zero matched Dart files is an error. A valid
changed-only scan with zero changed Dart files succeeds and writes an empty
requested report.

## Configuration

Top-level keys are `include`, `exclude`, `rules`, and `architecture`.

```yaml
rules:
  <rule-id>:
    enabled: true
    severity: high
    <rule-specific-option>: <scalar>

architecture:
  detect_cycles: false
  layers: []
  modules: []
```

Rule severity is `low`, `medium`, or `high`. Unknown rule IDs and unknown
rule-specific options are errors in `config check`. Run `config init` to
generate current definitions and defaults.

A boundary entry is:

```yaml
- name: presentation
  path: lib/presentation/**
  allowed_deps: [domain, core]
```

Layer and module enforcement is inactive when its boundary list is empty.
Circular import detection requires `architecture.detect_cycles: true` and is
skipped in changed-only mode.

## Rule inventory

The registry contains 16 IDs:

```text
ble_scanning
bloc_equatable_props_incomplete
circular_dependency
iot_security
layer_violation
lifecycle_resource_not_disposed
module_violation
mutable_state_exposed
notify_listeners_in_loop
provider_value_lifecycle_misuse
riverpod_read_used_for_render
riverpod_watch_in_callback
side_effect_in_build
state_dependency_cycle
state_layer_ui_dependency
state_manager_created_in_build
```

`rules [rule-id]` is the authoritative description of purpose, default
severity, framework, options, example, and remediation.

## Findings

The internal finding model exposes one canonical JSON representation:

```json
{
  "ruleId": "iot_security",
  "title": "IoT 安全风险",
  "file": "/project/lib/device.dart",
  "line": 10,
  "severity": "high",
  "domain": "architecture",
  "message": "...",
  "detail": "...",
  "suggestion": "...",
  "metadata": {},
  "framework": "generic",
  "evidence": []
}
```

There are no duplicate `id`/`ruleId` or `level`/`severity` fields, and no
priority, score, or confidence fields.

## JSON report

JSON reports use schema version `2.0.0`:

```json
{
  "schemaVersion": "2.0.0",
  "projectPath": "/project",
  "scanMode": "full",
  "summary": {
    "total": 1,
    "high": 1,
    "medium": 0,
    "low": 0,
    "suppressed": 0,
    "suppressedByBaseline": 0,
    "diagnostics": 0,
    "byDomain": {}
  },
  "issues": [],
  "diagnostics": []
}
```

SARIF reports conform to SARIF 2.1.0 and include registry definitions and
finding locations.

## Suppression and baseline

Supported comments are same-line and immediately preceding-line forms:

```dart
// flutterguard: ignore iot_security
final endpoint = localEndpoint;
```

Multiple IDs may be comma-separated; `ignore all` suppresses all findings at
the target line.

`baseline create` stores stable fingerprints derived from rule ID, normalized
path, line, and message. A scan with `--baseline` hides matching findings after
inline suppression.

## Changed-only behavior

Changed-only mode verifies `<base>^{commit}`, collects tracked changes and
untracked files, and filters them to configured Dart sources. Unchanged project
files remain available for import and state-graph resolution. Project-level
pubspec checks run only when `pubspec.yaml` changed. State dependency cycles
use the full graph and report cycles touching a changed source.

## Release gates

A release is valid only when all of the following pass from the repository
root:

```bash
dart pub get
dart analyze
dart test
dart run bin/flutterguard.dart scan example --format json --no-color
dart pub publish --dry-run
```

Native release artifacts are produced by `scripts/package_release.sh` and
`scripts/package_release.ps1` on their respective operating systems.
