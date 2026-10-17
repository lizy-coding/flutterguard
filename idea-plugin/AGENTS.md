# IntelliJ integration

This directory owns editor integration and native CLI packaging. Detector,
configuration, and finding ownership remain in the root Dart scanner.

## Entry points and protocol

- `BoundaryLensExternalAnnotator` collects the selected Dart file, invokes the
  native CLI, retains the full report, and projects current-file findings into annotations.
- `BoundaryLensSettings` owns the project-local enabled flag only. The IDE
  displays findings without a severity gate; gate policy belongs to CLI callers.
- `META-INF/plugin.xml` declares plugin ID `com.boundarylens` and its editor,
  project-service, settings, and optional Dart integration entry points.
- The annotator invokes `scan <absolute-file.dart> --format json --stdout
  --no-color --fail-on none` with the IDE project as working directory.
  Keep stdout as JSON and stderr as diagnostics. Exit 0 and 1 both allow report
  parsing; exit 2 or higher is a failed invocation.
- Map `high` to ERROR, `medium` to WARNING, and `low` to WEAK WARNING. Keep
  finding IDs, locations, and domain supplied by the CLI.
- Keep the existing 30-second invocation deadline visible when verifying IDE
  behavior. Missing resources, timeout, or parse failure is not scan success.

## Native resources and version

The first release is macOS ARM64 only. The preflight packages this native resource:

```text
src/main/resources/bin/boundarylens-darwin-arm64
```

`../scripts/idea_plugin_preflight.sh` copies these from versioned `dist/`
packages and runs Gradle check, verifier, and build. Its preflight is mutating.
Runtime resource lookup is owned by `BoundaryLensNativeCli`; Windows includes
the `.exe` suffix. Extract once per IDE process and reject unsupported hosts.
The descriptor declares com.intellij.modules.os.mac and com.intellij.modules.arch.arm64
so Marketplace limits delivery. Resource-name mapping tests do not declare release
support for the other hosts.
`PLUGIN_VERSION` is supplied from the root pubspec; Gradle reads that same file
when unset. Verify the version in the packaged descriptor and native executable.

For integration changes, select the annotator/settings/descriptor files and
CLI output contract tests that match the change. Validate supported native
resources and the Gradle gates when packaging changes. No whole-repository
scan is needed to update this guide.

Do not duplicate detector or registry logic here, expose private Dart APIs,
or claim publication from a plugin ZIP alone. Use the root `AGENTS.md` and
`../scripts/AGENTS.md` for authoritative scope and release boundaries.

## Scan snapshots and validation

Collect immutable path/document-stamp information on the IDE read thread. Never
scan unsaved disk content as if it were the current document. Discard stale
results; do not clamp invalid locations onto unrelated lines. Parse schema and retain all findings, including unanchored project findings.
Filter to the selected file only when rendering editor annotations. Drain stdout/stderr while waiting, honor
cancellation, and show scanner failures/diagnostics instead of empty success.

`./gradlew check buildPlugin` is the implementation gate. `-PlocalIdePath` and
`BOUNDARYLENS_KOTLIN_VERSION` allow a matching installed SDK/compiler for local
validation; they must match the declared 261 / IDEA 2026.1.5 compatibility line.
See `README.md` here for installation and manual acceptance.

## Package reports and module coverage

The manual package action resolves the nearest ancestor pubspec.yaml of the
selected Dart file and invokes the same CLI process path with that package root.
Never substitute a workspace root for a nested package. A read-only text report
retains full finding paths, reason/detail, diagnostics, and module coverage.
Coverage statuses not_configured/disabled/complete/partial and scope
project/file/changed describe this scan only; zero findings or complete does not
certify whole-project architecture. Missing coverage from an older CLI is unknown.
Untrusted IDE projects must not invoke the CLI automatically or manually; do not
change the user's trust setting. Unsaved disk-content and stale-result safeguards
apply to both actions. Native smoke tests must exercise the current module-entry
contract rather than silently validating an old bundled detector.

## Bundled documentation

`docs/guide.html` and `docs/screenshots/` are packaged under `documentation/`
for the read-only settings gallery. `docs/changelog.html` is the sole change-notes
source for both What's New and the bundled version history. Keep local iteration
records distinct from published versions. Verify actual Swing HTML/image
rendering and viewport layout; successful resource loading alone is insufficient.
