# Internal Implementation Layer

## Responsibility
This directory contains reusable implementation for the CLI.

## Main Files
- `scanner.dart`: global scan orchestration and `ScanResult`.
- `config_loader.dart`: YAML parsing into typed record configs.
- `file_collector.dart`: include/exclude glob file discovery.
- `report_generator.dart`: table and JSON output.
- `static_issue.dart`: issue data model.
- `path_utils.dart`: cross-platform path/glob helpers.
- `import_utils.dart`: Dart import resolution against collected files.
- `source_utils.dart`: analyzer source location helpers.
- `rules/`: rule implementations only.

## Design Rules
- Keep `bin/` thin; reusable logic belongs here.
- Prefer typed records and small helper classes over dynamic maps.
- Convert analyzer offsets to line numbers before storing `StaticIssue.line`.
- Keep Windows path behavior covered by tests when touching path/import logic.
- Do not depend on Flutter; this package is a Dart CLI.
