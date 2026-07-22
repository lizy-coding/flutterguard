# FlutterGuard Architecture

## Shape

FlutterGuard is one publishable Dart package and one executable. The repository
root is the package root.

```text
bin/flutterguard.dart          parse and route four command families
lib/src/cli/                   command parsers and I/O adapters
lib/src/scanner.dart           scan orchestration
lib/src/config_loader.dart     YAML to compact generic rule settings
lib/src/source_workspace.dart  per-scan source/AST cache and diagnostics
lib/src/import_graph.dart      project-local resolved import graph
lib/src/boundary_engine.dart   shared dependency-boundary evaluator
lib/src/rules/registry.dart    only rule metadata/default/execution registry
lib/src/rules/rule.dart        RuleDefinition and RuleRegistration
lib/src/rules/*.dart           detectors
lib/src/report_generator.dart  table and JSON output
lib/src/sarif_report.dart       SARIF output
test/                          external contract and detector tests
example/                       CI scan target
```

There is no workspace orchestrator, runtime instrumentation package, dynamic
plugin loader, generated registry, or public Dart scanner API.

## Scan flow

```text
CLI
 └─ FlutterGuardScanner.scan
     ├─ ProjectResolver
     ├─ ScanConfig.fromFile
     ├─ FileCollector
     ├─ ScanContext
     │   ├─ SourceWorkspace
     │   └─ changed/all/target file sets
     ├─ RuleRegistry.analyze
     │   ├─ one shared ImportGraph when needed
     │   └─ explicit RuleRegistration executors
     ├─ SuppressionFilter
     ├─ optional Baseline
     └─ table / JSON / SARIF report
```

`ScanContext` is the only scanner-to-rule scope carrier. `SourceWorkspace`
reads and parses each source file at most once. Architecture checks share one
`ImportGraph`; layer and module rules share `BoundaryRule` and
`DependencyBoundaryEngine`.

## Rule model

`RuleRegistry.registrations` is the single source of truth. Every registration
contains:

- one `RuleDefinition`: ID, domain, default severity, documentation, options;
- one executor receiving `ScanContext`, effective `RuleConfig`, and an optional
  shared import graph.

Configuration defaults and `flutterguard rules` output are derived from these
definitions. Do not add another catalog, metadata registry, reflection layer,
or barrel export.

All rules receive common `enabled` and `severity` settings. Special settings
belong in `RuleDefinition.defaultOptions`; the current example is `requireTls`.

## Detection ownership

- `lifecycle_resource_not_disposed` owns resource close/cancel/dispose checks.
- `ble_scanning` owns scan timeout findings, not generic disconnect pairing.
- `iot_security` owns credentials and insecure transport findings.
- Dependency version and broker placement policy stay with ecosystem tools and
  application configuration rather than FlutterGuard rules.
- `BoundaryRule` owns both layer and module dependency policy.
- Framework-specific state rules activate from source imports; there is no
  global framework or confidence switch.

This ownership prevents the same source pattern from being reported by several
rule families.

## External boundaries

The supported integration boundary is the CLI plus JSON/SARIF. Code under
`lib/src` is package-private and may change without a Dart API migration.

Stable capabilities are:

- positional project path and explicit `--config`;
- changed-only scanning using a verified Git base;
- inline suppression and baseline filtering;
- severity-based CI exit codes;
- JSON schema versioning and SARIF 2.1.0.

Scoring, priority, confidence, compatibility aliases, profile presets, install
diagnostics, issue export, and baseline management subcommands are intentionally
outside the architecture.

## Change rules

When adding a detector:

1. implement or extend one detector file;
2. add one `RuleRegistration` with a `RuleDefinition`;
3. add positive, negative, disabled, and output-contract tests where relevant;
4. update the external spec only when the CLI/config/report contract changes.

Before delivery run `dart analyze`, `dart test`, a demo scan, and
`dart pub publish --dry-run` for release-affecting changes.
