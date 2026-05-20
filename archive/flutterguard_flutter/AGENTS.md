# Package: flutterguard_flutter [FROZEN]

## Role
Flutter runtime integration for FlutterGuard — error hooks, route observer, frame metrics, and GuardBoundary widget rebuild counter.

**Status: FROZEN**. No new features. Bug fixes only.

## Dependency Map
- depends on: flutterguard_core (path), flutter SDK (>=3.19.0)
- depended by: nothing

## Entry Points
- lib barrel: `lib/flutterguard_flutter.dart`

## Key Source Files
| File | Responsibility |
|------|---------------|
| `src/flutter_guard.dart` | FlutterGuard.run(): wraps core, error hooks, frame timing |
| `src/guard_boundary.dart` | GuardBoundary widget: rebuild count tracking |
| `src/route_observer.dart` | FlutterGuardRouteObserver: Navigator route tracking |

## Pubspec Overrides
melos-managed: flutterguard_core → path: ../flutterguard_core

## Test
- command: `flutter test` (not in melos scripts yet)
- test file: `test/flutter_test.dart` (4 tests)

## Why Frozen
Only meaningful when core runtime tracing is also active. Static analysis approach (Path A) does not require Flutter runtime instrumentation.

## Notes
- Has Flutter SDK constraint (>=3.19.0) — testing requires Flutter SDK to be installed
- Not included in `melos run test` (which uses `dart test`); run `flutter test` manually
