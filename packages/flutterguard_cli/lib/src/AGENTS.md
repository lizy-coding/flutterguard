# Internal Implementation Layer

## Responsibility
This directory contains reusable implementation for the CLI.

## Main Files
- `scanner.dart`: global scan orchestration and `ScanResult`.
- `scan_context.dart`: project/all/target file scope and scan mode.
- `source_workspace.dart`: shared source text/AST/line cache and diagnostics.
- `import_graph.dart`: resolved import graph shared by architecture rules.
- `boundary_engine.dart`: common layer/module dependency enforcement.
- `rules/catalog.dart`: explicit rule metadata and execution wiring.
- `config_loader.dart`: YAML parsing into typed record configs (20 rule configs + state management + architecture).
- `file_collector.dart`: include/exclude glob file discovery.
- `project_resolver.dart`: project auto-discovery (walk-up flutterguard.yaml / pubspec.yaml / lib/).
- `report_generator.dart`: table and JSON output with optional `--no-color` support.
- `static_issue.dart`: issue data model.
- `path_utils.dart`: cross-platform path/glob helpers.
- `import_utils.dart`: Dart import resolution against collected files.
- `source_utils.dart`: analyzer source location helpers.
- `rules/`: rule implementations only (21 rule classes, 23 rule IDs).

## Design Rules
- Keep `bin/` thin; reusable logic belongs here.
- Prefer typed records and small helper classes over dynamic maps.
- Convert analyzer offsets to line numbers before storing `StaticIssue.line`.
- Keep Windows path behavior covered by tests when touching path/import logic.
- Do not depend on Flutter; this package is a Dart CLI.
- pubspec_security handles project-root YAML parsing (uses `package:yaml` directly).
