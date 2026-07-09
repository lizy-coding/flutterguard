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

## Milestone 0.4.x — CI Adoption Hardening

Goal: Make the existing CLI reliable and low-friction in real CI pipelines.

Deliverables:

- Improve rule accuracy with more real-world IoT Flutter fixtures.
- Add baseline management commands:
  - `flutterguard baseline diff`
  - `flutterguard baseline prune`
  - `flutterguard baseline stats`
- Add CI guardrails to prevent baseline growth.
- Enhance SARIF output with richer rule metadata and precise locations where
  available.
- Add checked-in GitHub Actions examples for JSON gates and SARIF upload.
- Add more suppression tests around comments, whitespace, and adjacent issues.

Exit Criteria:

- CI users can onboard existing projects without blocking on historical issues.
- Baseline files can be reviewed and reduced over time.
- SARIF uploads cleanly to GitHub Code Scanning.

## Milestone 0.5 — Developer Workflow Integrations

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

## Milestone 0.6 — Fixes, Reports, and Workspace Scale

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

## Milestone 0.7 — Deeper Static Analysis

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

## Milestone 0.8+ — Extensibility and Team Governance

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
