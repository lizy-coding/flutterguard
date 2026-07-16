# FlutterGuard Architecture

## Monorepo Structure
```
flutterguard/
├── flutterguard.yaml              # CLI config example / root defaults
├── melos.yaml                     # Monorepo bootstrap + script orchestration
├── AGENTS.md                      # Agent-parseable project rules
├── PROJECT_RULES.md               # Human + agent constitution
├── analysis_options.yaml          # Root strict analysis config
├── pubspec.yaml                   # Root workspace (melos only)
├── docs/
│   ├── FLUTTERGUARD_SPEC.md       # Single source of truth
│   └── ARCHITECTURE.md            # This file
├── packages/
│   └── flutterguard_cli/          # [ACTIVE] CLI static analysis
├── archive/                       # Runtime tracing (v0.1.0, reserved)
│   ├── flutterguard_core/
│   ├── flutterguard_dio/
│   └── flutterguard_flutter/
└── examples/
    └── scan_demo/                 # CLI scan target
```

## Dependency Graph
```
                    ┌──────────────────┐
                    │  flutterguard    │  (root workspace)
                    └────────┬─────────┘
                             │ melos
                             ▼
                    ┌──────────────────────┐
                    │  flutterguard_cli     │
                    │  [ACTIVE]            │
                    │  deps: args,analyzer,│
                    │  glob,path,yaml      │
                    └──────────────────────┘
```

## CLI Scan Data Flow
```
User runs: dart run flutterguard scan -p <path> [--config <yaml>]
  │
  ├── 1. ArgParser parses CLI flags
  ├── 2. ScanConfig.fromFile() loads YAML config
  │       └── includes architecture.layers/modules declarations
  ├── 3. FileCollector.collect() globs .dart files
  │       └── applies include/exclude patterns
  ├── 4. ScanContext separates all files from changed target files
  ├── 5. SourceWorkspace reads/parses each target source once
  │       └── read/parse failures become ScanDiagnostic entries
  ├── 6. RuleCatalog explicitly wires 21 rule classes / 23 rule IDs
  │       ├── source rules share SourceWorkspace content/AST/line info
  │       ├── architecture rules share one ImportGraph
  │       └── layer/module checks share DependencyBoundaryEngine
  ├── 7. Issues sorted by risk level (high → medium → low)
  ├── 8. Suppression and baseline filters produce visible issues
  ├── 9. ReportGenerator generates output
  │       ├── Table → terminal stdout
  │       └── JSON → .flutterguard/report.json
  └── 10. CI gate check (exit 1 if fail threshold exceeded)
```

## Rule Architecture
```
Direct rule tests and programmatic consumers retain the standalone API:
  ┌──────────────────────────────────────────────┐
  │  class XxxRule {                             │
  │    analyze(List<String> files,               │
  │      {SourceWorkspace? workspace})           │
  │      → List<StaticIssue>                     │
  │  }                                           │
  └──────────────────────────────────────────────┘

Issue model (StaticIssue):
  id, title, file, line, level
  + domain (architecture/performance/standards)
  + priority (p0/p1/p2)
  + message, detail, suggestion, metadata
  + framework, confidence, evidence (up to 5 entries)
```

Scanner execution uses one `ScanContext` and one explicit `RuleCatalog`.
There is no dynamic plugin loading, reflection, or rule code generation.

Architecture data flow:

```
SourceWorkspace → ImportGraph → DependencyBoundaryEngine
                               ├── LayerViolationRule
                               └── ModuleViolationRule
                  ImportGraph ───── CircularDependencyRule
```

State-management data flow:

```
SourceWorkspace AST
  ├── shared build/callback/import/owner/glob helpers
  ├── generic build, mutability and UI-boundary rules
  ├── Riverpod / Bloc / Provider framework rules
  └── project-wide state graph → Tarjan SCC → deterministic shortest cycle
```

State rules are gated in this order: global `state_management.enabled`, the
per-rule switch, confidence threshold, framework import auto-detection,
`ignore_paths`, AST detection, then the existing suppression and baseline
filters. Changed-only state-cycle analysis builds from `allFiles` but reports
only components touching `targetFiles`.

## CLI Command Layout

`bin/flutterguard.dart` owns top-level routing, help, positional-path
normalization, and documented exit codes. Functional commands live under
`lib/src/cli/`:

- `cli_parsers.dart`: parser tree and command option contracts
- `scan_command.dart`: scan reporting and CI gates
- `baseline_commands.dart`: create/stats/prune/check
- `config_commands.dart`: init/config/doctor behavior
- `issue_commands.dart`: issue feedback export
- `rule_commands.dart`: rules/explain output

## Output Formats

| Format | Purpose | Enabled |
|--------|---------|---------|
| table | Human-readable terminal output grouped by domain | Default |
| json | Machine-readable for CI and custom tooling | --format=json |
| sarif | GitHub Code Scanning integration | --format=sarif |

## Override Chains

### pubspec_overrides.yaml (melos-managed)
- Only `flutterguard_cli` remains (no path dependencies)
- Run `melos bootstrap` after any pubspec.yaml change

### analysis_options.yaml Inheritance
```
root/analysis_options.yaml
  strict-casts: true, strict-inference: true
  └── packages/flutterguard_cli/analysis_options.yaml
        inherits root + package:lints/recommended.yaml
        excludes: test/fixtures/**
```

### flutterguard.yaml Config Override
```
root/flutterguard.yaml (default config, documented example)
  ├── <scan_target>/flutterguard.yaml (per-project config, merges over root)
  └── --config flag (CLI arg, highest priority)
```
