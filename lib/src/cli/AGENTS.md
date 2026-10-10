# CLI sub-layer

This layer owns argument parsing and command I/O routing. The scan kernel owns
scan orchestration, rule execution, configuration loading, suppression,
baseline matching, and report generation.

## File map

| file | role |
|---|---|
| `cli_parsers.dart` | `ArgParser` definitions for all command families |
| `scan_command.dart` | scan arguments to `FlutterGuardScanner`, stdout/stderr and severity gate |
| `baseline_commands.dart` | baseline create argument routing |
| `config_commands.dart` | config init and check routing |
| `rule_commands.dart` | rules list and detail I/O |

## Target and report contract

- Preserve directory, single `.dart` file, and Git changed-only requests. Pass
  the explicit target to the kernel; do not expand it into an independent scan.
- A single-file request resolves its project root through an ancestor
  `pubspec.yaml`. Project context needed by architecture rules does not change
  the selected finding target.
- In `--stdout` mode, stdout contains the selected structured JSON or SARIF
  report. Preserve the kernel's no-report-file-write behavior. Put diagnostics,
  setup errors, and severity gate messages on stderr.
- Exit 0 means scan and gate passed; exit 1 means visible findings failed the
  configured gate; exit 2 means command input or scan setup was invalid.
  Structured output remains valid on exit 1.
- JSON findings retain `ruleId`, `severity`, and `domain`; do not add aliases or
  transform severity for an IDE. The IDE owns display mapping.
- Keep tests focused on changed argument, output, and exit-code behavior;
  detector behavior belongs to detector/kernel tests.

For exploration, start with the changed command and its parser/kernel calls;
do not invoke an unrestricted project scan to update this guide.

See root `AGENTS.md` for authoritative layer and path constraints.
