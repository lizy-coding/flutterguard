# CLI Entry Layer

## Responsibility
`flutterguard.dart` is only the command-line adapter.

It should:
- Parse commands and options with `package:args`.
- Support positional path: `flutterguard scan ./my_project` (no `-p` required).
- Print help/version text.
- Convert validation or scan errors into documented exit codes.
- Call `FlutterGuardScanner.scan()` for real work.
- Pass `--no-color` flag through to `ReportGenerator`.

It should not:
- Implement rules.
- Read Dart files directly.
- Generate reports beyond calling `ReportGenerator`.
- Duplicate scan orchestration already in `lib/src/scanner.dart`.

## Exit Codes
- `0`: success or help/version output
- `1`: CI gate failed
- `2`: bad input, bad config, or scan setup error

## Required Checks
After changing this layer, run:
- `dart run melos run analyze`
- `dart run melos run test:cli`
