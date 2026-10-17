# BoundaryLens

BoundaryLens is an independently maintained static analysis tool for
Dart/Flutter projects, with a CLI and an IntelliJ adapter. Applications consume
JSON or SARIF reports; they do not depend on a runtime SDK or private scanner API.

The next-stage workflow protects project-declared module public entry points.
See the [four-file runnable example](idea-plugin/examples/module_boundary/README.md).
Only architecture checks are enabled by default; lifecycle, IoT/security and
state-framework checks remain available with explicit `enabled: true`.
Missing module configuration is reported as `not_configured`, not a project pass.

```yaml
architecture:
  modules:
    - name: checkout
      path: lib/checkout/**
      allowed_deps: [payment]
      entry_points: [lib/checkout/api.dart]
    - name: payment
      path: lib/payment/**
      allowed_deps: []
      entry_points: [lib/payment/api.dart]
```

Adjust paths to existing files. Cross-module references must use the target's
declared entry, while its own facade may export internal files. Omitting
entry_points preserves dependency-only checks and reports partial protection.

Consumer projects own their business contracts, module admission, platform
acceptance, and CI policy. BoundaryLens does not read a project's generated
Agent contracts or require a particular repository layout, generator, or host.
Use Dart/Flutter format, analysis, and tests for their existing responsibilities;
use BoundaryLens only where an explicit detector adds useful evidence.

## IntelliJ IDEA plugin

This repository is the source and release-maintenance home for the BoundaryLens
IDEA plugin: [lizy-coding/flutterguard](https://github.com/lizy-coding/flutterguard).
The plugin delegates detection to the bundled CLI maintained in this same repository.

- [Installation, examples and screenshots](idea-plugin/README.md)
- [Plugin release maintenance](idea-plugin/RELEASING.md)
- [Version history](idea-plugin/docs/changelog.html)
- [User license](idea-plugin/docs/eula.md) and [privacy statement](idea-plugin/docs/privacy.md)
- [Marketplace submission preparation](idea-plugin/release-review/marketplace-submission.md)

Local preparation does not publish these materials or the plugin. Marketplace
availability and approval must be recorded after an actual submission.

## Install

BoundaryLens is currently a local source iteration. The new package name is not
claimed to be published on pub.dev. See [rename migration](doc/RENAMING.md) and
[the next module-check milestones](doc/MODULE_DETECTION_NEXT_STEPS.md).

```bash
dart pub global activate --source path .
boundarylens --version
```

From a source checkout:

```bash
dart pub get
dart run bin/boundarylens.dart scan example
```

## Commands

```text
boundarylens scan [path] [options]
boundarylens baseline create [path]
boundarylens config init [path]
boundarylens config check [path]
boundarylens rules [rule-id] [--format table|json]
```

The core scan options are:

- `--config`, `-c`: explicit configuration file.
- `--format`, `-f`: `table`, `json`, or `sarif`.
- `--output`, `-o`: report directory; default `.boundarylens`.
- `--stdout`: print JSON/SARIF to stdout instead of writing report files.
- `--fail-on`: `none`, `high`, `medium`, or `low`.
- `--changed-only --base <ref>`: scan Git-changed Dart files.
- `--baseline <file>`: hide findings already recorded in a baseline.
- `--verbose`: include diagnostics, detail, and evidence.
- `--no-color`: disable ANSI terminal color.

Exit code `0` means the scan completed and the gate passed. Exit code `1` means
the severity gate failed. Exit code `2` means the command or scan setup was
invalid.

## Optional tool integration

Install the CLI independently of the application package. An agent or toolset
can invoke it with an explicit package/file target and configuration:

```bash
boundarylens config check /path/to/app
boundarylens scan /path/to/app/lib/example.dart --config /path/to/app/boundarylens.yaml --format json --stdout --no-color --fail-on none
```

Exit 1 still carries a usable structured report; exit 2 is a failed invocation.
The consumer decides whether findings block a change. Inspect diagnostics as well
as findings; an empty finding list alone is not proof of complete verification.

## IDE integration

| BoundaryLens severity | IDE inspection level | SARIF level |
|---|---|---|
| `high` | ERROR | error |
| `medium` | WARNING | warning |
| `low` | WEAK WARNING | note |

## Configuration

Configuration is optional. Generate a complete starter file from the rule
registry:

```bash
boundarylens config init .
boundarylens config check .
```

Minimal example:

```yaml
include:
  - lib/**

exclude:
  - lib/generated/**
  - lib/**.g.dart

rules:
  iot_security:
    enabled: true
    severity: high
    requireTls: true
  ble_scanning:
    enabled: true
    severity: medium

architecture:
  detect_cycles: true
  layers:
    - name: presentation
      path: lib/presentation/**
      allowed_deps: [domain, core]
    - name: domain
      path: lib/domain/**
      allowed_deps: [core]
    - name: core
      path: lib/core/**
      allowed_deps: []
  modules: []
```

Every rule accepts `enabled` and `severity`. Rule-specific scalar options are
listed by `boundarylens rules <rule-id>`.

## Rules

The registry currently contains 16 rule IDs. This is an implementation inventory,
not a claim that every detector is suitable for a blocking gate. Architecture
checks require explicit boundaries; lifecycle, transport, and state heuristics
need consumer-specific positive and negative validation before enforcement:

- Architecture: `layer_violation`, `module_violation`,
  `circular_dependency`, `state_layer_ui_dependency`,
  `state_dependency_cycle`.
- Lifecycle and performance: `lifecycle_resource_not_disposed`,
  `side_effect_in_build`, `state_manager_created_in_build`,
  `riverpod_read_used_for_render`, `riverpod_watch_in_callback`,
  `provider_value_lifecycle_misuse`, `notify_listeners_in_loop`.
- IoT security: `ble_scanning`, `iot_security`.
- State standards: `mutable_state_exposed`,
  `bloc_equatable_props_incomplete`.

Generic file-size, missing-const, dependency-version, and broker-configuration
checks were removed in 0.7.0. Dart lints, `dart pub outdated`, dependency
security tools, and application configuration are better owners.

## Reports and CI

JSON uses schema version `2.0.0` and exposes one canonical field name per
concept: `ruleId`, `severity`, and `domain`. SARIF 2.1.0 is suitable for GitHub
Code Scanning.

```bash
boundarylens baseline create .
boundarylens scan . \
  --baseline .boundarylens/baseline.json \
  --format sarif \
  --fail-on high
```

Suppression comments remain available for precise false positives:

```dart
// boundarylens: ignore iot_security
final endpoint = loadLocalDevelopmentEndpoint();
```

## Repository layout

```text
bin/                 executable entry point
lib/src/cli/         command parsers and handlers
lib/src/rules/       registry, rule definitions, and detectors
lib/src/             scan/config/report shared kernel
test/                contract and detector tests
example/             scan target used by CI
doc/                 architecture and external contract
scripts/             native release packaging only
```

BoundaryLens is a single Dart package. There is no Melos workspace, runtime
SDK, plugin system, or public Dart scanner API.

## Development

```bash
dart pub get
dart format --output=none --set-exit-if-changed bin lib test
dart analyze
dart test
dart run bin/boundarylens.dart scan example --format json --no-color
dart pub publish --dry-run
```

### Release preflight

Before creating a release tag, run the compact preflight command:

```bash
bash scripts/release_preflight.sh
```

It resolves dependencies, checks formatting, analysis, tests, and the CLI
example, then runs `dart pub publish --dry-run` without uploading anything.
It finishes by printing the required human checks for package contents, legal
redistribution, version/tag, and publisher access. A nonzero exit means at
least one automated release gate failed.

See [doc/ARCHITECTURE.md](doc/ARCHITECTURE.md) for internal boundaries and
[doc/BOUNDARYLENS_SPEC.md](doc/BOUNDARYLENS_SPEC.md) for the external
contract.

## License

MIT. See [LICENSE](LICENSE).
