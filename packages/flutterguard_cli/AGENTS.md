# Package: flutterguard_cli [ACTIVE]

## Role
Primary CLI tool for IoT Flutter static architecture scanning and CI gating.

## Dependency Map
- depends on: args, analyzer ^7.3.0, glob, path, yaml
- depended by: nothing

## Entry Points
- bin: `bin/flutterguard.dart` — CLI entry, arg parsing, rule wiring
- lib barrel: `lib/flutterguard_cli.dart`

## Key Source Files
| File | Responsibility |
|------|---------------|
| `bin/flutterguard.dart` | Arg parsing, positional path, scan orchestration, exit codes, `--no-color` |
| `src/config_loader.dart` | YAML → ScanConfig typedef parsing (11 rule configs + architecture) |
| `src/file_collector.dart` | Glob-based .dart file discovery |
| `src/project_resolver.dart` | Project auto-discovery (walk-up flutterguard.yaml / pubspec.yaml / lib/) |
| `src/import_utils.dart` | Shared import resolution utility |
| `src/path_utils.dart` | Cross-platform path/glob helpers (p.Context abstraction) |
| `src/source_utils.dart` | Analyzer offset → line number conversion |
| `src/static_issue.dart` | StaticIssue model + RiskLevel enum |
| `src/report_generator.dart` | JSON + Table report generation + score + --no-color |
| `src/rules/large_units.dart` | 3 sub-rules: file size, class size, build method size |
| `src/rules/lifecycle_resource.dart` | Undisposed controllers/streams/MQTT/BLE detection |
| `src/rules/layer_violation.dart` | Cross-layer import violation detection |
| `src/rules/module_violation.dart` | Cross-module import violation detection |
| `src/rules/circular_dependency.dart` | File-level cycle detection |
| `src/rules/missing_const_constructor.dart` | Widgets missing const constructor |
| `src/rules/iot_security.dart` | Hardcoded secrets, cleartext MQTT/HTTP, insecure BLE |
| `src/rules/device_lifecycle.dart` | Device init/teardown pair checks |
| `src/rules/mqtt_connection.dart` | MQTT connect/disconnect, subscribe/unsubscribe, broker URLs |
| `src/rules/ble_scanning.dart` | BLE startScan/stopScan, connect/disconnect, scan timeout |
| `src/rules/pubspec_security.dart` | Unbounded deps, deprecated packages, outdated IoT dependencies |

## Wired Rules (11 rule classes, 13 rule IDs)
Standards: LargeUnitsRule (3 IDs), MissingConstConstructorRule, PubspecSecurityRule
Performance: LifecycleResourceRule
Architecture: LayerViolationRule, ModuleViolationRule, CircularDependencyRule
IoT: DeviceLifecycleRule, MqttConnectionRule, BleScanningRule, IotSecurityRule

## Test
- command: `melos run test:cli`
- test files: `test/scanner_test.dart` (53 tests) and `test/cli_test.dart` (4 process-level tests)
- fixtures: `test/fixtures/` (16 functional fixture files)
- every new rule needs: spec entry → config typedef → class → fixture → test → wire in scanner.dart

## Current Toolchain Flow
1. `bin/flutterguard.dart` parses CLI arguments (supports positional `<path>`), maps validation errors to exit codes.
2. `lib/src/project_resolver.dart` auto-discovers project root by walking up for flutterguard.yaml / pubspec.yaml / lib/.
3. `lib/src/scanner.dart` owns scan orchestration: config loading, file collection, rule execution, issue sorting, and optional JSON writing.
4. `lib/src/config_loader.dart` parses `flutterguard.yaml` into typed record configs.
5. `lib/src/file_collector.dart` resolves include/exclude globs to Dart files.
6. `lib/src/rules/` contains explicit rule classes. Do not add reflection or dynamic plugin loading.
7. `lib/src/report_generator.dart` renders table output (with optional `--no-color`) and JSON report payloads.

## Change Boundaries
- Put user-facing CLI parsing and exit-code behavior in `bin/`.
- Put reusable scan behavior in `lib/src/scanner.dart`, not in `bin/`.
- Put rule-specific detection in `lib/src/rules/`.
- Put shared path/import/source helpers in `lib/src/*_utils.dart`.
- Put project resolution logic in `lib/src/project_resolver.dart`.
- Add or update tests in `test/scanner_test.dart` for every behavior change.
