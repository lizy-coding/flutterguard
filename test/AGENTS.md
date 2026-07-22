# Tests

Tests are organized by contract rather than one monolithic suite:

- `cli_test.dart`: process-level exit/path/report behavior.
- `config_test.dart`: generic config and registry-driven templates.
- `rules_test.dart`: detector ownership and positive cases.
- `scanner_test.dart`: orchestration, reports, baseline, and CI gates.
- `fixtures/`: parser inputs excluded from repository analysis.

Prefer temporary directories for project/config/Git behavior. Every external
contract change must update a focused assertion; do not preserve deleted
features merely to keep the historical test count.
