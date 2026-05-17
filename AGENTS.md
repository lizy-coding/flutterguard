# flutterguard — IoT Flutter Static Analysis CLI

## Identity
IoT/smart home Flutter project static analysis CLI plugin. NOT an observability SDK or APM tool.

## Architecture
- **Monorepo**: melos, 4 packages + 2 examples
- **Path A (ACTIVE)**: `flutterguard_cli` — all new features
- **Path B (FROZEN)**: `flutterguard_core`, `flutterguard_dio`, `flutterguard_flutter` — bug fixes only

## Package Hierarchy
| Package | Status | Depends On | Depended By |
|---------|--------|------------|-------------|
| flutterguard_cli | ACTIVE | core, args, analyzer, glob, path, yaml | — |
| flutterguard_core | FROZEN | meta | cli, dio, flutter |
| flutterguard_dio | FROZEN | core, dio ^5.7.0 | — |
| flutterguard_flutter | FROZEN | core, flutter SDK | — |
| scan_demo | — | (none, scan target) | — |
| usage_demo | — | core | — |

## Override Chain
1. **pubspec_overrides.yaml** — melos auto-managed; 4 packages override `flutterguard_core` to local path
2. **analysis_options.yaml** — root strict-casts/strict-inference → per-package overrides (cli: +lints/recommended + fixture exclude)
3. **flutterguard.yaml** — root default config → user project overrides on scan

## Key Commands
| Command | Purpose |
|---------|---------|
| `melos bootstrap` | Install + generate pubspec_overrides |
| `melos run analyze` | dart analyze on all packages |
| `melos run format` | dart format on all packages |
| `melos run test` | Test all flutterguard_* packages |
| `melos run test:cli` | CLI tests only |
| `dart run flutterguard scan -p <path>` | Run scan on a project |

## CLI Entry Point
`packages/flutterguard_cli/bin/flutterguard.dart`

Wired rules (3): LargeUnitsRule, LifecycleResourceRule, BoundaryImportRule

## Source Layout
```
packages/flutterguard_cli/lib/src/
  config_loader.dart         # YAML → ScanConfig
  file_collector.dart        # Glob file discovery
  static_issue.dart          # StaticIssue + RiskLevel
  report_generator.dart      # JSON/MD output + score
  rules/
    large_units.dart         # large_file, large_class, large_build_method
    lifecycle_resource.dart  # lifecycle_resource_not_disposed
    boundary_import.dart     # boundary_import_violation
```

## Spec
Single source of truth: `docs/FLUTTERGUARD_SPEC.md` — read before implementing any feature.

## Maintenance Rules
1. New rule: spec entry → config typedef → rule class → fixture → test → wire into bin/flutterguard.dart
2. Always run `melos run analyze` + `melos run test:cli` before committing
3. Do NOT modify frozen packages (core/dio/flutter) except for critical bug fixes
4. Do NOT add Flutter widgets, web/cloud infra, or SaaS SDKs
