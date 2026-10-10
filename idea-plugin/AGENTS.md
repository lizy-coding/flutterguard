# IntelliJ integration

This directory owns editor integration and native CLI packaging. Detector,
configuration, and finding ownership remain in the root Dart scanner.

## Entry points and protocol

- `FlutterGuardExternalAnnotator` collects the selected Dart file, invokes the
  native CLI, parses the report, and creates annotations.
- `FlutterGuardSettings` owns the project-local enabled flag only. The IDE
  displays findings without a severity gate; gate policy belongs to CLI callers.
- `META-INF/plugin.xml` declares plugin ID `com.flutterguard` and its editor,
  project-service, and startup entry points.
- The annotator invokes `scan <absolute-file.dart> --format json --stdout
  --no-color --fail-on none` with the IDE project as working directory.
  Keep stdout as JSON and stderr as diagnostics. Exit 0 and 1 both allow report
  parsing; exit 2 or higher is a failed invocation.
- Map `high` to ERROR, `medium` to WARNING, and `low` to WEAK WARNING. Keep
  finding IDs, locations, and domain supplied by the CLI.
- Keep the existing 30-second invocation deadline visible when verifying IDE
  behavior. Missing resources, timeout, or parse failure is not scan success.

## Native resources and version

The preflight packages these native resources:

```text
src/main/resources/bin/flutterguard-darwin-arm64
src/main/resources/bin/flutterguard-darwin-x64
src/main/resources/bin/flutterguard-linux-x64
src/main/resources/bin/flutterguard-windows-x64.exe
```

`../scripts/idea_plugin_preflight.sh` copies these from versioned `dist/`
packages and runs Gradle check, verifier, and build. Its preflight is mutating.
Verify runtime lookup agrees with these names: the current `resolveBinary`
lookup omits the `.exe` suffix for Windows while the packaged resource includes
it. This source mismatch requires a separate fix before claiming Windows IDE
acceptance.
`PLUGIN_VERSION` is supplied from the root pubspec; do not interpret the Gradle
`0.0.0` fallback as an intended release.

For integration changes, select the annotator/settings/descriptor files and
CLI output contract tests that match the change. Validate supported native
resources and the Gradle gates when packaging changes. No whole-repository
scan is needed to update this guide.

Do not duplicate detector or registry logic here, expose private Dart APIs,
or claim publication from a plugin ZIP alone. Use the root `AGENTS.md` and
`../scripts/AGENTS.md` for authoritative scope and release boundaries.
