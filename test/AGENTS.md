# Tests

Contract-organized, not monolithic:

| file | scope |
|---|---|
| `cli_test.dart` | exit codes, path handling, report paths |
| `config_test.dart` | generic config, registry-driven templates |
| `rules_test.dart` | detector ownership, positive/negative/disabled/suppression |
| `scanner_test.dart` | orchestration, reports, baseline, CI gates |

Prefer temp directories for project/config/Git. External contract changes →
update focused assertion. Do not preserve deleted-feature tests.

See root AGENTS.md §Per-layer constraints for MUST NOT list.
