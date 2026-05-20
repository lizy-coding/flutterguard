# FlutterGuard

> **IoT Flutter project static analysis CLI — architecture enforcement, code quality, CI gating.**

FlutterGuard scans Flutter/Dart source code to detect architecture issues, security vulnerabilities, and anti-patterns specific to IoT device applications. Designed for CI integration and team-wide adoption.

## Installation

### Prerequisites

- [Dart SDK](https://dart.dev/get-dart) >=3.3.0

### Option A: Global activation (cross-platform)

```bash
# Clone the repo
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard

# Install monorepo dependencies
dart pub global activate melos
melos bootstrap

# Register flutterguard command globally
dart pub global activate --source path packages/flutterguard_cli

# Verify installation
flutterguard --help
```

> **Windows**: After activation, ensure `%USERPROFILE%\AppData\Local\Pub\Cache\bin` is in your `PATH`. Dart SDK installer usually adds it automatically. To verify: `where flutterguard`.

### Option B: Compile native binary

```bash
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
melos bootstrap
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
```

### Option C: Pre-compiled binary (macOS/Linux only)

```bash
curl -sL https://github.com/lizy-coding/flutterguard/releases/download/v0.1.0/flutterguard -o /usr/local/bin/flutterguard
chmod +x /usr/local/bin/flutterguard
```

## Quick Start

```bash
# Scan a Flutter project
flutterguard scan -p /path/to/your/project

# JSON output for CI
flutterguard scan -p . --format json --fail-on high

# See all options
flutterguard --help
```

### Demo

```bash
# From the repo root, scan the demo project
flutterguard scan -p examples/scan_demo
```

---

## Available Rules (6)

| Rule ID | Level | Domain | What it detects |
|---------|-------|--------|----------------|
| `large_file` | LOW | standards | Files exceeding maxLines (default 500) |
| `large_class` | LOW | standards | Classes exceeding maxLines (default 300) |
| `large_build_method` | MEDIUM | performance | Widget build() exceeding maxLines (default 80) |
| `lifecycle_resource_not_disposed` | MEDIUM | performance | StreamSubscription, Timer, AnimationController, MqttClient, BluetoothDevice, StreamController without matching cancel/dispose/close |
| `layer_violation` | HIGH | architecture | Cross-layer import violations (YAML-configured) |
| `module_violation` | HIGH | architecture | Cross-module import violations (YAML-configured) |
| `circular_dependency` | MEDIUM | architecture | File-level import cycles |
| `missing_const_constructor` | LOW | standards | StatelessWidget/StatefulWidget subclasses missing const constructor |

---

## Configuration

Create a `flutterguard.yaml` in your project root:

```yaml
include:
  - lib/**

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
  missing_const_constructor:
    enabled: true

architecture:
  layers:                        # Layered architecture enforcement
    - name: presentation
      path: lib/presentation/**
      allowed_deps: [domain, core]
    - name: domain
      path: lib/domain/**
      allowed_deps: [core]
    - name: data
      path: lib/data/**
      allowed_deps: [domain, core]
    - name: core
      path: lib/core/**
      allowed_deps: []

  modules:                       # Business module isolation
    - name: device_mqtt
      path: lib/device/mqtt/**
      allowed_deps: [domain, core]
    - name: device_ble
      path: lib/device/ble/**
      allowed_deps: [domain, core]

  detect_cycles: true
  layer_violation:
    enabled: true
  module_violation:
    enabled: true
```

---

## Output Formats

### Table (default)

```
 FlutterGuard Report  ─  scan_demo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 总评分:  98/100  优秀      文件总数: 2  问题总数: 2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 代码规范  2 items  ▰  LOW
────────────────────────────────────────────────────────────────
 LOW  P2 可选
       类过大
       lib/services/user_service.dart:3
       类 "UserService" 49 行（阈值: 30 行）
       修复: 建议将 "UserService" 的职责提取到更小的类中
```

### JSON

```bash
flutterguard scan -p . --format json
```

Output written to `.flutterguard/report.json`:

```json
{
  "version": "1.0.0",
  "score": 85,
  "summary": {
    "total": 3,
    "high": 1,
    "medium": 1,
    "low": 1,
    "byDomain": {
      "architecture": { "high": 1, "medium": 0, "low": 0, "total": 1 },
      "performance": { "high": 0, "medium": 1, "low": 0, "total": 1 },
      "standards":   { "high": 0, "medium": 0, "low": 1, "total": 1 }
    }
  },
  "issues": [...]
}
```

---

## CI Integration

```bash
# Fail the build if any HIGH issues exist
flutterguard scan -p . --format json --fail-on high

# Enforce a minimum score of 80
flutterguard scan -p . --format json --min-score 80

# Accept only clean scans (no issues at any level)
flutterguard scan -p . --fail-on low
```

**Exit codes**: `0` = pass, `1` = gate failed, `2` = error

---

## Scoring

```
score = max(0, 100 - high*10 - medium*4 - low*1)
```

| Score | Rating |
|-------|--------|
| 80-100 | 优秀 (Excellent) |
| 50-79 | 需关注 (Needs review) |
| 0-49 | 需整改 (Needs action) |

---

## Development

```bash
# Bootstrap monorepo
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
melos bootstrap

# Analyze
dart run melos run analyze

# Test (12 tests)
dart run melos run test:cli

# Compile CLI
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
```

---

## License

MIT
