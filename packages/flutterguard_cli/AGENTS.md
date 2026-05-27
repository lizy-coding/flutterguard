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
| `bin/flutterguard.dart` | Arg parsing, scan orchestration, exit codes |
| `src/config_loader.dart` | YAML → ScanConfig typedef parsing |
| `src/file_collector.dart` | Glob-based .dart file discovery |
| `src/import_utils.dart` | Shared import resolution utility |
| `src/static_issue.dart` | StaticIssue model + RiskLevel enum |
| `src/report_generator.dart` | JSON + Table report generation + score |
| `src/rules/large_units.dart` | 3 sub-rules: file size, class size, build method size |
| `src/rules/lifecycle_resource.dart` | Undisposed controllers/streams/MQTT/BLE detection |
| `src/rules/layer_violation.dart` | Cross-layer import violation detection |
| `src/rules/module_violation.dart` | Cross-module import violation detection |
| `src/rules/circular_dependency.dart` | File-level cycle detection |
| `src/rules/missing_const_constructor.dart` | Widgets missing const constructor |

## Wired Rules (6)
LargeUnitsRule, LifecycleResourceRule, LayerViolationRule, ModuleViolationRule, CircularDependencyRule, MissingConstConstructorRule

## Test
- command: `melos run test:cli`
- test file: `test/scanner_test.dart` (12 tests)
- fixtures: `test/fixtures/` (12 fixture files)
- every new rule needs: spec entry → config typedef → class → fixture → test → wire in bin/

## IoT Domain (planned in spec §12)
Rules defined but not yet implemented: device_lifecycle, mqtt_connection, ble_scanning, iot_security, pubspec_security.

## Current Toolchain Flow
1. `bin/flutterguard.dart` parses CLI arguments and maps validation errors to exit codes.
2. `lib/src/scanner.dart` owns scan orchestration: config loading, file collection, rule execution, issue sorting, and optional JSON writing.
3. `lib/src/config_loader.dart` parses `flutterguard.yaml` into typed record configs.
4. `lib/src/file_collector.dart` resolves include/exclude globs to Dart files.
5. `lib/src/rules/` contains explicit rule classes. Do not add reflection or dynamic plugin loading.
6. `lib/src/report_generator.dart` renders table output and JSON report payloads.

## Change Boundaries
- Put user-facing CLI parsing and exit-code behavior in `bin/`.
- Put reusable scan behavior in `lib/src/scanner.dart`, not in `bin/`.
- Put rule-specific detection in `lib/src/rules/`.
- Put shared path/import/source helpers in `lib/src/*_utils.dart`.
- Add or update tests in `test/scanner_test.dart` for every behavior change.
