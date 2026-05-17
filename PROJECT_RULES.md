# Project Rules for FlutterGuard

## 1. Identity
- FlutterGuard is an **IoT/smart home Flutter project static analysis CLI plugin**.
- NOT a general observability SDK, APM tool, or crash reporter.
- Output: compiled CLI binary (`dart compile exe`) that scans Dart source code.

## 2. Active vs Frozen

| Path | Status | Package | Notes |
|------|--------|---------|-------|
| **Path A** — CLI static analysis | **ACTIVE** | `flutterguard_cli` | All new features |
| **Path B** — Runtime tracing | **FROZEN** | `core`, `dio`, `flutter` | Bug fixes only |

Do NOT modify frozen packages except for critical bug fixes. Do NOT add new features to them.

## 3. Architecture Constraints
- Monorepo managed by **melos**. New packages must register in `melos.yaml`.
- Active code lives in `packages/flutterguard_cli/lib/src/`.
- Each rule is a standalone class: `analyze(List<String> files) → List<StaticIssue>`.
- Configuration driven by `flutterguard.yaml` (YAML schema, parsed in `config_loader.dart`).
- No plugin system, no code generation, no reflection — explicit wiring in `bin/flutterguard.dart`.

## 4. Code Conventions
- Dart 3.3+, `strict-casts: true`, `strict-inference: true`.
- Prefer Dart **records** (`typedef`) for config types.
- Prefer `const` constructors and `final` locals.
- Wrap per-file parsing in try/catch (one bad file must not crash the scan).
- Import style: `package:flutterguard_cli/src/...` (no relative imports across packages).

## 5. Testing Conventions
- Tests live in `packages/flutterguard_cli/test/` using `package:test`.
- Fixtures go in `test/fixtures/<rule_name>.dart`.
- Every new rule requires: spec entry → config typedef → rule class → fixture → test.
- Run tests: `melos run test:cli`.

## 6. Spec Governance
- `docs/FLUTTERGUARD_SPEC.md` is the **single source of truth**.
- Spec must be updated **before** implementation.
- All rule IDs, risk levels, and metadata schemas must be documented in spec first.

## 7. Forbidden
- Do NOT create new Flutter widgets or UI components.
- Do NOT add web/cloud infrastructure or dashboard UI.
- Do NOT use third-party SaaS SDKs.
- Do NOT commit secrets, API keys, or credentials.
- Do NOT add runtime instrumentation outside frozen packages.
- Do NOT introduce `package:build` / code generation dependencies.

## 8. Git Workflow
- Branch: `develop` for active work. PRs merge to `develop`.
- Commit messages: imperative mood, prefixed by scope (`cli:`, `spec:`, `docs:`).
- Before committing: run `melos run analyze` and `melos run test:cli`.
- Do NOT force-push to `develop` or `main`.
