# Public Library Layer

## Responsibility
`lib/flutterguard_cli.dart` is the public barrel for tests and programmatic consumers.

Export reusable models, config, scanner, report generation, rules, and shared utilities from here when they are stable enough for internal reuse.

## Rules
- Keep implementation in `lib/src/`.
- Do not put business logic directly in the barrel file.
- Avoid exporting experimental helpers unless tests or downstream usage need them.
- Preserve the static-analysis CLI identity; do not add runtime SDK APIs here.
