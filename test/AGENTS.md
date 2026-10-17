# Tests

Contract-organized, not monolithic:

| file | scope |
|---|---|
| `cli_test.dart` | exit codes, path handling, report paths |
| `config_test.dart` | generic config, registry-driven templates |
| `rules_test.dart` | detector ownership, positive/negative/disabled/suppression |
| `lifecycle_resource_test.dart` | nullable/generic fields, AST cleanup, delegates and lifecycle negative cases |
| `module_entry_test.dart` | module public entries, reference identity, ownership/config errors, coverage, CLI gates and filtering contracts |
| `rename_contract_test.dart` | BoundaryLens CLI identity, new/legacy config priority and suppression migration |
| `rule_contract_test.dart` | private rule接入、输入/范围/身份/参数校验、执行状态与报告兼容 |
| `scanner_test.dart` | orchestration, reports, baseline, CI gates |

Prefer temp directories for project/config/Git. External contract changes →
update focused assertion. Do not preserve deleted-feature tests.

See root AGENTS.md §Per-layer constraints for MUST NOT list.
