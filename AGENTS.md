# flutterguard — IoT Flutter Static Analysis CLI

## Identity
IoT/smart home Flutter project static analysis CLI plugin. NOT an observability SDK or APM tool.

## Architecture
- **Monorepo**: melos, 1 package + 1 example
- **Path A (ACTIVE)**: `flutterguard_cli` — all new features
- **Path B (ARCHIVED)**: `flutterguard_core`, `flutterguard_dio`, `flutterguard_flutter` — in `archive/` for future reference

## Package Hierarchy
| Package | Status | Depends On | Depended By |
|---------|--------|------------|-------------|
| flutterguard_cli | ACTIVE | args, analyzer, glob, path, yaml | — |
| scan_demo | — | (none, scan target) | — |

## Key Commands
| Command | Purpose |
|---------|---------|
| `dart run melos bootstrap` | Install workspace dependencies |
| `dart run melos run analyze` | dart analyze on all packages |
| `dart run melos run test:cli` | CLI tests only |
| `dart run flutterguard scan -p <path>` | Run scan on a project |

## CLI Entry Point
`packages/flutterguard_cli/bin/flutterguard.dart`

Wired rules (5): LargeUnitsRule, LifecycleResourceRule, LayerViolationRule, ModuleViolationRule, CircularDependencyRule

## Source Layout
```
packages/flutterguard_cli/lib/src/
  config_loader.dart         # YAML → ScanConfig (incl architecture.layers/modules)
  file_collector.dart        # Glob file discovery
  static_issue.dart          # StaticIssue + RiskLevel + IssueDomain + Priority
  report_generator.dart      # Table + JSON output + score
  domain.dart                # IssueDomain enum (architecture/performance/standards)
  priority.dart              # Priority enum (p0/p1/p2)
  rules/
    large_units.dart         # large_file, large_class, large_build_method
    lifecycle_resource.dart  # lifecycle_resource_not_disposed
    layer_violation.dart     # layer_violation (architecture layer breaches)
    module_violation.dart    # module_violation (cross-module breaches)
    circular_dependency.dart # circular_dependency (file-level cycles)
```

## Spec
Single source of truth: `docs/FLUTTERGUARD_SPEC.md` — read before implementing any feature.

## Maintenance Rules
1. New rule: spec entry → config typedef → rule class → fixture → test → wire into bin/flutterguard.dart
2. Always run `melos run analyze` + `melos run test:cli` before committing
3. Do NOT modify archived packages (core/dio/flutter) — they are frozen references
4. Do NOT add Flutter widgets, web/cloud infra, or SaaS SDKs
5. Output format defaults to `table`. JSON available via `--format=json`
6. Architecture rules require explicit `architecture.layers` / `architecture.modules` in flutterguard.yaml
