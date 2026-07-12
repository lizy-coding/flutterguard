# FlutterGuard Evolution Roadmap

FlutterGuard remains an IoT / smart home Flutter static analysis toolchain. The
core product direction is static governance for Flutter projects, not runtime
observability, APM, cloud dashboards, crash reporting, or SDK instrumentation.

## Guiding Principles

- Keep the CLI as the source of truth for scanning, configuration, reports, and
  CI behavior.
- Prefer local-first integrations that consume CLI output before introducing
  hosted services.
- Focus on real team adoption: low-noise CI, editor feedback, baseline
  management, and actionable reports.
- Avoid archived runtime packages for new feature work.

## Architecture Invariants (do not violate)

These were established by the v0.5.0 refactor and are binding for all future
work. New agents MUST follow them instead of reintroducing pre-0.5.0 patterns.

- Rule metadata and execution are wired through `lib/src/rules/catalog.dart`.
  It is the single source of truth. Do NOT wire rules directly in
  `bin/flutterguard.dart` or `scanner.dart`, and do NOT add reflection or
  dynamic plugin loading.
- `bin/flutterguard.dart` is thin: top-level routing, help, positional path,
  and exit codes only. Functional command behavior lives in `lib/src/cli/`
  (`scan_command`, `baseline_commands`, `config_commands`, `issue_commands`,
  `rule_commands`, `cli_parsers`).
- Rules consume shared analysis state, not ad-hoc file reads:
  - `SourceWorkspace` for source/AST caching and diagnostics.
  - `ImportGraph` for resolved Dart imports.
  - `DependencyBoundaryEngine` for layer/module boundary checks.
  - `ScanContext` for scan scope/mode (project/all/target files).
- Each rule keeps the standalone `analyze(List<String> files, {SourceWorkspace?
  workspace})` API so direct rule tests and programmatic consumers keep working.
- New rule flow is unchanged: spec entry → config typedef → rule class →
  fixture → test → wire into `rules/catalog.dart`.
- Workspace SDK constraint is `^3.11.5`; keep CI (`release.yml`,
  `flutterguard.yml`) SDK aligned when it changes.

## Current State (as of v0.5.0)

- Milestone 0.4.x (CI Adoption Hardening) is DONE: baseline `stats` / `prune` /
  `check --no-growth`, config profiles, install diagnostics, issue export, and
  no-match / changed-only scan policy hardening all shipped in 0.4.0–0.4.1.
- v0.5.0 was consumed by the internal architecture refactor above rather than
  the originally planned developer-workflow integrations. Those integrations
  now move to Milestone 0.6.

## Milestone 0.6 — Developer Workflow Integrations

Goal: Surface FlutterGuard findings before CI by integrating with developer
tools.

Deliverables:

- Official GitHub Action:
  - install FlutterGuard
  - run scan
  - upload JSON / SARIF artifacts
  - optionally upload SARIF to GitHub Code Scanning
- GitHub PR annotations mode for changed-line findings.
- VS Code extension MVP driven by CLI JSON output:
  - run scan on demand
  - show diagnostics in the editor
  - open rule explanations
  - insert suppression comments
- Config profiles:
  - `recommended`
  - `strict`
  - `migration`
  - `iot-security`
  - `architecture-only`

Exit Criteria:

- New users can add FlutterGuard to GitHub Actions with one reusable action.
- Developers can see and suppress findings in VS Code without reading CI logs.
- Teams can start from a profile instead of hand-authoring every rule setting.

## Milestone 0.7 — Fixes, Reports, and Workspace Scale

Goal: Move from reporting issues to helping teams reduce them across larger
Flutter codebases.

Deliverables:

- Auto-fix support for safe cases:
  - add missing `const` constructors where deterministic
  - insert suppression comments for selected findings
  - suggest `pubspec.yaml` dependency replacements
- Static HTML report output for local reviews and architecture audits.
- Melos / monorepo workspace scanning:
  - scan all packages
  - scan one package
  - scan affected packages
  - merge package reports
- Architecture graph exports:
  - Mermaid
  - DOT
  - dependency cycle graph
  - layer / module violation graph

Exit Criteria:

- Teams can track and reduce findings without building custom scripts.
- Large Flutter workspaces can run FlutterGuard package-by-package.
- Architecture violations can be reviewed visually during refactors.

## Milestone 0.8 — Deeper Static Analysis

Goal: Reduce false positives and expand IoT-specific detection using stronger
AST and project context.

Deliverables:

- Lifecycle detection improvements:
  - helper dispose methods
  - base classes and mixins
  - composite disposer patterns
  - resource collections
- Import resolution improvements:
  - package name awareness
  - workspace package imports
  - generated-file boundaries
- Additional IoT checks:
  - OTA update safety patterns
  - token and key storage risks
  - device pairing flow risks
  - local network discovery risks
  - permission and privacy configuration checks

Exit Criteria:

- Core lifecycle and IoT security rules produce fewer false positives on real
  projects.
- Monorepo package imports are handled consistently.
- New IoT checks remain static-only and CI-safe.

## Milestone 0.9+ — Extensibility and Team Governance

Goal: Support mature teams that need reusable governance policies without
turning FlutterGuard into a hosted platform.

Deliverables:

- Reusable team rule packs.
- Shared config inheritance:
  - local file extends
  - bundled profiles
  - organization profile conventions
- Custom rule SDK exploration.
- IntelliJ / Android Studio plugin after VS Code integration stabilizes.
- Optional GitHub App only if GitHub Action annotations are insufficient.

Exit Criteria:

- Teams can standardize policies across many Flutter apps.
- Customization is possible without weakening the built-in static analysis
  contract.
- Hosted services remain optional and out of the core product path.

## Non-Goals

- Runtime tracing SDK.
- APM or observability platform.
- Crash reporting.
- Cloud dashboard as a required workflow.
- Network proxy or HTTP inspector.
- Flutter widget library.
- Editing archived runtime packages in `archive/`.

## Recommended Priority

1. Official GitHub Action.
2. Baseline management commands.
3. VS Code extension MVP.
4. Config profiles and inheritance.
5. PR annotations.
6. Auto-fix for deterministic cases.
7. Static HTML report.
8. Workspace / monorepo scanning.
9. Architecture graph export.
10. Custom rule SDK exploration.
