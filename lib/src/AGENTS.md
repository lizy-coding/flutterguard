# Scan kernel

## File map

| file | role |
|---|---|
| `scanner.dart` | orchestration, suppression, baseline, report writes |
| `scan_context.dart` | immutable scan scope |
| `source_workspace.dart` | one-read/one-parse cache + diagnostics |
| `import_graph.dart` | resolved project import graph |
| `boundary_engine.dart` | shared boundary evaluator |
| `config_loader.dart` | YAML → generic `RuleConfig` |
| `config_tools.dart` | starter config + config validation |
| `report_generator.dart` | table + JSON output |
| `sarif_report.dart` | SARIF 2.1.0 output |
| `cli/` | argument parser + command I/O only |
| `rules/` | definitions, registry, detectors |

See root AGENTS.md §Per-layer constraints for MUST NOT list.
