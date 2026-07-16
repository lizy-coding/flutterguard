# Changelog

## 0.6.0 (2026-07-16)

- **cli:** Added 10 AST-first state-management maintainability rules for generic Flutter, Riverpod, Bloc, and Provider projects (23 total rule IDs).
- **cli:** Added state-rule severity/allowlist/ignore-path controls, framework auto-detection, confidence/evidence output, and changed-only state-cycle analysis.
- **reporting:** JSON and SARIF now include framework, confidence, and evidence while preserving existing fields and baseline fingerprints.
- **fix:** Qualified state dependency graph nodes by file and resolved duplicate names through project imports.
- **compatibility:** Aligned the published package SDK constraint and install examples with the Dart 3.11.5 release workflow.
- **test:** Expanded the CLI suite to 83 tests with generic/Riverpod/Bloc/Provider fixtures, version synchronization, and release-hardening coverage.
- **fix:** Prevent successful no-op full scans and preserve setup-error exit codes in local CI scripts.
- **fix:** Anchor configuration policy to the target project and require explicitly selected config files.
- **ci:** Run analyze, tests, and the demo scan against the current checkout on the OS matrix.

## 0.4.1 (2026-07-09)

### Adoption Hardening

- **cli:** Added `flutterguard doctor install` to diagnose executable version, Dart entrypoint, and PATH conflicts.
- **cli:** Added `flutterguard issue export` to create a local JSON feedback bundle for one finding without uploading source code.
- **cli:** Added baseline management commands: `baseline stats`, `baseline prune`, and `baseline check --no-growth`.
- **cli:** Added `flutterguard init --profile` with recommended, strict, migration, IoT security, architecture-only, and performance-only starter profiles.
- **cli:** `flutterguard init [<path>]` now supports a positional project path.
- **test:** Expanded CLI coverage for install diagnostics, issue export, baseline management, and config profiles.

## 0.4.0 (2026-07-08)

### CI Adoption

- **cli:** Added baseline creation with `flutterguard baseline create [<path>]`.
- **cli:** Added `scan --baseline <file>` so legacy issues can be filtered from reports, score, and CI gates.
- **cli:** Added single-line / next-line suppression comments for false positive control.
- **cli:** Added SARIF 2.1.0 output via `--format sarif` for GitHub Code Scanning upload.
- **cli:** JSON summary now includes suppression and baseline suppression counters.
- **docs:** Updated English, Chinese, and package README files with baseline, SARIF, `rules`, `explain`, and `--changed-only` usage.
- **release:** Added local source launchers and cross-platform release packaging scripts.
- **release:** Added tag-triggered GitHub Release workflow for native binaries.
- **test:** Expanded CLI tests to cover suppression, baseline, missing baseline failures, SARIF, and JSON summary counters.

## 0.2.0 (2026-06-15)

### IoT Domain Rules (5 new rules)

- **cli:** `iot_security` rule — detects hardcoded credentials, cleartext MQTT (port 1883), cleartext HTTP, and insecure BLE configurations (p0, architecture)
- **cli:** `device_lifecycle` rule — checks balanced init/teardown pairs (initState↔dispose, connect↔disconnect, startScan↔stopScan, listen↔cancel, subscribe↔unsubscribe) (p0, architecture)
- **cli:** `mqtt_connection` rule — validates MQTT connect/disconnect and subscribe/unsubscribe pairing, detects hardcoded broker URLs (p0, architecture)
- **cli:** `ble_scanning` rule — checks BLE startScan/stopScan pairing, connect/disconnect, and scan timeout configuration (p1, architecture)
- **cli:** `pubspec_security` rule — analyzes pubspec.yaml for unbounded dependencies, deprecated packages (flutter_blue→flutter_blue_plus), and outdated IoT dependencies (p2, standards)

### UX Improvements

- **cli:** Positional path argument — `flutterguard scan ./my_project` now works without `-p` flag
- **cli:** Project auto-discovery — walks up from CWD to find `flutterguard.yaml`, `pubspec.yaml`, or `lib/`
- **cli:** Config path resolution with 3-tier priority (absolute → CWD-relative → project-relative)
- **cli:** `--no-color` flag to disable ANSI terminal output
- **cli:** Cross-platform compile scripts (`scripts/compile.sh`, `scripts/compile.ps1`)

### CI & Automation

- **ci:** GitHub Actions workflow with ubuntu/macos/windows matrix
- **ci:** Local CI scripts (`scripts/scan_ci.sh`, `scripts/scan_ci.ps1`) with configurable gates
- **docs:** README restructured — user install (pub.dev) / native binary / developer install tiers
- **docs:** README CI integration examples (GitHub Actions, GitLab CI, pre-commit hook, local scripts)
- **docs:** Windows commands use correct backslash paths in install and compile steps

### Total Rules: 11 rule classes, 13 rule IDs

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
