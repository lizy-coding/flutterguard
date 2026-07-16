# FlutterGuard — Specification Document

> **Internal use only. Not git tracked.**
> This document is the single source of truth for agent-driven implementation.

Version: M5 (Milestone 5) — State Maintainability | Last Updated: 2026-07-16

---

## 0. Scope

### 0.1 Identity
FlutterGuard is an **IoT/smart home Flutter project static analysis CLI plugin**. It scans Flutter/Dart source code to detect architecture issues, security vulnerabilities, and anti-patterns specific to IoT device applications.

### 0.2 Active Development
- **Path A (CLI static analysis)**: PRIMARY — actively developed. All new feature work targets `packages/flutterguard_cli/`.
- **Path B (runtime tracing)**: ARCHIVED — superseded by CLI static analysis. The packages `flutterguard_core/`, `flutterguard_dio/`, `flutterguard_flutter/` reside in `archive/` for future reference.

### 0.3 What FlutterGuard IS
- A CLI tool (compiled native binary) for CI-gated static analysis
- An architecture enforcement tool with YAML-driven config
- An IoT-domain-aware rule engine for Flutter projects
- An import dependency and layer compliance checker

### 0.4 What FlutterGuard is NOT
- NOT a runtime observability or APM SDK
- NOT a crash reporter (Sentry/Crashlytics alternative)
- NOT a general-purpose Dart linter (use `dart analyze` / `custom_lint`)
- NOT a web dashboard or data visualization platform
- NOT a network proxy or HTTP inspector
- NOT a Flutter widget library

### 0.5 Analysis Scope
- **Input**: `.dart` source files under `lib/` (configurable via glob patterns)
- **Output**: Table (terminal) / JSON (CI) / SARIF (GitHub Code Scanning) — no Markdown
- **Config**: `flutterguard.yaml` in project root
- **Runtime**: No runtime instrumentation — purely static analysis at compile time

---

## 1. Architecture Overview

```
User runs: flutterguard scan [<path>] [--changed-only] [--base main] [--baseline .flutterguard/baseline.json]
  │
  ├── 1. ArgParser parses CLI flags
  ├── 2. ScanConfig.fromFile() loads YAML config
  ├── 3. FileCollector.collect() globs .dart files
  │       └── if --changed-only: FileCollector.getChangedFiles() filters by git diff
  ├── 4. Scan: 21 rule classes analyze source/project state (23 rule IDs)
  │       ├── LargeUnitsRule              (file size, class size, build method size)
  │       ├── LifecycleResourceRule       (undisposed controllers/streams)
  │       ├── LayerViolationRule          (cross-layer import violations)
  │       ├── ModuleViolationRule         (cross-module import violations)
  │       ├── CircularDependencyRule      (file-level cycle detection)
  │       ├── MissingConstConstructorRule (widgets missing const constructor)
  │       ├── DeviceLifecycleRule         (init/teardown pairing)
  │       ├── MqttConnectionRule          (MQTT connect/disconnect, hardcoded URLs)
  │       ├── BleScanningRule             (BLE scan lifecycle, timeout)
  │       ├── IotSecurityRule             (hardcoded secrets, cleartext, insecure BLE)
  │       ├── PubspecSecurityRule         (unbounded deps, deprecated packages)
  │       ├── 5 generic state rules       (build, mutability, UI boundary, cycle)
  │       ├── 2 Riverpod rules            (read/render, watch/callback)
  │       ├── 1 Bloc rule                 (Equatable props completeness)
  │       └── 2 Provider rules            (ownership, loop notifications)
  │       └── (changed-only: import cycle skipped; state cycle uses full graph)
  ├── 5. Issues sorted by risk level (high → medium → low)
  ├── 6. Suppression comments and optional baseline filter visible issues
  ├── 7. ReportGenerator generates output
  │       ├── Table → terminal stdout
  │       └── JSON → .flutterguard/report.json
  │       └── SARIF → .flutterguard/report.sarif
  └── 8. CI gate check (exit 1 if fail threshold exceeded)
```

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| `package:analyzer` for AST | Resolves type information for resource detection |
| `package:glob` for file matching | Consistent glob support for include/exclude and architecture paths |
| Shared scan data | `ScanContext` carries project/all/target files; `SourceWorkspace` caches source text, AST, line info, and diagnostics |
| Rule class compatibility | Direct rule calls retain `analyze(List<String> files, {SourceWorkspace? workspace})`; scanner execution is wired by `RuleCatalog` |
| Shared architecture kernel | Layer/module/cycle rules consume one `ImportGraph`; layer/module checks share `DependencyBoundaryEngine` |
| No plugin system | Rules are explicitly wired in `RuleCatalog` — no reflection, no codegen |

---

## 2. Package Map & Dependencies

```
flutterguard/
├── packages/
│   └── flutterguard_cli/           Dart CLI (ACTIVE)
│       └── depends: args, analyzer ^7.3.0, glob, path, yaml
├── archive/                        Reserved — runtime tracing (v0.1.0)
│   ├── flutterguard_core/
│   ├── flutterguard_dio/
│   └── flutterguard_flutter/
└── examples/
    └── scan_demo/                  Scan target demo
```

**Compile target**: `dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard` → native binary

---

## 3. Data Models

### 3.1 StaticIssue (CLI)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| id | String | yes | Rule ID e.g. `layer_violation` |
| title | String | yes | Human title |
| file | String | yes | Absolute path |
| line | int? | no | Line number |
| level | RiskLevel | yes | low / medium / high |
| domain | IssueDomain | yes | architecture / performance / standards |
| priority | Priority | yes | p0 / p1 / p2 |
| message | String | yes | Short explanation |
| detail | String | no | Long description with context |
| suggestion | String | yes | Fix recommendation |
| metadata | Map<String,Object?> | yes | Rule-specific data |
| framework | StateManagementFramework | yes | generic / riverpod / bloc / provider |
| confidence | RuleConfidence | yes | certain / probable / informational |
| evidence | List<String> | yes | At most five compact AST evidence entries |

### 3.2 RiskLevel Enum

```dart
enum RiskLevel { low, medium, high }
```

### 3.3 IssueDomain Enum

```dart
enum IssueDomain { architecture, performance, standards }
```

### 3.4 Priority Enum

```dart
enum Priority { p0, p1, p2 }
```

### 3.5 State-management enums

```dart
enum StateManagementFramework { riverpod, bloc, provider, generic }
enum RuleConfidence { certain, probable, informational }
```

---

## 4. CLI Contract

### Command

```
flutterguard scan [options]
  --path (-p)     Project path to scan (default: .)
  --config (-c)   Config file path (default: flutterguard.yaml)
  --format (-f)   Output format: table | json | sarif (default: table)
  --output (-o)   Output directory (default: .flutterguard)
  --verbose (-v)  Show detailed output with code context
  --fail-on       CI gate: none | high | medium | low (default: none)
  --min-score     Minimum score threshold 0-100
  --changed-only   Only scan .dart files changed since --base (default: false)
  --base           Git base ref for changed-only (default: main)
  --baseline       Baseline JSON file used to hide existing issues

flutterguard baseline create [<path>]
  --output (-o)   Baseline output path (default: .flutterguard/baseline.json)

flutterguard rules [options]
  --format (-f)   Output format: table | json (default: table)

flutterguard explain <rule-id>
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success, including a valid changed-only scan with no relevant changes |
| 1 | CI gate failed (issues at/below `--fail-on` level or score < `--min-score`) |
| 2 | Scan/explain setup error (bad path, missing explicit config, invalid config, zero configured Dart files, unknown rule ID) |

### File Collection

- Use `glob` package to match `include` patterns
- Remove matching files for `exclude` patterns
- Only `.dart` files
- Default include: `lib/**`
- Default exclude: `lib/generated/**`, `lib/**.g.dart`, `lib/**.freezed.dart`, `lib/**.mocks.dart`

---

## 5. Config Schema (flutterguard.yaml)

```yaml
include:
  - lib/**           # Glob patterns for files to scan

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
  side_effect_in_build:
    enabled: true
    severity: high
    allowlist: []
    ignore_paths: []
  # The other nine state rules use the same four keys.

state_management:
  enabled: true
  framework_auto_detect: true
  confidence_threshold: certain

architecture:                      # Architecture layer/module rules
  layers:                          # Layered architecture enforcement
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

  modules:                         # Business module isolation
    - name: device_mqtt
      path: lib/device/mqtt/**
      allowed_deps: [domain, core]
    - name: device_ble
      path: lib/device/ble/**
      allowed_deps: [domain, core]

  detect_cycles: true              # Circular dependency detection
```

State-rule `severity` accepts `high`, `medium`, or `low` and maps to P0, P1,
or P2 respectively. `ignore_paths` values are project-relative POSIX globs.
`allowlist` values are exact rule-specific symbols; dependency-cycle edges use
`Source->Target`. Unknown enum values, invalid severity values, and wrong value
types are configuration errors. Missing state configuration uses the defaults
above and remains compatible with older YAML files.

---

## 6. Export Format Spec

### 6.1 JSON Report Schema

```json
{
  "version": "1.0.0",
  "generatedAt": "ISO8601",
  "scanMode": "full|changed",
  "projectPath": "/absolute/path",
  "score": 85,
  "summary": {
    "total": 4,
    "high": 1,
    "medium": 2,
        "low": 1,
        "suppressed": 0,
        "suppressedByBaseline": 0,
        "diagnostics": 0,
    "byDomain": {
      "architecture": { "high": 1, "medium": 1, "low": 0, "total": 2 },
      "performance": { "high": 0, "medium": 1, "low": 0, "total": 1 },
      "standards":   { "high": 0, "medium": 0, "low": 1, "total": 1 }
    }
  },
  "issues": [
    {
      "id": "layer_violation",
      "ruleId": "layer_violation",
      "title": "层间依赖违规",
      "file": "/absolute/path/to/file.dart",
      "line": 42,
      "level": "high",
      "severity": "high",
      "domain": "architecture",
      "priority": "p0",
      "message": "Short description",
      "detail": "Long description with import path and layer info",
      "suggestion": "Fix recommendation",
      "metadata": { "sourceLayer": "service", "targetLayer": "widget" },
      "framework": "generic",
      "confidence": "certain",
      "evidence": []
    }
  ],
  "diagnostics": []
}
```

### 6.2 Score Calculation

```
score = max(0, 100 - high*10 - medium*4 - low*1)
```

### 6.3 Table Output (Terminal)

Default output format. Example:

```

### 6.4 SARIF Output

`--format sarif` writes `.flutterguard/report.sarif` and prints a short stdout summary.

- SARIF version: `2.1.0`
- Rule metadata source: `RuleRegistry`
- Result severity mapping: high → `error`, medium → `warning`, low → `note`
- Location URI: project-relative path when possible
- Location line: `StaticIssue.line`, or line `1` when absent

### 6.5 Suppression Comments

Supported source comments:

```dart
// flutterguard: ignore <rule_id>
// flutterguard: ignore <rule_id>, <rule_id>
// flutterguard: ignore all
```

Suppression applies only to issues on the comment line and the immediately following line. It does not support file-wide disable blocks or cross-file suppression. Suppressed issues are hidden from normal outputs and CI gates. JSON summary includes `suppressed`.

### 6.6 Baseline

```bash
flutterguard baseline create . --output .flutterguard/baseline.json
flutterguard scan . --baseline .flutterguard/baseline.json
```

Baseline files contain a sorted list of issue fingerprints. The fingerprint input is:

```
id + relative file path + line + message
```

Baseline-matched issues are hidden from stdout/JSON/SARIF and do not affect `--fail-on` or `--min-score`. Missing or invalid baseline files are scan errors with exit code 2 through the CLI. JSON summary includes `suppressedByBaseline`.
 FlutterGuard Report  ─  scan_demo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 总评分:  88/100  优秀           文件总数: 2  问题总数: 3
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 架构违规  1 items  HIGH
 ────────────────────────────────────────────────────────────────
  HIGH  P0 优先
       层间依赖违规
       lib/services/user_service.dart:7
       service 层不可依赖 widget 层
       修复: 将导入的内容移至 core 或更抽象层
```

---

## 7. Static Rules Detail

### 7.1 large_file (RiskLevel: low, Domain: standards, Priority: p2)

**Detection**: Count lines of file. If > maxLines (default 500), issue.

**Implementation**: Simple file line count via `File.readAsLinesSync()`.

### 7.2 large_class (RiskLevel: low, Domain: standards, Priority: p2)

**Detection**: Find `class ClassName {` via analyzer AST. Calculate lines from class declaration to matching `}`. If > maxLines (default 300), issue.

**Implementation**: Parse with `package:analyzer`, find `ClassDeclaration`, calculate line span.

### 7.3 large_build_method (RiskLevel: medium, Domain: performance, Priority: p1)

**Detection**: Find `Widget build(BuildContext ...)` method in any `ClassDeclaration`. Calculate line span. If > maxLines (default 80), issue.

**Implementation**: Parse with `package:analyzer`, visit class members, match `MethodDeclaration` with name `build` and return type `Widget`.

### 7.4 lifecycle_resource_not_disposed (RiskLevel: medium, Domain: performance, Priority: p1)

**Detection**:
1. For each class, find non-static field declarations
2. Check if type matches: `StreamSubscription`, `Timer`, `AnimationController`, `TextEditingController`, `ScrollController`, `FocusNode`
3. Check type either as exact match or containing generic (`<Type>`)
4. Find `dispose()` method in the class
5. In dispose method body, check if `${fieldName}.${expectedCall}()` exists
6. If not found, report issue

**Resource → expected call**:
- StreamSubscription → cancel
- Timer → cancel
- AnimationController → dispose
- TextEditingController → dispose
- ScrollController → dispose
- FocusNode → dispose
- MqttClient → disconnect
- BluetoothDevice → disconnect
- StreamController → close

**Implementation**: Parse with `package:analyzer`, visit `FieldDeclaration`, `MethodDeclaration`. Check dispose body via string contains.

### 7.5 layer_violation (RiskLevel: high, Domain: architecture, Priority: p0)

**Detection**: For each file, determine which architecture layer it belongs to by matching its path against `architecture.layers[].path` glob patterns. For each `import` directive, resolve the imported file and determine its layer. If the target layer is not in the source layer's `allowed_deps` list, report a violation.

**Implementation**: Parse with `package:analyzer`, visit `ImportDirective`. Resolve imports via path normalization (supports relative and package: imports). Match layers via `Glob` from `package:glob`.

### 7.6 module_violation (RiskLevel: high, Domain: architecture, Priority: p0)

**Detection**: Same mechanism as `layer_violation` but operates on `architecture.modules`. Checks import relationships between named business modules.

**Implementation**: Same as 7.5 but uses `ModuleConfig` instead of `LayerConfig`.

### 7.7 circular_dependency (RiskLevel: medium, Domain: architecture, Priority: p1)

**Detection**: Build a directed import graph for all scanned files. Use DFS with white/gray/black coloring to detect cycles. Report each unique cycle found.

**Limitations**:
- Detects file-level cycles only (not class-level)
- Only resolves imports within the scanned file set
- May report the same logical cycle from different entry points

### 7.8 missing_const_constructor (RiskLevel: low, Domain: standards, Priority: p2)

**Detection**:
1. Find all `StatelessWidget` and `StatefulWidget` subclass declarations
2. Check if the class has a `const` constructor
3. If no `const` constructor is found and the class is a widget, report issue
4. Also checks plain classes where all fields are final and could be const

### 7.9 device_lifecycle (RiskLevel: high, Domain: architecture, Priority: p0)

**Detection**: For each class, check that device lifecycle methods have balanced init/teardown pairs:
- `initState` ↔ `dispose`
- `connect()` ↔ `disconnect()`
- `start()` ↔ `stop()`
- `listen()` / `subscribe()` ↔ `cancel()` / `unsubscribe()`

**Implementation**: Parse with `package:analyzer`, check method name presence for balanced pairs.

### 7.10 mqtt_connection (RiskLevel: high, Domain: architecture, Priority: p0)

**Detection**:
1. Find MQTT client field declarations (types matching `*MqttClient`, `*MQTT*`)
2. Check for `connect()` calls — verify `disconnect()` exists in dispose-like methods
3. Check for `subscribe()` calls — verify corresponding `unsubscribe()` calls exist
4. Check for hardcoded broker URLs (string literals containing `tcp://` or `mqtt://`)

### 7.11 ble_scanning (RiskLevel: medium, Domain: architecture, Priority: p1)

**Detection**:
1. Find BLE-related field declarations (types matching `*Ble*`, `*Bluetooth*`)
2. Check for `startScan()` calls — verify `stopScan()` exists in dispose-like methods
3. Check for `connect()` calls to BLE devices — verify `disconnect()` exists
4. Check that scan timeout is configured (look for timeout parameter in `startScan()`)

**Config**: `maxScanDurationMs: int (default: 10000)`

### 7.12 iot_security (RiskLevel: high, Domain: architecture, Priority: p0)

**Detection**:
| Check | Pattern | Severity |
|-------|---------|----------|
| Hardcoded password/token | String literal matching `password`/`token`/`secret` assignment | high |
| Cleartext MQTT | `tcp://` host or port `1883` in MQTT config | high |
| Cleartext HTTP | `http://` in IoT context packages | medium |
| Insecure BLE | BLE without `bond`/`pair` references | medium |

**Config**: `requireTls: bool (default: true)`

### 7.13 pubspec_security (RiskLevel: medium, Domain: standards, Priority: p2)

**Detection**: Analyzes the project's `pubspec.yaml` rather than individual `.dart` files.
| Check | Pattern | Severity |
|-------|---------|----------|
| Unbounded dependency | `^any` or no version constraint | medium |
| Outdated mqtt_client | `mqtt_client` version < 10.x.x | high |
| Outdated flutter_blue | `flutter_blue` (deprecated, use `flutter_blue_plus`) | high |
| Outdated http | `http` package < 1.x.x with cleartext patterns | medium |

### 7.14-7.23 State-management maintainability rules

All rules are AST-first, default enabled, and currently emit `certain`
findings. Common gating is global/per-rule enablement, confidence threshold,
framework import auto-detection, project-relative `ignore_paths`, then AST
detection. Existing source suppression and baseline filtering run afterward.

| ID | Default | Framework | Detection contract |
|----|---------|-----------|--------------------|
| `side_effect_in_build` | high/P0 | generic | One issue per Widget/State/Consumer build root for direct state/resource effects; nested callbacks and local collection `add` are excluded. |
| `state_manager_created_in_build` | high/P0 | generic | One issue per Controller/Bloc/Cubit/Notifier/Flutter-controller construction in build; nested event and ownership callbacks are excluded. |
| `mutable_state_exposed` | medium/P1 | generic | Public non-final fields, mutable collection references/getters, and in-place `state` collection mutation in business state owners; Flutter `State<T>` and unmodifiable values are excluded. |
| `state_layer_ui_dependency` | high/P0 | generic | One issue per state owner using BuildContext/Widget or navigation/dialog/messenger/media/theme APIs. Nested generic types without runtime use are ignored. |
| `state_dependency_cycle` | high/P0 | generic | Provider/state/service graph, Tarjan SCC, one deterministic shortest cycle per SCC containing a state node. Changed mode uses all files and reports only cycles touching a changed file. |
| `riverpod_read_used_for_render` | medium/P1 | riverpod | Local flow from `ref.read(provider)` into returned Widget construction or conditional/collection rendering; commands and callbacks are excluded. |
| `riverpod_watch_in_callback` | medium/P1 | riverpod | One issue per event/listener/timer/async callback containing `ref.watch`; build and provider declaration bodies are excluded. |
| `bloc_equatable_props_incomplete` | medium/P1 | bloc | One merged issue per Equatable class whose final instance fields are absent from `props`. |
| `provider_value_lifecycle_misuse` | medium/P1 | provider | `.value(value: new Instance())` and `create: (_) => existingInstance`; const/immutable/allowlisted values are excluded. BlocProvider is accepted. |
| `notify_listeners_in_loop` | medium/P1 | provider | One issue per for/for-in/while/do/forEach root containing `notifyListeners`; literal 0/1 iteration is excluded. |

Framework auto-detection recognizes Riverpod, Bloc, Equatable, Provider and
Flutter Bloc imports. With `framework_auto_detect: false`, import gates are
skipped but AST shapes remain mandatory. Evidence is deduplicated and capped at
five entries.

---

## 8. Test Contracts

### 8.1 CLI Tests (83 tests)

| Test | Fixture | Then |
|------|---------|------|
| scan_detects_large_file | large_file.dart (501 lines) | 1 issue, id=large_file |
| scan_detects_large_class | large_class.dart (class 303 lines) | 1 issue, id=large_class |
| scan_detects_large_build_method | large_build.dart (build method 81+ lines) | 1 issue, id=large_build_method |
| scan_detects_lifecycle_resource | lifecycle_issue.dart | 2+ issues, id=lifecycle_resource_not_disposed |
| scan_detects_layer_violation | boundary_issue.dart + architecture_config.yaml | 1+ issues, id=layer_violation |
| scan_detects_module_violation | boundary_issue.dart + architecture_config.yaml | 1+ issues, id=module_violation |
| scan_detects_circular_dependency | cycle_a.dart, cycle_b.dart, cycle_c.dart | 1+ issues, id=circular_dependency |
| scan_detects_missing_const_constructor | missing_const.dart | 1+ issues, id=missing_const_constructor |
| config_parses_enabled_flags | architecture_config.yaml + architecture_disabled.yaml | enabled/true, disabled/false |
| wiring_disabled_layer_module | architecture_disabled.yaml + boundary fixtures | 0 issues |
| ci_fail_on_high | array with high issue | shouldFail(issues, 'high') == true |
| json_report_generated | issues array | output contains expected fields |
| scan_detects_lifecycle_iot_resource | lifecycle_issue.dart (with MqttClient) | matches IoT types |
| changed_only_filters_files | temp git repo, 2 files, change 1 | scanMode=changed, only changed-file issues |
| changed_only_full_scan_when_no_git | non-git dir with changedOnly | scanMode=full |
| changed_only_skips_circular_dependency | cycle fixture with changedOnly | 0 circular_dependency issues |
| registry_contains_all_23_rules | RuleRegistry.all() | length == 23 |
| registry_find_returns_correct_meta | find('large_file') | non-null, correct id/domain |
| registry_find_unknown_returns_null | find('nonexistent') | null |

### 8.2 Fixture Files

Located at `packages/flutterguard_cli/test/fixtures/`:

| File | Description |
|------|-------------|
| large_file.dart | 501 generated comment lines |
| large_class.dart | Class with 303 lines (2 line wrapper + 301 filler) |
| large_build.dart | Widget build method with 81+ lines |
| lifecycle_issue.dart | StreamSubscription + Timer fields, empty dispose() |
| boundary_issue.dart | Imports forbidden_file.dart (reused for layer/module tests) |
| forbidden_file.dart | Target of layer/module violation |
| cycle_a.dart | Circular dependency start (imports cycle_b) |
| cycle_b.dart | Circular dependency middle (imports cycle_c) |
| cycle_c.dart | Circular dependency end (imports cycle_a) |
| architecture_config.yaml | Config with layer + module declarations |
| architecture_disabled.yaml | Config with layer/module violations disabled |
| missing_const.dart | Widget subclass without const constructor |

---

## 9. Evolution Roadmap

### M1 (Completed) — Static Scan MVP

Key deliverables:
- CLI static scan with 4 rules (large_file, large_class, large_build_method, lifecycle_resource_not_disposed)
- JSON + Table report generation with CI gate
- Runtime tracing packages archived to `archive/`

### M2 (Current) — Architecture Detection + Output Reform

- Architecture layer/module enforcement (layer_violation, module_violation)
- Circular dependency detection (circular_dependency)
- `table` output format with domain grouping (architecture / performance / standards)
- Priority system (P0/P1/P2) per issue
- Cleaned up CLI params (removed markdown, group-by, top, no-module-score)
- SPEC rewrite: removed all runtime tracing documentation

### M3 (Completed v0.3.0) — Incremental Scan + Rule Introspection + IoT Rules

Key deliverables:
- `--changed-only` incremental scan via git diff (skips cyclic dep in changed mode)
- `flutterguard rules` / `flutterguard explain` subcommands with RuleMeta registry
- `device_lifecycle`, `mqtt_connection`, `ble_scanning`, `iot_security`, `pubspec_security`
- 57 tests across reusable scanner/rule coverage and process-level CLI behavior
- RuleMeta class + RuleRegistry for rule introspection

### M4 — CI Adoption

- Single-line / next-line suppression comments for false positive control
- Baseline creation and `scan --baseline` filtering for legacy projects
- SARIF output format for GitHub Code Scanning
- GitHub Actions CI examples for JSON gates and SARIF upload
- Rule accuracy regression tests around suppression, baseline, SARIF, and IoT rules

### M5 — Enterprise + DX

- GitHub Actions annotations mode
- Team configuration sharing
- Pre-commit hook integration
- IDE plugin (VS Code / IntelliJ) for inline results

---

## 10. Known Limitations (M4 Current)

1. **Lifecycle resource detection**: Uses string contains in dispose body, not full AST visitor. Does not detect:
   - Disposal via helper method calls
   - Disposal via `disposeAll()` style patterns
   - Resources created via factory methods
2. **Import resolution**: Package imports are resolved by stripping the package: prefix and matching against the scanned file set. Imports from external packages are not resolved.
3. **Cyclic detection**: Reports cycles at file granularity, not class/module granularity. Same logical cycle may be reported from different DFS entry points.
4. **Architecture rules**: Layer/module rules require the user to explicitly declare all layers/modules in flutterguard.yaml. No auto-detection.
5. **Multi-isolate**: Not supported (single-isolate only)
6. **State graph resolution**: State dependency edges are syntactic and project-local; runtime service locators and generated provider code are not resolved.
7. **Incremental scan**: `--changed-only` skips circular_dependency entirely
   in changed mode. Layer/module violations are detected only when the changed
   file is the source of the illegal import; unchanged target files remain
   available for import resolution. Project-level pubspec security is checked
   in full scans and when `pubspec.yaml` changes in incremental scans.
   `state_dependency_cycle` is the exception: it always builds the full graph
   and reports only cycles that touch a changed source file.
8. **Suppression**: Only current-line and next-line comments are supported.
   There is no file-wide disable/enable block.
9. **Baseline**: Fingerprints intentionally include line and message, so moving
   code or changing rule wording can surface old issues again.

---

## 11. Commands Reference

```bash
# Bootstrap (development)
cd flutterguard
dart pub get
melos bootstrap

# Analyze
dart run melos run analyze

# Test
dart run melos run test:cli

# Compile CLI
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard

# Scan a project
./flutterguard scan --path /path/to/flutter_project

# Run IoT scan demo
./flutterguard scan --path examples/scan_demo

# Create a baseline and scan only new issues
./flutterguard baseline create . --output .flutterguard/baseline.json
./flutterguard scan . --baseline .flutterguard/baseline.json

# Generate SARIF for GitHub Code Scanning
./flutterguard scan . --format sarif --baseline .flutterguard/baseline.json
```

---

## 13. Rule Registry & Explain Commands

### 13.1 RuleMeta
Data class in `lib/src/rule_meta.dart`:
- `id` — rule identifier
- `name` — Chinese display name
- `domain` — architecture / performance / standards
- `riskLevel` — high / medium / low
- `priority` — p0 / p1 / p2
- `purpose` — detection purpose
- `riskReason` — why this matters
- `badExample` — anti-pattern
- `fixSuggestion` — recommended fix
- `configKeys` — YAML config keys
- `cicdSafe` — whether suitable for CI gating
- `framework` — generic / riverpod / bloc / provider
- `confidence` — certain / probable / informational

### 13.2 RuleRegistry
Singleton in `lib/src/rules/registry.dart`:
- `all()` → `List<RuleMeta>` (23 entries)
- `find(String id)` → `RuleMeta?`

### 13.3 CLI Commands
- `flutterguard rules` — table of all rules
- `flutterguard rules --format json` — JSON payload
- `flutterguard explain <rule-id>` — full detail; exit 2 on unknown ID

---

## 14. Incremental Scan (--changed-only)

### Flow
1. Resolve the containing repository with `git rev-parse --show-toplevel`
2. Verify `<base>^{commit}` and reject option-like or invalid refs
3. `git diff --name-only --diff-filter=ACMR -z <verified-commit> --`
4. `git ls-files --others --exclude-standard -z` (untracked files)
5. Union both NUL-delimited sets, anchor paths to the target project, and filter to `.dart` files
6. Feed filtered files to all rules
7. CircularDependencyRule is disabled only for a valid changed-mode scan

### Behavior Matrix
| Condition | Behavior | scanMode |
|-----------|----------|----------|
| Non-git dir | Fallback to full scan | full |
| --changed-only, 0 changes | Empty successful report | changed |
| --changed-only, changes > 0 | Only scan changed .dart files | changed |
| Invalid `--base` | Scan setup error (exit 2) | — |
| --base not specified | Defaults to 'main' | — |
