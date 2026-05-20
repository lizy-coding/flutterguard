# Package: flutterguard_core [FROZEN]

## Role
Flow-level aspect tracing engine — trace models, Zone-based context propagation, ring buffer store, and JSON/Markdown exporters.

**Status: FROZEN**. No new features. Bug fixes only.

## Dependency Map
- depends on: meta ^1.12.0
- depended by: flutterguard_cli (path), flutterguard_dio (path), flutterguard_flutter (path)

## Entry Points
- lib barrel: `lib/flutterguard_core.dart`

## Key Source Files
| File | Responsibility |
|------|---------------|
| `src/flutter_guard.dart` | Static API: action(), span(), record*(), export*() |
| `src/guard_config.dart` | FlutterGuardConfig model |
| `src/trace_context.dart` | Zone-based traceId propagation |
| `src/trace_model.dart` | Data models: FlowTrace, SpanTrace, NetworkTrace, etc. |
| `src/trace_store.dart` | Ring buffer singleton store (100 trace default) |
| `src/json_exporter.dart` | JSON export formatting |
| `src/markdown_exporter.dart` | Markdown export formatting |

## Pubspec Overrides
melos-managed: none (core has no path deps)

## Analysis Options
Inherits root strict-casts/strict-inference + package:lints/recommended.yaml (from pubspec).

## Test
- command: `melos run test:core`
- test file: `test/flutter_guard_test.dart` (7 tests)

## Forward Compatibility
- Keep public API stable (flutterguard_cli depends on this via path)
- Do NOT add new exports without team consensus
- Do NOT remove existing public APIs (breaks cli, dio, flutter packages)

## Why Frozen
Runtime tracing approach was superseded by static analysis (Path A). Core remains as a reference implementation and may be re-visited in M4 roadmap.
