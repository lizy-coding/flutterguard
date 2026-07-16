# FlutterGuard — Complete Usage Guide

> 版本: 0.6.0 | 支持: macOS / Windows / Linux | Dart SDK >=3.11.5

---

## 目录

1. [安装](#1-安装)
2. [快速开始](#2-快速开始)
3. [CLI 命令参考](#3-cli-命令参考)
4. [配置文件](#4-配置文件)
5. [规则详解](#5-规则详解)
6. [评分系统](#6-评分系统)
7. [输出格式](#7-输出格式)
8. [CI 集成](#8-ci-集成)
9. [路径处理说明](#9-路径处理说明)
10. [常见问题](#10-常见问题)
11. [开发指南](#11-开发指南)

配置策略总览见 [CONFIGURATION_STRATEGY.md](../CONFIGURATION_STRATEGY.md)：CLI 输出只放即时下一步，完整命令与配置心智模型放在专门说明文档中。

---

## 1. 安装

### 1.1 前置条件

| 组件 | 最低版本 | 安装方式 |
|------|---------|---------|
| Dart SDK | 3.11.5+ | [dart.dev/get-dart](https://dart.dev/get-dart) |
| Git | 任意 | 用于克隆仓库 |

### 1.2 全局命令安装（推荐）

<details open>
<summary><b>macOS / Linux</b></summary>

```bash
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard

dart pub get
dart pub global activate melos
melos bootstrap

dart pub global activate --source path packages/flutterguard_cli
flutterguard --help
```

确认 `$HOME/.pub-cache/bin` 已在 `PATH` 中：

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"   # 添加到 ~/.zshrc 或 ~/.bashrc
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard

dart pub get
dart pub global activate melos
melos bootstrap

dart pub global activate --source path packages\flutterguard_cli
flutterguard --help
```

确认 `%USERPROFILE%\AppData\Local\Pub\Cache\bin` 已在 `PATH` 中（Dart 安装器默认添加）。

若 `flutterguard` 命令未识别，检查并手动添加：

```powershell
$env:Path += ";$env:USERPROFILE\AppData\Local\Pub\Cache\bin"
```
</details>

### 1.3 编译独立二进制

<details open>
<summary><b>macOS / Linux</b></summary>

```bash
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
./flutterguard --help
```
</details>

<details>
<summary><b>Windows</b></summary>

```powershell
dart compile exe packages\flutterguard_cli\bin\flutterguard.dart -o flutterguard.exe
.\flutterguard.exe --help
```
</details>

### 1.4 验证安装

```bash
flutterguard --version    # 输出: flutterguard 0.6.0
flutterguard --help       # 输出帮助信息
```

---

## 2. 快速开始

### 扫描一个项目

```bash
# macOS / Linux
flutterguard scan -p /path/to/flutter_project

# Windows
flutterguard scan -p D:\dev\my_flutter_app

# 扫描当前目录
flutterguard scan -p .
```

### 扫描示例项目

```bash
flutterguard scan -p examples/scan_demo
```

### CI 门禁模式

```bash
# JSON 输出 + HIGH 级别失败
flutterguard scan -p . --format json --fail-on high

# 最低分 80 分
flutterguard scan -p . --format json --min-score 80
```

---

## 3. CLI 命令参考

### 3.1 命令结构

```
flutterguard <command> [options]

Commands:
  scan      Scan a Flutter project for architecture issues
  --help    Show usage
  --version Show version
```

### 3.2 scan 命令参数

| 参数 | 简写 | 类型 | 默认值 | 说明 |
|------|------|------|--------|------|
| `--path` | `-p` | path | `.` | 要扫描的项目路径 |
| `--config` | `-c` | path | `flutterguard.yaml` | 配置文件路径（相对于项目根目录） |
| `--format` | `-f` | `table` \| `json` | `table` | 输出格式 |
| `--output` | `-o` | path | `.flutterguard` | JSON 报告输出目录 |
| `--verbose` | `-v` | flag | off | 显示详细代码上下文 |
| `--fail-on` | — | `none` \| `high` \| `medium` \| `low` | `none` | CI 门禁等级 |
| `--min-score` | — | int (0-100) | unset | 最低可接受评分 |
| `--help` | `-h` | flag | — | 显示 scan 帮助 |

### 3.3 退出码

| 退出码 | 含义 |
|--------|------|
| `0` | 成功完成（含 help/version 及增量扫描没有相关变更） |
| `1` | CI 门禁失败（存在超过 `--fail-on` 的问题或评分低于 `--min-score`） |
| `2` | 扫描设置错误（路径不存在、显式配置缺失、配置无效或未匹配到配置范围内的 Dart 文件） |

### 3.4 使用示例

```bash
# 基础扫描
flutterguard scan -p ./my_app

# 指定配置文件
flutterguard scan -p . -c my_config.yaml

# JSON 输出到指定目录
flutterguard scan -p . --format json -o reports

# 详细输出模式
flutterguard scan -p . -v

# CI 门禁：存在 HIGH 级别问题即失败
flutterguard scan -p . --fail-on high

# CI 门禁：存在任何问题即失败
flutterguard scan -p . --fail-on low

# 综合门禁：HIGH 且评分低于 80 失败
flutterguard scan -p . --fail-on high --min-score 80

# Windows 示例
flutterguard scan -p D:\dev\flutter_app -c config\flutterguard.yaml
flutterguard scan -p . --format json --fail-on medium --min-score 60
```

---

## 4. 配置文件

### 4.1 配置位置

FlutterGuard 按以下优先级加载配置：

1. 命令行 `--config` 指定的文件路径（最高优先级）
2. 项目根目录下的 `flutterguard.yaml`
3. 内置默认配置（无配置文件时使用）

### 4.2 完整配置示例

```yaml
# ========== 文件收集 ==========
include:
  - lib/**
  - test/**

exclude:
  - lib/generated/**
  - lib/**.g.dart
  - lib/**.freezed.dart
  - lib/**.mocks.dart

# ========== 规则开关与阈值 ==========
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

  side_effect_in_build:
    enabled: true
    severity: high
    allowlist: []
    ignore_paths: []

  riverpod_read_used_for_render:
    enabled: true
    severity: medium

# ========== 状态管理规则总开关 ==========
state_management:
  enabled: true
  framework_auto_detect: true
  confidence_threshold: certain

# ========== 架构约束 ==========
architecture:
  # 层间依赖约束
  layers:
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

  # 业务模块隔离
  modules:
    - name: device_mqtt
      path: lib/device/mqtt/**
      allowed_deps: [domain, core]

    - name: device_ble
      path: lib/device/ble/**
      allowed_deps: [domain, core]

  # 循环依赖检测
  detect_cycles: true

  # 规则开关
  layer_violation:
    enabled: true
  module_violation:
    enabled: true
```

### 4.3 配置项说明

#### include / exclude

| 字段 | 类型 | 说明 |
|------|------|------|
| `include` | `List<String>` | glob 模式，指定要扫描的文件。默认 `['lib/**']` |
| `exclude` | `List<String>` | glob 模式，排除匹配的文件。默认排除 generated/freezed/mocks |

#### rules.*.enabled

每个规则有独立的 `enabled` 开关。设为 `false` 可禁用该规则。

#### rules.*.maxLines

阈值类规则（large_file / large_class / large_build_method）支持 `maxLines` 自定义。超过该值即报告问题。

#### state_management 与状态规则

- `state_management.enabled`: 10 条状态管理规则的总开关，默认 `true`
- `framework_auto_detect`: 默认根据 Riverpod/Bloc/Provider import 与 AST 形态共同识别；设为 `false` 时只跳过 import 门槛
- `confidence_threshold`: `certain` / `probable` / `informational`；当前规则均为 `certain`
- 每条状态规则支持 `enabled`、`severity`、`allowlist`、`ignore_paths`
- `severity` 映射 high→P0、medium→P1、low→P2，并影响评分与 CI gate
- `ignore_paths` 使用项目相对 POSIX glob；依赖环 allowlist 边使用 `Source->Target`

#### architecture.layers

- `name`: 层名称（任意字符串）
- `path`: glob 模式，匹配该层的文件
- `allowed_deps`: 该层允许依赖的其他层名称列表

**重要**: 层规则需要显式声明所有层。未声明的文件不在任何层内，不受检查。

#### architecture.modules

- 结构与 layers 完全相同
- `name`: 模块名称
- `path`: 模块文件匹配模式
- `allowed_deps`: 允许依赖的模块列表

#### architecture.detect_cycles

- 类型: `bool`
- 默认: `false`（默认配置）/ `true`（推荐）
- 启用文件级循环依赖检测

#### architecture.layer_violation.enabled / module_violation.enabled

- 类型: `bool`
- 默认: `true`
- 全局开关，即使配置了 layers/modules 也可临时关闭

### 4.4 默认配置（无 flutterguard.yaml 时）

```yaml
include:  [lib/**]
exclude:  [lib/generated/**, lib/**.g.dart, lib/**.freezed.dart, lib/**.mocks.dart]

rules:
  large_file:                { enabled: true, maxLines: 500 }
  large_class:               { enabled: true, maxLines: 300 }
  large_build_method:        { enabled: true, maxLines: 80  }
  lifecycle_resource:        { enabled: true }
  missing_const_constructor: { enabled: true }
  device_lifecycle:          { enabled: true }
  mqtt_connection:           { enabled: true }
  ble_scanning:              { enabled: true, maxScanDurationMs: 10000 }
  iot_security:              { enabled: true, requireTls: true }
  pubspec_security:          { enabled: true }
  side_effect_in_build:      { enabled: true, severity: high }
  state_manager_created_in_build: { enabled: true, severity: high }
  mutable_state_exposed:     { enabled: true, severity: medium }
  state_layer_ui_dependency: { enabled: true, severity: high }
  state_dependency_cycle:    { enabled: true, severity: high }
  riverpod_read_used_for_render: { enabled: true, severity: medium }
  riverpod_watch_in_callback: { enabled: true, severity: medium }
  bloc_equatable_props_incomplete: { enabled: true, severity: medium }
  provider_value_lifecycle_misuse: { enabled: true, severity: medium }
  notify_listeners_in_loop:  { enabled: true, severity: medium }

state_management:
  enabled: true
  framework_auto_detect: true
  confidence_threshold: certain

architecture:
  layers: []              # 未配置层，不执行层规则
  modules: []             # 未配置模块，不执行模块规则
  detect_cycles: false
  layer_violation:  { enabled: true }
  module_violation: { enabled: true }
```

---

## 5. 规则详解

### 5.1 large_file — 文件过大

| 属性 | 值 |
|------|----|
| **ID** | `large_file` |
| **风险等级** | LOW |
| **领域** | standards（代码规范） |
| **优先级** | P2 |
| **可配置** | `enabled`, `maxLines` |
| **检测方式** | 读取文件行数，超过 `maxLines`（默认 500）报告问题 |

### 5.2 large_class — 类过大

| 属性 | 值 |
|------|----|
| **ID** | `large_class` |
| **风险等级** | LOW |
| **领域** | standards（代码规范） |
| **优先级** | P2 |
| **可配置** | `enabled`, `maxLines` |
| **检测方式** | 找到 `class ClassName` 声明，计算类体行数，超过 `maxLines`（默认 300）报告 |

### 5.3 large_build_method — Build 方法过大

| 属性 | 值 |
|------|----|
| **ID** | `large_build_method` |
| **风险等级** | MEDIUM |
| **领域** | performance（性能） |
| **优先级** | P1 |
| **可配置** | `enabled`, `maxLines` |
| **检测方式** | 找到 `Widget build(BuildContext)` 方法，计算行数，超过 `maxLines`（默认 80）报告 |

### 5.4 lifecycle_resource_not_disposed — 资源未释放

| 属性 | 值 |
|------|----|
| **ID** | `lifecycle_resource_not_disposed` |
| **风险等级** | MEDIUM |
| **领域** | performance（性能） |
| **优先级** | P1 |
| **可配置** | `enabled` |

**检测的资源类型**：

| 类型 | 期望释放方法 | IoT 相关 |
|------|-------------|---------|
| `StreamSubscription` | `.cancel()` | |
| `Timer` | `.cancel()` | |
| `AnimationController` | `.dispose()` | |
| `TextEditingController` | `.dispose()` | |
| `ScrollController` | `.dispose()` | |
| `FocusNode` | `.dispose()` | |
| `MqttClient` | `.disconnect()` | ✅ IoT |
| `BluetoothDevice` | `.disconnect()` | ✅ IoT |
| `StreamController` | `.close()` | |

**检测方式**: 对每个类，检查字段声明 → 类型匹配 → 是否在 `dispose()` 方法中调用了对应的释放方法。

### 5.5 layer_violation — 层间依赖违规

| 属性 | 值 |
|------|----|
| **ID** | `layer_violation` |
| **风险等级** | HIGH |
| **领域** | architecture（架构） |
| **优先级** | P0 |
| **可配置** | `architecture.layer_violation.enabled`, `architecture.layers` |

**示例**：`presentation` 层允许依赖 `[domain, core]`。如果 `presentation` 层中的文件 import 了 `data` 层文件，报告违规。

### 5.6 module_violation — 模块依赖违规

| 属性 | 值 |
|------|----|
| **ID** | `module_violation` |
| **风险等级** | HIGH |
| **领域** | architecture（架构） |
| **优先级** | P0 |
| **可配置** | `architecture.module_violation.enabled`, `architecture.modules` |

**与 layer_violation 的区别**: module 用于业务模块隔离（如 device_mqtt 不应依赖 device_ble），layer 用于架构分层约束。

### 5.7 circular_dependency — 循环依赖

| 属性 | 值 |
|------|----|
| **ID** | `circular_dependency` |
| **风险等级** | MEDIUM |
| **领域** | architecture（架构） |
| **优先级** | P1 |
| **可配置** | `architecture.detect_cycles` |

**检测方式**: 构建有向图 → DFS 染色检测环 → 每个文件级环报告一次。

### 5.8 missing_const_constructor — 缺少 const 构造函数

| 属性 | 值 |
|------|----|
| **ID** | `missing_const_constructor` |
| **风险等级** | LOW |
| **领域** | standards（代码规范） |
| **优先级** | P2 |
| **可配置** | `enabled` |

**检测方式**: 找到 `StatelessWidget` / `StatefulWidget` 子类 → 检查是否有 `const` 构造函数。

---

### 5.9 状态管理可维护性规则（10 条）

| ID | 默认等级 | 框架 | True positive | Safe pattern |
|----|----------|------|---------------|--------------|
| `side_effect_in_build` | HIGH | generic | build 中 `emit()`、`notifyListeners()`、连接设备或 notifier 命令 | 事件回调或 listener 内执行 |
| `state_manager_created_in_build` | HIGH | generic | build 中 `DeviceController()` | State 字段或 Provider `create` 持有 |
| `mutable_state_exposed` | MEDIUM | generic | public 可变字段/集合 getter、`state.items.add` | unmodifiable view、copyWith |
| `state_layer_ui_dependency` | HIGH | generic | Controller 参数为 BuildContext 或调用 Navigator | 状态层输出事件，Widget 执行 UI 行为 |
| `state_dependency_cycle` | HIGH | generic | Provider/Controller/Service 形成 SCC | 单向接口或协调器 |
| `riverpod_read_used_for_render` | MEDIUM | Riverpod | `Text(ref.read(p).name)` | 渲染用 `ref.watch`，命令用 `ref.read` |
| `riverpod_watch_in_callback` | MEDIUM | Riverpod | `onTap: () => ref.watch(p)` | 回调使用 `ref.read` |
| `bloc_equatable_props_incomplete` | MEDIUM | Bloc | final 字段未加入 `props` | 所有值字段均在 `props` |
| `provider_value_lifecycle_misuse` | MEDIUM | Provider | `.value(value: Controller())` / `create: (_) => existing` | 新实例用 create，已有实例用 .value |
| `notify_listeners_in_loop` | MEDIUM | Provider | for/while/forEach 内通知 | 批量修改后统一通知一次 |

显式行级抑制继续使用现有注释：

```dart
// flutterguard: ignore side_effect_in_build
Widget build(BuildContext context) {
  ref.read(deviceProvider.notifier).refresh();
  return const DeviceView();
}
```

## 6. 评分系统

### 6.1 计算公式

```
score = max(0, 100 - HIGH×10 - MEDIUM×4 - LOW×1)
```

| 问题等级 | 扣分 |
|---------|------|
| HIGH | -10 |
| MEDIUM | -4 |
| LOW | -1 |

### 6.2 评分等级

| 分数段 | 等级 | 含义 |
|--------|------|------|
| 80-100 | 优秀 | 代码质量良好 |
| 50-79 | 需关注 | 存在一定问题，建议处理 |
| 0-49 | 需整改 | 存在较多严重问题，需要立即处理 |

---

## 7. 输出格式

### 7.1 Table 格式（默认）

终端输出，按领域分组显示。示例：

```
 FlutterGuard Report  ─  my_flutter_app
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 总评分:  88/100  优秀            扫描文件: 15  问题总数: 3
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  架构违规  1 items  ▰  HIGH
─────────────────────────────────────────────────────────────────

  HIGH P0 优先
       层间依赖违规
       lib/presentation/home_page.dart:42
       presentation 层不可依赖 data 层
       修复: 将导入的内容移至 domain 或 core层
```

### 7.2 JSON 格式

`--format json` 输出到 stdout（摘要）和 `--output` 目录下 `report.json`。

```json
{
  "version": "1.0.0",
  "generatedAt": "2026-06-09T12:00:00.000Z",
  "projectPath": "/Users/dev/my_flutter_app",
  "score": 88,
  "summary": {
    "total": 3,
    "high": 1,
    "medium": 1,
    "low": 1,
    "byDomain": {
      "architecture": { "high": 1, "medium": 1, "low": 0, "total": 2 },
      "performance": { "high": 0, "medium": 0, "low": 0, "total": 0 },
      "standards":   { "high": 0, "medium": 0, "low": 1, "total": 1 }
    }
  },
  "issues": [
    {
      "id": "layer_violation",
      "title": "层间依赖违规",
      "file": "/Users/dev/my_flutter_app/lib/presentation/home_page.dart",
      "line": 42,
      "level": "high",
      "domain": "architecture",
      "priority": "p0",
      "message": "presentation 层不可依赖 data 层",
      "detail": "导入: package:app/data/repo.dart\n源层: presentation (lib/presentation/**)\n目标层: data (lib/data/**)\n允许依赖: domain, core",
      "suggestion": "将导入的内容移至 domain 或 core层",
      "metadata": {
        "sourceLayer": "presentation",
        "targetLayer": "data",
        "imported": "package:app/data/repo.dart",
        "allowedDeps": ["domain", "core"]
      }
    }
  ]
}
```

### 7.3 输出路径

| 平台 | CLI --output 默认值 | 实际输出路径 |
|------|-------------------|-------------|
| macOS | `.flutterguard` | `/Users/xxx/project/.flutterguard/report.json` |
| Windows | `.flutterguard` | `D:\xxx\project\.flutterguard\report.json` |

---

## 8. CI 集成

### 8.1 GitHub Actions

```yaml
name: FlutterGuard

on: [push, pull_request]

jobs:
  scan:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: 3.11.5
      - name: Install FlutterGuard
        run: dart pub global activate flutterguard_cli
      - name: Scan
        run: flutterguard scan -p . --format json --fail-on high --min-score 80
```

### 8.2 GitLab CI

```yaml
flutterguard:
  image: dart:3.11.5
  script:
    - dart pub global activate flutterguard_cli
    - flutterguard scan -p . --format json --fail-on high --min-score 80
  artifacts:
    paths:
      - .flutterguard/report.json
    when: always
```

### 8.3 预提交钩子 (pre-commit)

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: flutterguard
        name: FlutterGuard scan
        entry: flutterguard scan -p . --fail-on high
        language: system
        pass_filenames: false
        always_run: true
```

### 8.4 Windows 本地 CI 脚本

```powershell
# tools\scan_ci.ps1
$ErrorActionPreference = "Stop"

Write-Host "FlutterGuard Scan" -ForegroundColor Cyan
flutterguard scan -p . --format json --fail-on high --min-score 80

if ($LASTEXITCODE -eq 0) {
    Write-Host "Passed!" -ForegroundColor Green
} else {
    Write-Host "Failed! Check .flutterguard/report.json for details." -ForegroundColor Red
    exit 1
}
```

---

## 9. 路径处理说明

### 9.1 跨平台策略

FlutterGuard 所有路径操作均通过 `package:path` 的 Context 系统完成，自动适配不同平台的路径分隔符。

| 场景 | macOS | Windows | 处理方式 |
|------|-------|---------|---------|
| 内部路径操作 | `/` | `\` | `p.Context(style: p.Style.posix/windows)` |
| glob 模式匹配 | `/` | `/` | `replaceAll('\\', '/')` 归一化 |
| import 解析 | `/` | `\` → `/` | Context.normalize |
| 配置文件 glob | `lib/**` | `lib/**` | 统一正斜杠 |

### 9.2 glob 模式约定

无论什么平台，YAML 配置中的 glob 模式均使用**正斜杠** `/`：

```yaml
# 正确
path: lib/presentation/**

# 错误（Windows 也不要使用反斜杠）
path: lib\presentation\**
```

### 9.3 方法级 Context 参数

以下公共 API 支持传入 `p.Context` 以适配特定平台：

| 方法 | Context 参数 |
|------|-------------|
| `projectPathContext()` | `context` |
| `normalizePath()` | `context`, `basePath` |
| `matchesProjectGlob()` | `context` |
| `projectRelativePath()` | `context` |
| `resolveImport()` | `context` |

---

## 10. 常见问题

### Q: 未找到配置文件怎么办？

自动使用内置默认配置（所有规则启用，无架构约束）。可通过 `-c` 参数显式指定。

### Q: 如何忽略生成的代码？

默认已经排除了 `lib/generated/**`, `lib/**.g.dart`, `lib/**.freezed.dart`, `lib/**.mocks.dart`。可在 `flutterguard.yaml` 的 `exclude` 中添加更多模式。

### Q: 架构规则未生效？

检查以下几点：
1. `architecture.layers` / `architecture.modules` 是否已声明
2. `architecture.layer_violation.enabled` / `module_violation.enabled` 是否为 `true`
3. glob 模式是否匹配目标文件（使用正斜杠）

### Q: Windows 终端输出乱码？

```powershell
# PowerShell 设置 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 推荐使用 Windows Terminal（Windows 10/11 自带）
```

### Q: Windows 下颜色不显示？

旧 cmd.exe 不支持 ANSI 转义码，使用 Windows Terminal 即可。颜色仅影响外观，不影响功能。

### Q: 如何生成原生可执行文件并分发？

```bash
# macOS
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard

# Windows
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard.exe
```

编译产物可独立运行，无需 Dart 环境。

---

## 11. 开发指南

### 11.1 环境准备

```bash
# macOS / Linux
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub get
dart pub global activate melos
melos bootstrap

# Windows
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub get
dart pub global activate melos
melos bootstrap
```

### 11.2 常用命令

| 命令 | 说明 |
|------|------|
| `dart run melos run analyze` | 静态分析 |
| `dart run melos run test:cli` | 运行 CLI 测试（26 个测试） |
| `dart run flutterguard scan -p examples/scan_demo` | 扫描示例项目 |
| `dart compile exe ...` | 编译原生二进制 |

### 11.3 测试结构

```
packages/flutterguard_cli/test/
├── scanner_test.dart          # 26 个测试
└── fixtures/                  # 规则与配置 fixture
    ├── large_file.dart
    ├── large_class.dart
    ├── large_build.dart
    ├── lifecycle_issue.dart
    ├── boundary_issue.dart
    ├── forbidden_file.dart
    ├── cycle_a.dart
    ├── cycle_b.dart
    ├── cycle_c.dart
    ├── missing_const.dart
    ├── architecture_config.yaml
    └── architecture_disabled.yaml
```

### 11.4 添加新规则

1. 在 `docs/FLUTTERGUARD_SPEC.md` 添加规则规格
2. 在 `config_loader.dart` 添加类型定义（如需要新配置字段）
3. 在 `lib/src/rules/` 实现规则类
4. 在 `test/fixtures/` 添加测试 fixture
5. 在 `test/scanner_test.dart` 添加测试
6. 在 `scanner.dart:_analyze()` 中注册规则
7. 在 `bin/flutterguard.dart` 的 help 文本中更新说明
8. 运行 `melos run analyze && melos run test:cli`
