# CLI sub-layer

Argument parsing and command I/O routing. No scan orchestration, rule
execution, or config loading.

## File map

| file | role |
|---|---|
| `cli_parsers.dart` | `ArgParser` definitions for all command families |
| `scan_command.dart` | scan argument routing → `FlutterGuardScanner` |
| `baseline_commands.dart` | baseline create argument routing |
| `config_commands.dart` | config init + check routing |
| `rule_commands.dart` | rules list + detail I/O |

See root AGENTS.md §Per-layer constraints for MUST NOT list.
