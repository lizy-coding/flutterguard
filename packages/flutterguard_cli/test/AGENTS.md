# Test Layer

## Responsibility
Tests verify rule behavior, scanner orchestration, report generation, and cross-platform path handling.

## Main Test File
`scanner_test.dart` is the current integration-style test suite for the CLI package.

## Rules
- Add a fixture for every new rule or regression case.
- Keep fixtures small unless testing size thresholds.
- Test Windows path behavior using `package:path` contexts instead of requiring Windows.
- Prefer testing reusable `lib/src/` behavior directly; only shell out to the CLI when validating argument/exit behavior.
- Temporary files created by tests must be deleted with `addTearDown`.

## Required Command
Run `dart run melos run test:cli` after test changes.
