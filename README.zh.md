# FlutterGuard

> **面向 Flutter 应用的流程级切面追踪与架构扫描工具。**

[**English**](README.md) | [**中文**](README.zh.md)

[![Dart](https://img.shields.io/badge/Dart-3.3%2B-blue)](https://dart.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.19%2B-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## 有何不同

| 不是崩溃 SDK | 不是 HTTP 抓包工具 | 不是日志库 |
|---|---|---|
| FlutterGuard 不取代 Sentry/Crashlytics。它将**运行时行为关联**为结构化追踪。 | Charles 记录请求体。FlutterGuard 只记录**发生了什么** — 方法、路径、状态码、耗时 — 挂接到你的流程上。 | 调试日志是非结构化和临时的。FlutterGuard 产出**可导出、可关联**的报告。 |

FlutterGuard 可以回答这些问题：

- *"为什么这个用户操作花了 2 秒？"* — spans、网络请求、帧
- *"在这个操作的声明周期中，错误发生在哪里？"* — 流程上下文中的错误
- *"这个项目中有哪些文件存在架构风险？"* — 静态扫描
- *"在这次结账流程中发生了级联重建吗？"* — GuardBoundary 计数器

---

## 安装

### 运行时包（Flutter 应用）

```yaml
# pubspec.yaml
dependencies:
  flutterguard_flutter: ^0.1.0
  flutterguard_dio: ^0.1.0   # 如果使用 Dio
```

### CLI（独立工具）

```bash
dart pub global activate flutterguard_cli
# 或编译为原生二进制：
git clone <repo-url>
cd flutterguard
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
```

---

## 快速开始

### 1. 包裹应用

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

### 2. 追踪用户操作

```dart
ElevatedButton(
  onPressed: () {
    FlutterGuard.action('checkout', () async {
      final valid = await FlutterGuard.span('validate_cart', () => validate());
      if (valid) {
        await FlutterGuard.span('process_payment', () => process());
      }
    });
  },
  child: Text('Checkout'),
)
```

### 3. 添加 Dio 拦截器

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(FlutterGuardDioInterceptor());
```

### 4. 标记组件边界

```dart
GuardBoundary(
  name: 'CheckoutPage',
  child: CheckoutView(),
)
```

### 5. 导出报告

```dart
final report = FlutterGuard.exportMarkdown();
print(report);

final json = FlutterGuard.exportJson();
await File('report.json').writeAsString(json);
```

### 6. 运行静态扫描

```bash
flutterguard scan --path ./my_project
```

---

## 运行时 API

### `FlutterGuard.run()`

初始化所有 hooks 并启动 Flutter 应用。必须在 `runApp` 之前调用。

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

创建一个新的流程追踪。`body` 中的所有 spans、网络请求、错误、路由和帧指标会自动关联。

```dart
await FlutterGuard.action('login', () async {
  final token = await auth.login(username, password);
  storage.saveToken(token);
}, tags: {'screen': 'login'});
```

### `FlutterGuard.span<T>(name, body, {tags})`

在当前流程下创建子 span。如果没有活跃流程，则直接执行 body 而不记录。

```dart
final data = await FlutterGuard.span('fetch_user', () => api.getUser(id));
```

### `FlutterGuardRouteObserver`

添加到 `MaterialApp.navigatorObservers`。记录 push、pop、replace、remove 事件。

```dart
MaterialApp(
  navigatorObservers: [FlutterGuard.routeObserver],
)
```

### `GuardBoundary`

包裹任意 widget 以在活跃流程中统计重建次数。

```dart
GuardBoundary(
  name: 'ProductList',
  child: ProductListView(),
)
```

### `FlutterGuard.currentTraceId`

从 Zone 返回当前流程追踪 ID，或 `null`。

```dart
final traceId = FlutterGuard.currentTraceId;
```

### `FlutterGuard.exportJson()` / `FlutterGuard.exportMarkdown()`

导出所有记录的追踪为结构化报告。

```dart
final json = FlutterGuard.exportJson();
final md = FlutterGuard.exportMarkdown();
```

### `FlutterGuard.reset()`

清除所有存储的追踪。

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

默认敏感键：`authorization, cookie, set-cookie, token, password, secret, email, phone`

记录 method、path、status code、duration、success/failure。不记录请求/响应体。

---

## CLI

### `flutterguard scan`

```
flutterguard scan [options]

Options:
  -p, --path      扫描项目路径（默认：.）
  -c, --config    配置文件路径（默认：flutterguard.yaml）
  -f, --format    输出格式：json | markdown | both（默认：both）
  -o, --output    输出目录（默认：.flutterguard）
  --fail-on       CI 门控阈值：none | high | medium | low（默认：none）
  --min-score     最低分数 0-100
```

输出文件：
- `.flutterguard/report.json` — 机器可读
- `.flutterguard/report.md` — 人类可读

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

### CI 集成

**GitHub Actions：**

```yaml
- name: FlutterGuard Scan
  run: |
    dart pub global activate flutterguard_cli
    flutterguard scan --path . --fail-on high
```

**Pre-commit（本地）：**

```bash
#!/bin/bash
flutterguard scan --path . --fail-on medium
```

退出码：`0` = 通过，`1` = 门控失败，`2` = 错误

---

## 静态规则

| 规则 | 等级 | 检测内容 |
|------|------|----------|
| `large_file` | medium | 文件超过 maxLines（默认 500） |
| `large_class` | medium | 类超过 maxLines（默认 300） |
| `large_build_method` | medium | widget 的 build() 方法超过 maxLines（默认 80） |
| `lifecycle_resource_not_disposed` | **high** | StreamSubscription、Timer、AnimationController、TextEditingController、ScrollController、FocusNode 未对应 cancel/dispose |
| `boundary_import_violation` | **high** | 导入违反了配置的模块边界 |

**评分**：100 基础分 — 每 high -10，每 medium -4，每 low -1（最低 0）

---

## 报告格式

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

综合报告，包含以下章节：Summary、Static Issues（High/Medium/Low）、Runtime Flows 和 CI Result。

---

## M1 功能列表

- [x] `FlutterGuard.action()` — 带 Zone 上下文的流程级追踪创建
- [x] `FlutterGuard.span()` — 异步子 spans，自动关联
- [x] `FlutterGuard.run()` — 自动错误 hooks、帧指标、路由观察者
- [x] `FlutterGuardRouteObserver` — 记录 push/pop/replace/remove
- [x] `GuardBoundary` — widget 重建计数
- [x] `FlutterGuardDioInterceptor` — Dio 5.x HTTP 追踪
- [x] CLI 静态扫描 — 5 条规则，YAML 配置，JSON/Markdown 报告
- [x] CI 门控 — `--fail-on` 阈值退出码
- [x] 评分系统 — 基于问题严重性的 0-100 分
- [x] 演示应用 — 集成了所有功能的结账流程

## M1 非目标

- AI 诊断或自动修复
- DevTools 扩展
- MQTT、BLE 或 Matter 协议追踪
- Riverpod/BLoC/GetX 状态管理适配器
- 完整 HTTP 体检查
- 崩溃 SDK 替代品（Sentry/Crashlytics）
- IDE lint 插件集成

---

## 示例输出

运行演示结账流程：

```
# FlutterGuard Report

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

## 路线图

| 里程碑 | 时间 | 重点 |
|--------|------|------|
| **M1** | 当前 | 流程追踪 + 静态扫描 MVP |
| M2 | 2026 Q3 | 类型精确的生命周期检测、循环检测、自定义插件 |
| M3 | 2026 Q4 | DevTools 扩展、Sentry 桥接、时间线集成 |
| M4 | 2027 | 企业功能、多 isolate、存储后端 |

---

## 开发

```bash
# 克隆和引导
git clone <repo-url>
cd flutterguard
melos bootstrap

# 分析所有包
melos run analyze

# 运行测试
dart test packages/flutterguard_core
dart test packages/flutterguard_dio
dart test packages/flutterguard_cli
flutter test packages/flutterguard_flutter

# 运行追踪 API 演示
dart run examples/usage_demo/bin/trace_demo.dart

# 扫描示例项目
dart pub global activate --source path packages/flutterguard_cli
flutterguard scan --path examples/scan_demo
```

---

## 许可

MIT
