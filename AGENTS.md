# flutterguard — Agent Guide

## Identity

FlutterGuard is an executable-only static analysis CLI for IoT/smart-home
Flutter projects. It is not an observability SDK, APM product, hosted service,
or general-purpose style linter.

## Repository

Single Dart package at root. No Melos, no `packages/`, no plugin system, no
public scanner library API.

```text
bin/             entry → route only, no business logic
lib/             barrel → no public API exports
lib/src/         kernel → scan, config, report, rules
lib/src/cli/     command parsers and I/O only
lib/src/rules/   detectors, registry, definitions
test/            contract and detector tests
test/fixtures/   small parser inputs, one behavior per file
example/         CI scan target, read-only
doc/             architecture, spec, roadmap
scripts/         native release packaging (bash + powershell)
```

## Commands

```bash
dart pub get
dart format bin lib test
dart analyze
dart test
dart run bin/flutterguard.dart scan example --format json --no-color
dart compile exe bin/flutterguard.dart -o flutterguard
dart pub publish --dry-run
```

## Architecture invariants

- `ScanContext` carries project/all/target files, scan mode, config,
  `SourceWorkspace`.
- `SourceWorkspace` owns source reads, AST parsing, line info, and diagnostics.
- Architecture rules share one `ImportGraph`.
- Layer/module enforcement share `BoundaryRule` +
  `DependencyBoundaryEngine`.
- `RuleRegistry.registrations` is the only metadata/default/execution registry.
- Rules receive generic `RuleConfig`; rule-specific defaults in
  `RuleDefinition.defaultOptions`.
- CLI + JSON/SARIF is the integration boundary. `lib/src` is private
  implementation.

## Per-layer constraints (authoritative; subdirectory AGENTS.md files are additive only)

| layer | MUST NOT |
|---|---|
| `bin/` | business logic, rule wiring, config defaults, report construction, second API |
| `lib/` | public API exports from barrel file |
| `lib/src/` | bypass `ScanContext`, parse files independently, duplicate config defaults, second registry, non-cross-platform paths |
| `lib/src/cli/` | scan orchestration, rule execution, config loading |
| `lib/src/rules/` | read/parse files independently (use `SourceWorkspace`), ignore `RuleConfig.enabled`, emit wrong severity, duplicate finding ownership, add metadata catalog |
| `test/` | monolithic suite, preserve deleted-feature tests for historical count |
| `test/fixtures/` | generated outputs, full sample apps, multiple behaviors per file (where practical) |
| `example/` | modify without updating expected scan reports |
| `scripts/` | introduce Dart deps, assume OS other than target, skip `dart compile exe` precheck |

## Product surface

Supported command families are `scan`, `baseline create`, `config init|check`,
and `rules [rule-id]`.

The canonical finding taxonomy is `ruleId + severity + domain`. Do not add
priority, score, confidence, or compatibility aliases. Framework is descriptive
metadata, not a global configuration switch.

Keep changed-only scanning, inline suppression, baseline filtering, JSON, and
SARIF behavior covered by tests.

## Adding or changing a rule

1. Implement or extend a detector under `lib/src/rules/`.
2. Add exactly one registration and definition in `rules/registry.dart`.
3. Add positive, negative, disabled, and output-contract coverage as needed.
4. Update `doc/FLUTTERGUARD_SPEC.md` only for external contract changes.
5. Run the full verification commands above.

Do not add generic size, formatting, or missing-const checks; those belong to
Dart lints or dedicated complexity tooling.

## Documentation hierarchy

- `EVOLUTION_PLAN.md` is the local checkpoint and next-step execution order.
- This file defines repository-wide constraints.
- Nested `AGENTS.md` files contain only directory-specific responsibilities.
- `doc/ARCHITECTURE.md` defines internal boundaries.
- `doc/FLUTTERGUARD_SPEC.md` defines external behavior.
- `README.md` is the user onboarding document.

When behavior changes, update the narrowest authoritative document rather than
copying the same contract across every level.
