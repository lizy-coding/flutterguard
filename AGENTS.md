# flutterguard — Agent Guide

## Identity

FlutterGuard is an executable-only static analysis CLI for IoT/smart-home
Flutter projects. It is not an observability SDK, APM product, hosted service,
or general-purpose style linter.

## Repository

This is one Dart package rooted at the repository root.

```text
bin/       executable entry point
lib/src/   scan, config, report, and rule implementation
test/      contract and detector tests
example/   CI scan target
doc/       architecture and external contract
scripts/   native release packaging
```

Do not reintroduce Melos, `packages/`, archived runtime packages, a plugin
system, or a public scanner library API.

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

- `ScanContext` carries project/all/target files, scan mode, config, and the
  shared `SourceWorkspace`.
- `SourceWorkspace` owns source reads, AST parsing, line info, and diagnostics.
- Architecture rules share one `ImportGraph`.
- Layer and module enforcement share `BoundaryRule` and
  `DependencyBoundaryEngine`.
- `RuleRegistry.registrations` is the only metadata/default/execution registry.
- Rules receive effective generic `RuleConfig`; rule-specific defaults live in
  `RuleDefinition.defaultOptions`.
- CLI and JSON/SARIF are the supported integration boundary. `lib/src` is
  private implementation.

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
