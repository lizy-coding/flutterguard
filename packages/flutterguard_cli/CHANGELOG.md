# Changelog

## 0.6.0 (2026-07-16)

- Added 10 AST-first state-management maintainability rules, bringing the registry to 23 rule IDs.
- Added shared state configuration, severity/priority overrides, framework auto-detection, allowlists, ignore paths, confidence, and evidence.
- Extended table, JSON, rules/explain, and SARIF output without changing baseline fingerprints or existing report fields.
- State dependency cycles now use file-qualified nodes and import-aware resolution, preventing false cycles when projects contain duplicate type names.
- Aligned the published package SDK constraint and install examples with the Dart 3.11.5 release workflow.
- Added generic, Riverpod, Bloc, and Provider fixtures; the CLI suite now contains 83 tests, including version synchronization, per-rule enablement, suppression, baseline, duplicate-name, and changed-only graph coverage.

## 0.5.0 (2026-07-12)

### Architecture Refactor

- **cli:** Introduced shared scan analysis infrastructure: `ScanContext`, `SourceWorkspace`, `ImportGraph`, and `DependencyBoundaryEngine`.
- **cli:** Added `rules/catalog.dart` as the single source of truth for rule metadata and execution, routing all rules through the shared workspace.
- **cli:** Split command handlers into `lib/src/cli/`, reducing `bin/flutterguard.dart` to routing, help, and exit codes.
- **ci:** Aligned the release workflow Dart SDK with the workspace `^3.11.5` constraint.
- **fix:** Reject full scans whose include/exclude policy matches no Dart files instead of returning a successful empty report.
- **fix:** Resolve relative configs from the target project and reject missing explicitly selected config files.
- **fix:** Treat clean changed-only scans as successful empty incremental reports and reject invalid Git base refs.
- **ci:** Validate the current checkout on all supported CI operating systems instead of scanning with a pub.dev installation.

## 0.4.1 (2026-07-09)

### Adoption Hardening

- **cli:** Added `flutterguard doctor install` to diagnose executable version, Dart entrypoint, and PATH conflicts.
- **cli:** Added `flutterguard issue export` for local, user-reviewed false-positive feedback bundles.
- **cli:** Added `flutterguard baseline stats`, `flutterguard baseline prune`, and `flutterguard baseline check --no-growth`.
- **cli:** Added `flutterguard init --profile` starter profiles and positional `init [<path>]` support.
- **test:** Added coverage for install diagnostics, issue export, baseline management, and config profiles.

## 0.4.0 (2026-07-08)

### CI Adoption

- **cli:** Added `flutterguard baseline create [<path>]` to snapshot existing issues into `.flutterguard/baseline.json`.
- **cli:** Added `scan --baseline <file>` to hide baseline-matched issues from stdout, JSON, SARIF, scoring, and CI gates.
- **cli:** Added source suppression comments: `// flutterguard: ignore <rule_id>`, comma-separated IDs, and `ignore all`.
- **cli:** Added `--format sarif` with SARIF 2.1.0 output at `.flutterguard/report.sarif` for GitHub Code Scanning.
- **cli:** JSON summary now reports `suppressed` and `suppressedByBaseline` counts.
- **docs:** Updated README command references, CI onboarding order, suppression examples, baseline usage, and SARIF upload workflow.
- **release:** Documented source-checkout launcher usage to avoid stale global binaries.

### Tests

- **test:** Added coverage for suppression matching, next-line `ignore all`, baseline filtering, missing baseline errors, JSON counters, and SARIF structure.
- **test:** CLI test suite now covers 43 tests.

## 0.3.0 (2026-06-28)

### Incremental Scan (--changed-only)

- **cli:** New `--changed-only` flag — only scans `.dart` files changed since `--base` (default: `main`)
- **cli:** Integrated `git diff --name-only` + `git ls-files --others` for change detection
- **cli:** Non-git fallback: gracefully degrades to full scan
- **cli:** `circular_dependency` auto-disabled in changed-only mode
- **cli:** JSON report now includes `scanMode: full|changed` field

### Rule Introspection (rules / explain)

- **cli:** New `flutterguard rules` subcommand — list all 13 rules with ID, domain, name
- **cli:** New `flutterguard explain <rule-id>` subcommand — detailed purpose, risk, example, fix, config
- **cli:** New `RuleMeta` class in `lib/src/rule_meta.dart` — structured rule metadata
- **cli:** New `RuleRegistry` singleton in `lib/src/rules/registry.dart` — registry with `all()` and `find()`
- **cli:** Output supports both `table` (default) and `--format json`

### Tests

- **test:** 37 total tests (26 base + 6 new + 5 existing)
- **test:** 3 `changed-only` tests: git repo filter, non-git fallback, skip cycle
- **test:** 3 registry tests: all 13 rules, find by ID, unknown returns null

### Infrastructure

- **meta:** Version bumped to 0.3.0
- **meta:** `AGENTS.md` and `FLUTTERGUARD_SPEC.md` updated for new features

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
