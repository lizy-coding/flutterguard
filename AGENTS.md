# flutterguard — Agent Guide

## Identity and integration boundary

FlutterGuard is an independent static analysis CLI and IDE integration for
Dart/Flutter projects. The Dart package is `flutterguard_cli`; the executable is
`flutterguard`. Application integrations use CLI JSON or SARIF reports.
`lib/src` is private implementation, and the package adds no runtime SDK to a
scanned application.

`idea-plugin/` is the IntelliJ integration. It invokes a bundled native CLI;
it does not own detectors, rule defaults, or a second scanner API. The CLI has
no extension plugin system.

## Repository

The scanner is a single Dart package at the repository root.

```text
bin/             executable entry; command routing only
lib/             barrel; no public scanner API exports
lib/src/         scan/config/report kernel
lib/src/cli/     command parsers and command I/O
lib/src/rules/   detectors, definitions, sole rule registry
idea-plugin/     IntelliJ adapter and bundled native CLI resources
scripts/         native packaging, CLI and IDEA release preflight
test/           contract and detector tests
test/fixtures/  small parser inputs, one behavior per file
example/         CI scan target
doc/             architecture, external spec, roadmap
```

## Bounded exploration

- Resolve the local repository, target package, and applicable path policy
  before reading source. If an external host is used, its registration is
  additional evidence; local development does not require that host.
- Inspect `git status --short --branch` and recent commit file lists. Read this
  guide, `CONTEXT.md`, `pubspec.yaml`, and the scoped guides for selected paths.
- Follow explicit entry points, imports, and files changed by the task. Start
  with at most 8 additional files and record why any expansion is needed.
- Documentation or registration updates do not justify a whole-repository
  scan, registry refresh, recursive file walk, or `flutterguard scan .`.
  Output-count limits alone do not prove that source traversal is bounded.
- Preserve unrelated dirty files. Keep proposed edits within the task's
  declared paths and the host's allowed paths; use one explicit reviewable
  scope for any required expansion.

## Commands and verification

For a CLI or detector change, resolve dependencies and run the applicable
focused tests first. The complete Dart gate is:

```bash
dart pub get
dart format --output=none --set-exit-if-changed bin lib test
dart analyze
dart test
dart run bin/flutterguard.dart scan example --format json --no-color
dart compile exe bin/flutterguard.dart -o flutterguard
dart pub publish --dry-run
```

For Agent-document-only changes, validate changed Markdown, referenced paths,
and `git diff --check`; a full scanner run or test suite is not required.
`bash scripts/release_preflight.sh` is the CLI release gate. IDEA has a separate
preflight in `scripts/idea_plugin_preflight.sh`; it copies native binaries into
plugin resources and invokes Gradle, so it is not a read-only inspection.
Run publishing commands only for a release requested in the current task.

## Architecture invariants

- `ScanContext` carries project/all/target files, scan mode, config, and
  `SourceWorkspace`.
- `SourceWorkspace` owns source reads, AST parsing, line info, and diagnostics.
- Architecture rules share one `ImportGraph`.
- Layer/module enforcement share `BoundaryRule` and
  `DependencyBoundaryEngine`.
- `RuleRegistry.registrations` is the only metadata/default/execution registry.
- Rules receive generic `RuleConfig`; rule-specific defaults belong to
  `RuleDefinition.defaultOptions`.
- `FlutterGuardScanner` owns scan orchestration, suppression, baseline
  filtering, and report generation. CLI and IDE adapters own their I/O only.

## Per-layer constraints

Root constraints are authoritative; scoped `AGENTS.md` files are additive.

| layer | MUST NOT |
|---|---|
| `bin/` | business logic, rule wiring, config defaults, report construction, second API |
| `lib/` | public scanner API exports from the barrel |
| `lib/src/` | bypass `ScanContext`, parse files independently, duplicate config defaults, second registry, non-cross-platform paths |
| `lib/src/cli/` | scan orchestration, rule execution, config loading |
| `lib/src/rules/` | read/parse files independently, ignore effective `RuleConfig`, duplicate finding ownership or metadata catalogs |
| `idea-plugin/` | duplicate detectors or rule registry, import private Dart implementation, treat exit 1 as invalid structured output |
| `test/` | monolithic suite, preserve deleted-feature tests for historical count |
| `test/fixtures/` | generated outputs, full sample apps, multiple behaviors per file where avoidable |
| `example/` | change scan inputs without checking their expected reports |
| `scripts/` | introduce Dart dependencies, assume another target OS, skip native compile/version checks |

## Product and IDE contract

Command families are `scan`, `baseline create`, `config init|check`, and
`rules [rule-id]`. Findings use `ruleId`, `severity`, and `domain`; severity is
`high`, `medium`, or `low`. JSON uses schema `2.0.0`; SARIF uses `2.1.0`.

A `.dart` file is a supported explicit scan target. Its project root is resolved
from an ancestor `pubspec.yaml`; a single-file request must retain its target
semantics even when architecture rules need project context.

`scan <file.dart> --format json --stdout --no-color` returns the structured
report on stdout without report-file writes. Diagnostics and severity gate
messages belong on stderr. Exit 0 means the scan and gate passed, exit 1 means
findings failed the configured gate, and exit 2 means input or scan setup was
invalid. Exit 1 still carries usable JSON/SARIF. Preserve changed-only scanning,
inline suppression, baseline filtering, single-file targets, and stdout output
contracts when changing the CLI or kernel.

## Public maintenance boundary

- No consumer repository paths, module registries, generated Agent contracts,
  platform matrices, or project-specific presets in the scanner or IDE.
- Consumers own business contracts, admission, tests, and CI policy. Integrate
  through the CLI and reports; do not couple dependency resolution or Git hooks
  to FlutterGuard.
- Before adding a rule, document a concrete defect, existing-tool coverage,
  required inputs, supported positive/negative cases, and remediation.
- Prefer removing speculative detectors over building type/data-flow systems
  solely to justify them. Existing rule inventory is not proof of reliability.

## Adding or changing a rule

1. Implement or extend a detector under `lib/src/rules/`.
2. Add exactly one registration and definition in `lib/src/rules/registry.dart`.
3. Add positive, negative, disabled, and output-contract coverage as needed.
4. Update `doc/FLUTTERGUARD_SPEC.md` only for external contract changes.
5. Run the complete Dart verification gate.

Generic file size, formatting, and missing-const checks belong to Dart lints or
dedicated complexity tooling. Framework is descriptive metadata, not a global
configuration switch. Do not add priority, score, confidence, or compatibility
aliases to the finding taxonomy.

## Documentation hierarchy

- `CONTEXT.md` defines the domain vocabulary only.
- This file defines repository constraints and execution entry points.
- Scoped `AGENTS.md` files define directory responsibilities.
- `doc/ARCHITECTURE.md` defines internal boundaries.
- `doc/FLUTTERGUARD_SPEC.md` defines external behavior.
- `README.md` is user onboarding; `EVOLUTION_PLAN.md` holds local evolution
  checkpoints and execution order.

Update the narrowest authoritative document when behavior changes. Historical
reports are evidence snapshots; do not rewrite them as current acceptance.
