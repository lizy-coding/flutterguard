# Project Context

> **Purpose**: Session handover document. Agents should read this first.
> **Also read**: `AGENTS.md` (project rules & package hierarchy), `PROJECT_RULES.md` (constitution), `docs/ARCHITECTURE.md` (dependency chains).

---

## Completed (Current Session)

| # | Task | Details |
|---|------|---------|
| 1 | Project rename | `flutterguard_flow` → `flutterguard` in melos.yaml, pubspec.yaml, README |
| 2 | Chinese README | `README.zh.md` with language toggle links |
| 3 | .gitignore cleanup | Deduplicated, sectioned (Dart/Flutter/CLI/IDE/macOS) |
| 4 | Example refactoring | Removed `examples/checkout/` (Flutter view), added `examples/scan_demo/` (CLI target) + `examples/usage_demo/` (tracing API demo) |
| 5 | .idea config | Updated project name, modules, added runConfigurations (trace_demo, scan_demo, melos bootstrap/clean/test), cleaned misc.xml |
| 6 | Clean tracked artifacts | Removed 3x `pubspec_overrides.yaml` + `.idea/caches/` + `.idea/git_toolbox_prj.xml` from git tracking |
| 7 | Directory rename | `flutterguard_flow/` → `flutterguard/` (git mv) |
| 8 | Create `PROJECT_RULES.md` | Agent-readable constitution (Root) |
| 9 | Supplement `docs/FLUTTERGUARD_SPEC.md` | §0 Scope + §15 IoT rules + updated Roadmap/Commands/Known Limitations |
| 10 | Renumber spec sections | §0 added, existing sections renumbered through §15 |

## Strategic Decisions

| Decision | Detail |
|----------|--------|
| **Path A first** | CLI static aspect analysis is primary; runtime tracing (Path B) is frozen |
| **Project identity** | IoT/smart home Flutter project static analysis plugin — NOT a general observability SDK |
| **Convergence strategy** | Spec/rules first, code converges gradually per PR (best burn rate) |

## Pending

| # | Task | Priority | File |
|   |------|----------|------|
| 1 | Refocus CLI rules toward IoT domain | Medium | Add device lifecycle, MQTT, BLE, security rules |
| 2 | Archive or spin off runtime packages | Low | `flutterguard_core`, `flutterguard_dio`, `flutterguard_flutter` |

## Key Files

| File | Purpose |
|------|---------|
| `PROJECT_RULES.md` | Agent-readable scope & conventions |
| `docs/FLUTTERGUARD_SPEC.md` | Single source of truth for implementation |
| `flutterguard.yaml` | CLI config schema example |
| `packages/flutterguard_cli/` | PRIMARY active package |
| `packages/flutterguard_core/` | [Transitional] runtime tracing — frozen |
| `packages/flutterguard_dio/` | [Transitional] frozen |
| `packages/flutterguard_flutter/` | [Transitional] frozen |
| `examples/scan_demo/` | CLI scan target for testing |
| `examples/usage_demo/` | Tracing API example |

## Agent Instructions

When resuming, always read `CONTEXT.md` (session state), `AGENTS.md` (project rules), `PROJECT_RULES.md` (constitution), `docs/ARCHITECTURE.md` (architecture), then reference `docs/FLUTTERGUARD_SPEC.md` for detailed specs.
