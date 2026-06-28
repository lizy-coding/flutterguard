# flutterguard — IoT Flutter Static Analysis CLI

## Identity
IoT/smart home Flutter project static analysis CLI plugin. NOT an observability SDK or APM tool.

## Architecture
- **Monorepo**: melos, 1 package + 1 example
- **Path A (ACTIVE)**: `flutterguard_cli` — all new features
- **Path B (ARCHIVED)**: `flutterguard_core`, `flutterguard_dio`, `flutterguard_flutter` — in `archive/` for future reference

## Package Hierarchy
| Package | Status | Depends On | Depended By |
|---------|--------|------------|-------------|
| flutterguard_cli | ACTIVE | args, analyzer, glob, path, yaml | — |
| scan_demo | — | (none, scan target) | — |

## Key Commands
| Command | Purpose |
|---------|---------|
| `dart run melos bootstrap` | Install workspace dependencies |
| `dart run melos run analyze` | dart analyze on all packages |
| `dart run melos run test:cli` | CLI tests only (37 tests) |
| `flutterguard scan [<path>]` | Run scan on a project (path defaults to current dir) |
| `flutterguard scan <path> --format json --fail-on high` | JSON output with CI gate |
| `flutterguard scan --changed-only` | Incremental scan of git-changed files |
| `flutterguard rules` / `flutterguard explain <id>` | List/describe rules |
| `dart compile exe ... -o flutterguard` | Compile native binary |

## CI & Automation
- `.github/workflows/flutterguard.yml` — CI with ubuntu/macos/windows matrix
- `scripts/compile.sh` / `scripts/compile.ps1` — cross-platform native binary compilation
- `scripts/scan_ci.sh` / `scripts/scan_ci.ps1` — local CI gate scripts

## CLI Entry Point
`packages/flutterguard_cli/bin/flutterguard.dart`

Supports positional path: `flutterguard scan ./my_project` (no `-p` required). Project auto-discovery walks up from CWD to find `flutterguard.yaml`, `pubspec.yaml`, or `lib/`. Supports --changed-only incremental scan and rule introspection (rules/explain).

Wired rules (11 rule classes, 13 rule IDs):
- Standards: LargeUnitsRule (3 IDs), MissingConstConstructorRule, PubspecSecurityRule
- Performance: LifecycleResourceRule
- Architecture: LayerViolationRule, ModuleViolationRule, CircularDependencyRule
- IoT: DeviceLifecycleRule, MqttConnectionRule, BleScanningRule, IotSecurityRule

## Source Layout
```
packages/flutterguard_cli/lib/src/
  config_loader.dart         # YAML → ScanConfig typedefs (11 rule configs + architecture)
  file_collector.dart        # Glob file discovery
  project_resolver.dart      # Project auto-discovery (walk-up flutterguard.yaml / pubspec.yaml / lib/)
  static_issue.dart          # StaticIssue + RiskLevel + IssueDomain + Priority
  report_generator.dart      # Table + JSON output + score, --no-color support
  domain.dart                # IssueDomain enum (architecture/performance/standards)
  priority.dart              # Priority enum (p0/p1/p2)
  path_utils.dart            # Cross-platform path/glob helpers (p.Context abstraction)
  import_utils.dart          # Dart import resolution against collected files
  source_utils.dart          # Analyzer offset → line number conversion
  rule_meta.dart             # Rule metadata for rules/explain
  rules/
    registry.dart                 # RuleRegistry for all 13 rule IDs
    large_units.dart              # large_file, large_class, large_build_method
    lifecycle_resource.dart       # lifecycle_resource_not_disposed
    layer_violation.dart          # layer_violation (architecture layer breaches)
    module_violation.dart         # module_violation (cross-module breaches)
    circular_dependency.dart      # circular_dependency (file-level cycles)
    missing_const_constructor.dart # missing_const_constructor
    iot_security.dart             # iot_security (hardcoded secrets, cleartext MQTT/HTTP, insecure BLE)
    device_lifecycle.dart         # device_lifecycle (init/teardown pair checks)
    mqtt_connection.dart          # mqtt_connection (MQTT connect/disconnect, broker URLs)
    ble_scanning.dart             # ble_scanning (BLE startScan/stopScan, timeout)
    pubspec_security.dart         # pubspec_security (unbounded deps, deprecated packages)
```

## Spec
Single source of truth: `docs/FLUTTERGUARD_SPEC.md` — read before implementing any feature.

## Maintenance Rules
1. New rule: spec entry → config typedef → rule class → fixture → test → wire into scanner.dart
2. Always run `melos run analyze` + `melos run test:cli` before committing
3. Do NOT modify archived packages (core/dio/flutter) — they are frozen references
4. Do NOT add Flutter widgets, web/cloud infra, or SaaS SDKs
5. Output format defaults to `table`. JSON available via `--format=json`
6. Architecture rules require explicit `architecture.layers` / `architecture.modules` in flutterguard.yaml
7. CLI supports positional path (`flutterguard scan ./project`) and `--no-color` flag
