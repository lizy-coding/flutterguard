# Package: flutterguard_cli [ACTIVE]

## Role
Primary CLI tool for IoT Flutter static architecture scanning and CI gating.

## Dependency Map
- depends on: flutterguard_core (path), args, analyzer ^7.3.0, glob, path, yaml
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
| `src/static_issue.dart` | StaticIssue model + RiskLevel enum |
| `src/report_generator.dart` | JSON + Markdown report + score calc |
| `src/rules/large_units.dart` | 3 sub-rules: file size, class size, build method |
| `src/rules/lifecycle_resource.dart` | Undisposed controllers/streams detection |
| `src/rules/boundary_import.dart` | Cross-boundary import violation detection |

## Wired Rules (3)
LargeUnitsRule, LifecycleResourceRule, BoundaryImportRule

## Pubspec Overrides
melos-managed: flutterguard_core → path: ../flutterguard_core

## Analysis Options Override
Inherits root strict-casts/strict-inference + package:lints/recommended.yaml. Excludes test/fixtures/**.

## Test
- command: `melos run test:cli`
- test file: `test/scanner_test.dart` (8 tests)
- fixtures: `test/fixtures/` (7 fixture files)
- every new rule needs: spec entry → config typedef → class → fixture → test → wire in bin/

## IoT Domain (planned in spec §15)
Rules defined in spec but not yet implemented: device_lifecycle, mqtt_connection, ble_scanning, iot_security, pubspec_security.
