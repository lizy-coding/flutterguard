# FlutterGuard Flow

> **Flow-level aspect tracing and architecture scanning for Flutter apps.**

FlutterGuard connects user actions to async spans, network requests, route transitions, errors, frame metrics, rebuild boundaries, and static architectural risks — all in a single correlated report.

[![Dart](https://img.shields.io/badge/Dart-3.3%2B-blue)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.19%2B-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## What Makes It Different

| Not a crash SDK | Not an HTTP inspector | Not a logger |
|---|---|---|
| FlutterGuard doesn't replace Sentry/Crashlytics. It **connects** runtime behavior into structured traces. | Alice/Charles log request bodies. FlutterGuard records **only what happened** — method, path, status, duration — attached to your flow. | Debug logs are unstructured and ephemeral. FlutterGuard produces **exportable, correlation-first** reports. |

FlutterGuard answers questions like:

- *"Why did this user action take 2 seconds?"* — spans, network, frames
- *"Where did the error occur in the lifecycle of this action?"* — error within flow context
- *"Which files are architectural risks in this project?"* — static scan
- *"Did a rebuild cascade during this checkout?"* — GuardBoundary counters

---

## Installation

### Runtime Packages (Flutter app)

```yaml
# pubspec.yaml
dependencies:
  flutterguard_flutter: ^0.1.0
  flutterguard_dio: ^0.1.0   # if using Dio
```

### CLI (standalone tool)

```bash
dart pub global activate flutterguard_cli
# OR compile to native binary:
git clone https://github.com/your-org/flutterguard.git
cd flutterguard
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
```

---

## Quick Start

### 1. Wrap your app

```dart
import 'package:flutterguard_flutter/flutterguard_flutter.dart';

void main() {
  FlutterGuard.run(
    app: MaterialApp(
      navigatorObservers: [FlutterGuard.routeObserver],
      home: HomePage(),
    ),
  );
}
```

### 2. Trace a user action

```dart
ElevatedButton(
  onPressed: () {
    FlutterGuard.action('checkout', () async {
      // spans auto-attach to this flow
      final valid = await FlutterGuard.span('validate_cart', () => validate());
      if (valid) {
        await FlutterGuard.span('process_payment', () => process());
      }
    });
  },
  child: Text('Checkout'),
)
```

### 3. Add the Dio interceptor

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(FlutterGuardDioInterceptor());
```

### 4. Mark widget boundaries

```dart
GuardBoundary(
  name: 'CheckoutPage',
  child: CheckoutView(),
)
```

### 5. Export the report

```dart
final report = FlutterGuard.exportMarkdown();
print(report);

final json = FlutterGuard.exportJson();
await File('report.json').writeAsString(json);
```

### 6. Run a static scan

```bash
flutterguard scan --path ./my_project
```

---

## Runtime API

### `FlutterGuard.run()`

Initializes all hooks and starts the Flutter app. Must be called before `runApp`.

```dart
FlutterGuard.run(
  config: const FlutterGuardConfig(
    enabled: true,
    collectErrors: true,
    collectFrames: true,
    collectRoutes: true,
    collectBuilds: true,
    slowFlowMs: 1000,
    jankFrameMs: 16,
    maxTraces: 100,
  ),
  app: MyApp(),
);
```

### `FlutterGuard.action<T>(name, body, {tags})`

Creates a new flow trace. All spans, network calls, errors, routes, and frame metrics within `body` are automatically correlated.

```dart
await FlutterGuard.action('login', () async {
  final token = await auth.login(username, password);
  storage.saveToken(token);
}, tags: {'screen': 'login'});
```

### `FlutterGuard.span<T>(name, body, {tags})`

Creates a child span under the current flow. If no active flow, executes body directly without recording.

```dart
final data = await FlutterGuard.span('fetch_user', () => api.getUser(id));
```

### `FlutterGuardRouteObserver`

Add to `MaterialApp.navigatorObservers`. Records push, pop, replace, remove events.

```dart
MaterialApp(
  navigatorObservers: [FlutterGuard.routeObserver],
  // ...
)
```

### `GuardBoundary`

Wrap any widget to count rebuilds within an active flow.

```dart
GuardBoundary(
  name: 'ProductList',
  child: ProductListView(),
)
```

### `FlutterGuard.currentTraceId`

Returns the current flow trace ID from the Zone, or `null`.

```dart
final traceId = FlutterGuard.currentTraceId;
```

### `FlutterGuard.exportJson()` / `FlutterGuard.exportMarkdown()`

Export all recorded traces as structured reports.

```dart
final json = FlutterGuard.exportJson();       // JSON
final md = FlutterGuard.exportMarkdown();     // Markdown
```

### `FlutterGuard.reset()`

Clears all stored traces.

```dart
FlutterGuard.reset();
```

### `FlutterGuardDioInterceptor`

```dart
FlutterGuardDioInterceptor(
  sanitizeHeaders: true,
  sanitizeBody: true,
  sensitiveKeys: ['authorization', 'password'],
)
```

Default sensitive keys: `authorization, cookie, set-cookie, token, password, secret, email, phone`

Records method, path, status code, duration, success/failure. Does NOT log request/response bodies.

---

## CLI

### `flutterguard scan`

```
flutterguard scan [options]

Options:
  -p, --path      Project path to scan (default: .)
  -c, --config    Config file path (default: flutterguard.yaml)
  -f, --format    Output format: json | markdown | both (default: both)
  -o, --output    Output directory (default: .flutterguard)
  --fail-on       CI gate threshold: none | high | medium | low (default: none)
  --min-score     Minimum score 0-100
```

Output files:
- `.flutterguard/report.json` — machine-readable
- `.flutterguard/report.md` — human-readable

### `flutterguard.yaml`

```yaml
include:
  - lib/**
  - test/**

exclude:
  - lib/generated/**
  - lib/**.g.dart
  - lib/**.freezed.dart
  - lib/**.mocks.dart

rules:
  large_file:
    enabled: true
    maxLines: 500
  large_class:
    enabled: true
    maxLines: 300
  large_build_method:
    enabled: true
    maxLines: 80
  lifecycle_resource:
    enabled: true

boundaries:
  - name: cart_module
    from: lib/cart/**
    forbidden:
      - lib/checkout/**
      - lib/payment/**
```

### CI Integration

**GitHub Actions:**

```yaml
- name: FlutterGuard Scan
  run: |
    dart pub global activate flutterguard_cli
    flutterguard scan --path . --fail-on high
```

**Pre-commit (local):**

```bash
#!/bin/bash
flutterguard scan --path . --fail-on medium
```

Exit codes: `0` = pass, `1` = gate failed, `2` = error

---

## Static Rules

| Rule | Level | What it detects |
|------|-------|----------------|
| `large_file` | medium | Files exceeding maxLines (default 500) |
| `large_class` | medium | Classes exceeding maxLines (default 300) |
| `large_build_method` | medium | Widget build() methods exceeding maxLines (default 80) |
| `lifecycle_resource_not_disposed` | **high** | StreamSubscription, Timer, AnimationController, TextEditingController, ScrollController, FocusNode without matching cancel/dispose |
| `boundary_import_violation` | **high** | Imports that violate configured module boundaries |

**Scoring**: 100 base — 10 per high — 4 per medium — 1 per low (minimum 0)

---

## Report Format

### JSON

```json
{
  "version": "1.0.0",
  "generatedAt": "2026-05-16T12:00:00.000Z",
  "projectPath": "/Users/you/my_app",
  "score": 85,
  "summary": { "high": 1, "medium": 2, "low": 1, "total": 4 },
  "staticIssues": [
    {
      "id": "lifecycle_resource_not_disposed",
      "title": "Lifecycle resource not disposed",
      "file": "/Users/you/my_app/lib/widgets/player.dart",
      "line": 42,
      "level": "high",
      "message": "AnimationController \"_controller\" in \"PlayerWidget\" may not be properly disposed.",
      "suggestion": "Call \"_controller.dispose()\" in the dispose() method.",
      "metadata": {
        "className": "PlayerWidget",
        "resourceType": "AnimationController",
        "fieldName": "_controller",
        "expectedDisposeCall": "dispose"
      }
    }
  ]
}
```

### Markdown

Comprehensive report with sections: Summary, Static Issues (High/Medium/Low), Runtime Flows, and CI Result.

---

## M1 Feature List

- [x] `FlutterGuard.action()` — flow-level trace creation with Zone context
- [x] `FlutterGuard.span()` — async child spans, auto-correlated
- [x] `FlutterGuard.run()` — automatic error hooks, frame metrics, route observer
- [x] `FlutterGuardRouteObserver` — records push/pop/replace/remove
- [x] `GuardBoundary` — widget rebuild counting
- [x] `FlutterGuardDioInterceptor` — Dio 5.x HTTP tracing
- [x] CLI static scan — 5 rules, YAML config, JSON/Markdown reports
- [x] CI gate — `--fail-on` threshold-based exit codes
- [x] Score system — 0-100 based on issue severity
- [x] Demo app — checkout flow with all integrations

## Non-Goals (M1)

- AI-based diagnosis or auto-fix
- DevTools extension
- MQTT, BLE, or Matter protocol tracing
- Riverpod/BLoC/GetX state management adapters
- Full HTTP body inspection
- Crash SDK replacement (Sentry/Crashlytics)
- IDE lint plugin integration

---

## Example Output

Running the demo checkout flow:

```
# FlutterGuard Flow Report

**Generated**: 2026-05-16T12:00:00.000Z
**Score**: 100 / 100

## Summary
| Level | Count |
|-------|-------|
| High | 0 |
| Medium | 0 |
| Low | 0 |
| **Total** | **0** |

## Runtime Flows

### submit_order `4b7d261143d5`
- **Status**: success
- **Duration**: 250ms

#### Spans
| Name | Duration | Error |
|------|----------|-------|
| validate_form | 100ms | - |
| request_create_order | 42ms | - |

#### Network
| Method | Path | Status | Duration |
|--------|------|--------|----------|
| POST | /posts | 201 | 42ms |

#### Routes
| Type | From | To |
|------|------|----|
| push | / | OrderResult |

#### Build Boundaries
- **CheckoutPage**: 1 rebuilds

---
```

---

## Roadmap

| Milestone | Timeline | Focus |
|-----------|----------|-------|
| **M1** | Current | Flow tracing + static scan MVP |
| M2 | Q3 2026 | Type-accurate lifecycle detection, cycle detection, custom plugins |
| M3 | Q4 2026 | DevTools extension, Sentry bridge, timeline integration |
| M4 | 2027 | Enterprise features, multi-isolate, storage backends |

---

## Development

```bash
# Clone and bootstrap
git clone <repo-url>
cd flutterguard
melos bootstrap

# Analyze all packages
melos run analyze

# Run tests
dart test packages/flutterguard_core
dart test packages/flutterguard_dio
dart test packages/flutterguard_cli
flutter test packages/flutterguard_flutter

# Run the example
cd examples/checkout_flow_example
flutter run
```

---

## License

MIT
