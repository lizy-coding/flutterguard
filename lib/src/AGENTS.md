# Scan kernel

This directory owns reusable implementation behind the executable.

- `scanner.dart`: orchestration, suppression, baseline, report writes.
- `scan_context.dart`: immutable scan scope.
- `source_workspace.dart`: one-read/one-parse cache and diagnostics.
- `import_graph.dart`: resolved project import graph.
- `boundary_engine.dart`: boundary evaluation shared by layer/module rules.
- `config_loader.dart`: compact YAML parser and generic `RuleConfig`.
- `config_tools.dart`: generated starter config and config validation.
- `report_generator.dart` / `sarif_report.dart`: output adapters.
- `cli/`: argument parser and command I/O only.
- `rules/`: definitions, registry, and detectors.

Do not bypass `ScanContext`, parse files independently inside scanner wiring,
duplicate config defaults, or create another registry. File/path behavior must
remain cross-platform and changed-only imports must resolve against all files.
