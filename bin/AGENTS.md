# Executable layer

`flutterguard.dart` may parse global arguments, route the four command families,
print usage/version, and map format errors to exit code 2.

Keep business logic in `lib/src/cli` or the scan kernel. Do not add rule wiring,
configuration defaults, report construction, or a second versioned API here.
