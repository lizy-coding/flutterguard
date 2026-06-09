# Changelog

## 0.1.1 (2026-06-09)

### pub.dev Publishing

- **cli:** Published to pub.dev — `dart pub global activate flutterguard_cli`
- **cli:** Added pubspec.yaml metadata (repository, issue_tracker, topics)
- **cli:** Added package-level README, LICENSE, CHANGELOG
- **cli:** Removed Flutter imports from test fixtures for pure Dart compatibility

### Cross-Platform Documentation

- **docs:** `USAGE.md` — comprehensive usage guide (macOS / Windows / Linux)
- **docs:** `WINDOWS_ASSESSMENT.md` — full Windows compatibility audit
- **docs:** Enhanced README.md and README.zh.md with platform-specific install/usage/troubleshooting sections

### Fixes

- **cli:** Fixed pub.dev topic count limit (5 max)
- **cli:** Fixed test fixture Flutter dependency warnings

## 0.1.0 (2026-05-17)

### Initial Release — CLI Static Analysis

- **cli:** 6 static analysis rules: large_file, large_class, large_build_method, lifecycle_resource_not_disposed (IoT-aware), layer_violation, module_violation, circular_dependency, missing_const_constructor
- **cli:** YAML-driven config with include/exclude patterns, rule thresholds, and architecture layers/modules
- **cli:** Table (terminal) and JSON output formats with domain-grouped reporting
- **cli:** CI gate integration with --fail-on threshold and --min-score support
- **cli:** Architecture layer/module enforcement with configurable enabled/disabled
- **cli:** Config key validation (warns on unknown YAML keys)
- **cli:** --version and comprehensive --help output
- **cli:** Native binary compilation (dart compile exe)
- **docs:** FLUTTERGUARD_SPEC.md with full rule contracts, config schema, and output spec
- **docs:** ARCHITECTURE.md, AGENTS.md, PROJECT_RULES.md with dependency graph and override chains
- **meta:** melos monorepo setup with 4 packages + 2 examples
- **meta:** MIT license

### Known Limitations

- IoT-specific rules (device_lifecycle, mqtt_connection, ble_scanning, iot_security, pubspec_security) defined in spec but not yet implemented
- Lifecycle resource detection uses string pattern matching (not type-resolution)
- runtime tracing packages (core/dio/flutter) are frozen — Path A (static analysis) is primary
