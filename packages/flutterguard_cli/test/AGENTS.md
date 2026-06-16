# Test Layer

## Responsibility
Tests verify rule behavior, scanner orchestration, report generation, and cross-platform path handling.

## Main Test File
`scanner_test.dart` is the current integration-style test suite for the CLI package (26 tests, 5 groups).

## Test Groups
| Group | Tests | Coverage |
|-------|-------|---------|
| Static Rules | 18 | 8 existing rules + 5 IoT rules + config parsing + wiring |
| Report Generation | 2 | JSON and stdout output validation |
| Scanner Orchestration | 3 | Full scan, missing path exception, invalid config |
| Path Handling | 3 | Windows globs, package imports, cross-platform import resolution |

## Rules
- Add a fixture for every new rule or regression case.
- Keep fixtures small unless testing size thresholds.
- Test Windows path behavior using `package:path` contexts instead of requiring Windows.
- Prefer testing reusable `lib/src/` behavior directly; only shell out to the CLI when validating argument/exit behavior.
- Temporary files created by tests must be deleted with `addTearDown`.
- pubspec_security tests use `Directory.systemTemp.createTempSync()` for isolated pubspec.yaml.

## Required Command
Run `dart run melos run test:cli` after test changes.
