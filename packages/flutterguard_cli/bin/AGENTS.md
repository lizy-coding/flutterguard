# CLI Entry Layer

## Responsibility
`flutterguard.dart` is only the top-level command router.

It should:
- Use the parser tree from `lib/src/cli/cli_parsers.dart`.
- Support positional path: `flutterguard scan ./my_project` (no `-p` required).
- Print help/version text.
- Convert validation or scan errors into documented exit codes.
- Delegate functional command behavior to `lib/src/cli/`.

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
