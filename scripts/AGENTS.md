# Packaging and release scripts

| file | platform | role |
|---|---|---|
| `package_release.sh` | macOS and Linux | native compile, version smoke, versioned tar.gz under `dist/` |
| `package_release.ps1` | Windows | native compile, version smoke, versioned ZIP under `dist/` |
| `release_preflight.sh` | shell host with Dart | dependencies, format, analysis, tests, example scan and pub.dev dry-run |
| `idea_plugin_preflight.sh` | macOS/Linux | native-resource sync, Gradle check, verifier and plugin ZIP |
| `idea_plugin_publish.sh` | macOS/Linux | IDEA preflight followed by Marketplace publication |

## Ownership and version

- Keep scripts as packaging and validation orchestration; introduce no Dart
  dependencies, scanner logic, or rule metadata.
- Read package version from root `pubspec.yaml`. Check the native CLI's
  `--version` agrees with it; the entry point currently has its own version
  constant, so agreement must be verified when versions change.
- Release preflight and native packaging resolve the committed lock against
  `https://pub.dev`, independently of a developer's local mirror setting.
  Dependency resolution must succeed before downstream CLI checks run.
- Native package folders are `dist/boundarylens-<version>-<os>-<arch>`.
  Packaging builds for the actual host/target and must run `dart compile exe`
  and the resulting binary's version check.
- Export `PLUGIN_VERSION` from pubspec for IDEA builds; Gradle also reads the
  root pubspec when unset. Verify the packaged version rather than assuming it.

## Gate and mutation boundaries

CLI preflight checks a clean worktree and runs the full Dart gate plus publish
dry-run. Its dependency resolution and example scan can write local files;
its dry-run never uploads a package. Preserve unrelated work instead of
removing files to satisfy its clean-worktree gate.

The first IDEA release targets only macOS arm64, as confirmed by the user.
Preflight runs on that host and requires its versioned native binary and matching
OS/architecture descriptor dependencies. It copies the binary into
`idea-plugin/src/main/resources/bin/`, changes executable modes where relevant,
and invokes Gradle `check`, `verifyPlugin`, and `buildPlugin`. It does not
compile missing binaries or prove Marketplace publication. Other native resources
are rejected in this distribution. CLI portability is independent of this first
IDE release; adding a target requires a separate distribution decision and smoke.

Keep CLI preflight, native packaging, IDEA verification, and publication
statuses distinct. A documentation refresh needs changed-path and whitespace
checks, not either preflight. Run publish scripts only for an explicitly
requested release; never print credentials.

See root `AGENTS.md` for repository constraints and the IDEA scoped guide for
resource names and the process protocol.
