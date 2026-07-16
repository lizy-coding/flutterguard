# Test Layer

## Responsibility
Tests verify rule behavior, scanner orchestration, report generation, and cross-platform path handling.

## Test Files
- `scanner_test.dart`: reusable scanner/rule integration suite (78 tests, 8 groups).
- `cli_test.dart`: process-level CLI exit and report behavior (5 tests).

## Test Groups
| Group | Tests | Coverage |
|-------|-------|---------|
| Static Rules | 18 | 8 existing rules + 5 IoT rules + config parsing + wiring |
| Report Generation | 3 | JSON, stdout, and suppression summary output |
| Scanner Orchestration | 16 | Scan policy, root pubspec, diagnostics, suppression, baseline, SARIF, issue export |
| Changed-only | 7 | Git filtering, project rules, architecture target resolution, clean scans, invalid refs, non-Git fallback, cycle behavior |
| Registry | 3 | Rule metadata lookup |
| Config Tools | 7 | Init profiles, effective config, doctor, install diagnostics |
| Path Handling | 3 | Windows globs, package imports, cross-platform import resolution |
| CLI Process | 4 | Exit codes, config scoping/enforcement, empty changed JSON report |

## Rules
- Add a fixture for every new rule or regression case.
- Keep fixtures small unless testing size thresholds.
- Test Windows path behavior using `package:path` contexts instead of requiring Windows.
- Prefer testing reusable `lib/src/` behavior directly; only shell out to the CLI when validating argument/exit behavior.
- Temporary files created by tests must be deleted with `addTearDown`.
- pubspec_security tests use `Directory.systemTemp.createTempSync()` for isolated pubspec.yaml.

## Required Command
Run `dart run melos run test:cli` after test changes.
