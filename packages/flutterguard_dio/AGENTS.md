# Package: flutterguard_dio [FROZEN]

## Role
Dio HTTP interceptor for FlutterGuard flow tracing — records HTTP requests/responses within active flows.

**Status: FROZEN**. No new features. Bug fixes only.

## Dependency Map
- depends on: flutterguard_core (path), dio ^5.7.0
- depended by: nothing

## Entry Points
- lib barrel: `lib/flutterguard_dio.dart`

## Key Source Files
| File | Responsibility |
|------|---------------|
| `src/dio_interceptor.dart` | FlutterGuardDioInterceptor: onRequest/onResponse/onError hooks |

## Pubspec Overrides
melos-managed: flutterguard_core → path: ../flutterguard_core

## Test
- command: `melos run test:dio`
- test file: `test/dio_interceptor_test.dart` (4 tests)

## Why Frozen
Only meaningful when core runtime tracing is also active. Static analysis approach (Path A) does not require HTTP interception.
