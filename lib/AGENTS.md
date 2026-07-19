# Library boundary

`flutterguard_cli.dart` intentionally exports no scanner API. FlutterGuard is
an executable package; integrations use the CLI plus JSON or SARIF.

All implementation belongs under `src/`. Do not export internal rule,
configuration, AST, or report types from the package barrel.
