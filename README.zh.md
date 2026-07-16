# FlutterGuard

> 面向 IoT / 智能家居 Flutter 项目的静态架构扫描 CLI，用于架构约束、代码质量检查和 CI 门禁。

[English](README.md) | [中文](README.zh.md)

FlutterGuard 扫描 Flutter/Dart 源码，报告架构边界违规、生命周期资源泄漏、循环依赖、过大文件/类/`build` 方法，以及常见代码规范问题。当前活动开发路径是 `packages/flutterguard_cli/`；旧的运行时追踪包已归档在 `archive/`。

**支持平台**: macOS、Windows、Linux — 纯 Dart CLI，零原生依赖。

**文档**: [使用指南](docs/USAGE.md) | [配置策略](CONFIGURATION_STRATEGY.md) | [Windows 评估](docs/WINDOWS_ASSESSMENT.md) | [技术规格](docs/FLUTTERGUARD_SPEC.md) | [架构](docs/ARCHITECTURE.md)

## 它是什么

- 静态分析命令行工具
- 基于 YAML 配置的架构约束工具
- 面向 IoT / 智能家居 Flutter 项目的规则集
- 可按严重等级或评分失败的 CI 门禁

## 它不是什么

- 不是运行时观测 SDK 或 APM
- 不是 Crashlytics / Sentry 替代品
- 不是 HTTP 抓包、日志库或云端 SaaS
- 不需要 API key，也不会上传 APK

## 环境要求

- Dart SDK 3.11.5 或更高版本
- 从源码开发时需要 `melos`
- 支持操作系统: macOS、Windows、Linux

---

## 安装

### 方式 A：pub.dev 安装（推荐）

<details open>
<summary><b>macOS / Linux</b></summary>

```bash
dart pub global activate flutterguard_cli

# 验证安装
flutterguard --version
```

确认 `$HOME/.pub-cache/bin` 在 `PATH` 中：

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"   # 添加到 ~/.zshrc 或 ~/.bashrc
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
dart pub global activate flutterguard_cli

# 验证安装
flutterguard --version
```

若 `flutterguard` 命令未识别，确认 `%USERPROFILE%\AppData\Local\Pub\Cache\bin` 在 `PATH` 中：

```powershell
$env:Path += ";$env:USERPROFILE\AppData\Local\Pub\Cache\bin"
```
</details>

### 方式 B：GitHub Release 二进制（运行时无需 Dart 环境）

从 GitHub Releases 下载对应平台的二进制后直接运行：

<details open>
<summary><b>macOS / Linux</b></summary>

```bash
chmod +x flutterguard
./flutterguard --version
./flutterguard scan .
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
.\flutterguard.exe --version
.\flutterguard.exe scan .
```
</details>

### 方式 C：源码开发运行

如果你希望直接运行当前 checkout 的源码，不替换全局 `flutterguard`
命令，使用本地 launcher。

<details>
<summary><b>macOS / Linux</b></summary>

```bash
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub get
./scripts/flutterguard-dev --version
./scripts/flutterguard-dev scan .
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub get
.\scripts\flutterguard-dev.ps1 --version
.\scripts\flutterguard-dev.ps1 scan .
```
</details>

---

## 快速开始

```bash
# 扫描当前目录
flutterguard scan

# 创建并检查基础配置
flutterguard init --profile migration
flutterguard config doctor
flutterguard doctor install

# 查看合并后的有效配置
flutterguard config print

# 扫描指定项目
flutterguard scan ./my_flutter_app          # macOS / Linux
flutterguard scan .\my_flutter_app          # Windows

# 使用 --path 标志
flutterguard scan -p /path/to/project       # macOS / Linux
flutterguard scan -p D:\path\to\project     # Windows

# JSON 输出 + CI 门禁
flutterguard scan . --format json --fail-on high

# 启用强门禁前先为历史问题创建 baseline
flutterguard baseline create .
flutterguard baseline stats
flutterguard baseline check . --baseline .flutterguard/baseline.json --no-growth
flutterguard scan . --baseline .flutterguard/baseline.json --fail-on high

# GitHub Code Scanning 输出
flutterguard scan . --format sarif --baseline .flutterguard/baseline.json

# 导出单个问题用于误报反馈
flutterguard issue export --rule mqtt_connection --file lib/device/mqtt.dart --line 42

# 显示帮助
flutterguard --help
flutterguard scan --help
```

### 扫描示例项目

```bash
flutterguard scan examples/scan_demo
```

---

## CLI 参考

命令：

| 命令 | 说明 |
|------|------|
| `flutterguard scan [<path>]` | 扫描项目（路径默认为当前目录） |
| `flutterguard baseline create [<path>]` | 为现有问题创建 baseline JSON 文件 |
| `flutterguard baseline stats` | 查看 baseline fingerprint 数量 |
| `flutterguard baseline prune [<path>]` | 从 baseline 移除已修复问题 |
| `flutterguard baseline check [<path>] --no-growth` | 当前问题未进入 baseline 时失败 |
| `flutterguard doctor install` | 检查可执行文件版本和 PATH 冲突 |
| `flutterguard init` | 创建基础 `flutterguard.yaml` |
| `flutterguard init --profile migration` | 使用 profile 创建基础配置 |
| `flutterguard init --with-architecture` | 创建包含架构层/模块模板的配置 |
| `flutterguard config print` | 输出合并后的有效配置 |
| `flutterguard config doctor` | 检查配置、glob 和架构引用 |
| `flutterguard issue export` | 导出单个问题为本地反馈 JSON |
| `flutterguard rules` | 列出所有可用规则 |
| `flutterguard explain <rule-id>` | 查看单条规则说明 |
| `flutterguard --help` / `-h` | 显示帮助 |
| `flutterguard --version` / `-V` | 显示版本 |

### 扫描参数

| 参数 | 简写 | 默认值 | 说明 |
|------|------|--------|------|
| `<path>` | — | `.` | 位置参数，项目路径（可选，放在选项之前） |
| `--path` | `-p` | `.` | 项目路径（被 `<path>` 位置参数覆盖） |
| `--config` | `-c` | `flutterguard.yaml` | 配置文件路径 |
| `--format` | `-f` | `table` | 输出格式：`table`、`json` 或 `sarif` |
| `--output` | `-o` | `.flutterguard` | 报告输出目录 |
| `--verbose` | `-v` | 关闭 | 显示详细代码上下文 |
| `--no-color` | — | 关闭 | 禁用 ANSI 终端颜色 |
| `--changed-only` | — | 关闭 | 只扫描相对 `--base` 变更的 Dart 文件 |
| `--base` | — | `main` | `--changed-only` 使用的 Git base ref |
| `--baseline` | — | 不设 | 用于隐藏历史问题的 baseline JSON 文件 |
| `--fail-on` | — | `none` | CI 门禁等级：`none` / `high` / `medium` / `low` |
| `--min-score` | — | 不设 | 最低可接受评分，0–100 |
| `--help` | `-h` | — | 显示 scan 帮助 |

### 退出码

| 退出码 | 含义 |
|--------|------|
| `0` | 成功，包含 help/version 以及增量扫描没有相关变更的情况 |
| `1` | CI 门禁失败（存在超过 `--fail-on` 的问题，或评分低于 `--min-score`）|
| `2` | 扫描设置错误（路径不存在、显式配置缺失、配置无效或未匹配到配置范围内的 Dart 文件） |

### 路径解析

FlutterGuard 从当前目录向上遍历，自动发现项目根目录（查找 `flutterguard.yaml`、`pubspec.yaml` 或 `lib/` 目录）。若未找到，则退化为当前目录。

`--config` 路径始终针对目标项目解析：
1. 绝对路径直接使用，且文件必须存在。
2. 相对路径从目标项目根目录解析，不再读取 CWD 下的同名文件。
3. 未显式指定且默认 `flutterguard.yaml` 不存在时使用内置默认值；任何显式选择的配置都必须存在。

---

## 配置文件

在项目根目录创建 `flutterguard.yaml`。

推荐策略：

1. 先零配置运行：`flutterguard scan`。
2. 需要自定义阈值或排除文件时，运行 `flutterguard init`。
3. 使用 `flutterguard config print` 查看合并后的默认值。
4. 启用 CI 门禁前先运行 `flutterguard config doctor`。
5. 只有项目边界已经明确时，再添加 architecture layers/modules。

完整决策模型见 [配置策略](CONFIGURATION_STRATEGY.md)。

### 基础配置（大多数用户适用）

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
  device_lifecycle:
    enabled: true
  mqtt_connection:
    enabled: true
  ble_scanning:
    enabled: true
    maxScanDurationMs: 10000
  iot_security:
    enabled: true
    requireTls: true
  pubspec_security:
    enabled: true
  side_effect_in_build:
    enabled: true
    severity: high
    allowlist: []
    ignore_paths: []
  riverpod_read_used_for_render:
    enabled: true
    severity: medium

state_management:
  enabled: true
  framework_auto_detect: true
  confidence_threshold: certain
```

10 条状态管理规则均支持 `enabled`、`severity`、`allowlist` 和项目相对 POSIX
`ignore_paths`。以上只展示共享结构；`flutterguard config print` 会输出所有规则的完整生效配置。

### 完整配置（含架构约束）

```yaml
# ... include/exclude/rules 同基础配置 ...

architecture:
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

  modules:
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

> **注意**: 架构规则（`layer_violation`、`module_violation`、`circular_dependency`）需要在配置中**显式声明** `architecture.layers`、`architecture.modules` 和/或 `architecture.detect_cycles`。它们不会自动发现项目边界。

> **Glob 模式约定**: 无论在什么平台上，YAML 配置中的 glob 模式均使用正斜杠 `/`。切勿使用反斜杠。

---

## 检测规则

| 规则 ID | 等级 | 领域 | 优先级 | 检测内容 | 配置要求 |
|---------|------|------|--------|----------|----------|
| `large_file` | LOW | standards | P2 | 文件行数超过 `maxLines` | — |
| `large_class` | LOW | standards | P2 | 类体行数超过 `maxLines` | — |
| `large_build_method` | MEDIUM | performance | P1 | `build()` 方法行数超过 `maxLines` | — |
| `lifecycle_resource_not_disposed` | MEDIUM | performance | P1 | 未释放的 StreamSubscription、Timer、AnimationController、TextEditingController、ScrollController、FocusNode、MqttClient、BluetoothDevice、StreamController | — |
| `missing_const_constructor` | LOW | standards | P2 | Widget 类缺少 `const` 构造函数 | — |
| `layer_violation` | HIGH | architecture | P0 | 跨架构层的依赖违规 | `architecture.layers` * |
| `module_violation` | HIGH | architecture | P0 | 跨业务模块的依赖违规 | `architecture.modules` * |
| `circular_dependency` | MEDIUM | architecture | P1 | 文件级循环依赖 | `architecture.detect_cycles` * |
| `device_lifecycle` | HIGH | architecture | P0 | 不平衡的 init/teardown 配对（initState↔dispose、connect↔disconnect 等） | — |
| `mqtt_connection` | HIGH | architecture | P0 | MQTT connect/disconnect 配对、硬编码 broker URL | — |
| `iot_security` | HIGH | architecture | P0 | 硬编码凭证、明文 MQTT/HTTP、不安全 BLE | `rules.iot_security.requireTls` |
| `ble_scanning` | MEDIUM | architecture | P1 | BLE startScan/stopScan 配对、扫描超时 | `rules.ble_scanning.maxScanDurationMs` |
| `pubspec_security` | MEDIUM | standards | P2 | 无界依赖、已废弃包、过旧 IoT 依赖版本 | — |
| `side_effect_in_build` | HIGH | performance | P0 | build 阶段执行状态或资源副作用 | — |
| `state_manager_created_in_build` | HIGH | performance | P0 | build 中创建 Controller/Bloc/Notifier | — |
| `mutable_state_exposed` | MEDIUM | architecture | P1 | 公开可变状态或原地修改 state 集合 | — |
| `state_layer_ui_dependency` | HIGH | architecture | P0 | 状态 owner 依赖 BuildContext、Widget、导航或主题 API | — |
| `state_dependency_cycle` | HIGH | architecture | P0 | Provider、状态 owner 与可达 service 之间的依赖环 | — |
| `riverpod_read_used_for_render` | MEDIUM | performance | P1 | `ref.read` 的值进入渲染输出 | Riverpod import * |
| `riverpod_watch_in_callback` | MEDIUM | performance | P1 | 事件或异步回调内调用 `ref.watch` | Riverpod import * |
| `bloc_equatable_props_incomplete` | MEDIUM | standards | P1 | Equatable final 字段遗漏于 `props` | Bloc + Equatable import * |
| `provider_value_lifecycle_misuse` | MEDIUM | performance | P1 | Provider `.value`/`create` 所有权模式反用 | Provider/Bloc import * |
| `notify_listeners_in_loop` | MEDIUM | performance | P1 | 重复循环内调用 `notifyListeners()` | Provider/Bloc import * |

<sub>* 架构项需显式 YAML；框架 import 默认自动识别，可设置 `state_management.framework_auto_detect: false` 改用纯 AST 形态匹配。</sub>

---

## 输出

### 终端表格（默认）

按领域分组的彩色终端报告，显示总评分、文件数、问题数及每个问题的详情。

### JSON 报告

`--format json` 将报告写入 `--output` 目录下的 `report.json`。

示例结构：

```json
{
  "version": "1.0.0",
  "generatedAt": "2026-06-09T12:00:00.000Z",
  "projectPath": "/path/to/project",
  "score": 85,
  "summary": {
    "total": 3,
    "high": 1,
    "medium": 1,
    "low": 1,
    "suppressed": 0,
    "suppressedByBaseline": 0,
    "byDomain": {
      "architecture": { "high": 1, "medium": 0, "low": 0, "total": 1 }
    }
  },
  "issues": []
}
```

### SARIF 报告

`--format sarif` 会写入 `.flutterguard/report.sarif`，可上传到 GitHub Code Scanning。high、medium、low 分别映射为 SARIF `error`、`warning`、`note`。

### Suppression 与 baseline

对已确认的误报可以使用源码注释：

```dart
// flutterguard: ignore missing_const_constructor
// flutterguard: ignore iot_security, mqtt_connection
// flutterguard: ignore all
```

注释只作用于当前行和下一行。

推荐 CI 接入顺序：

```bash
flutterguard config doctor
flutterguard baseline create .
flutterguard baseline check . --baseline .flutterguard/baseline.json --no-growth
flutterguard scan . --baseline .flutterguard/baseline.json --format json --fail-on high
```

## 评分

```
score = max(0, 100 - high×10 - medium×4 - low×1)
```

| 分数段 | 等级 |
|--------|------|
| 80–100 | 优秀 |
| 50–79 | 需关注 |
| 0–49 | 需整改 |

---

## CI 集成

### GitHub Actions

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
        run: flutterguard scan . --format json --baseline .flutterguard/baseline.json --fail-on high --min-score 80
```

### GitHub Code Scanning

```yaml
name: FlutterGuard SARIF

on: [push, pull_request]

jobs:
  code-scanning:
    runs-on: ubuntu-latest
    permissions:
      security-events: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: 3.11.5
      - run: dart pub global activate flutterguard_cli
      - run: flutterguard scan . --format sarif --baseline .flutterguard/baseline.json
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: .flutterguard/report.sarif
```

### GitLab CI

```yaml
flutterguard:
  image: dart:3.11.5
  script:
    - dart pub global activate flutterguard_cli
    - flutterguard scan . --format json --fail-on high --min-score 80
  artifacts:
    paths:
      - .flutterguard/report.json
    when: always
```

### pre-commit hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: flutterguard
        name: FlutterGuard scan
        entry: flutterguard scan . --fail-on high
        language: system
        pass_filenames: false
        always_run: true
```

### 本地脚本

<details>
<summary><b>macOS / Linux</b></summary>

```bash
#!/usr/bin/env bash
# scan_ci.sh
if flutterguard scan . --format json --fail-on high --min-score 80; then
    echo "All checks passed!"
else
    status=$?
    echo "FlutterGuard failed with exit code $status."
    exit "$status"
fi
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
# scan_ci.ps1
$ErrorActionPreference = "Stop"
flutterguard scan . --format json --fail-on high --min-score 80
$status = $LASTEXITCODE

if ($status -eq 0) {
    Write-Host "All checks passed!" -ForegroundColor Green
} else {
    Write-Host "FlutterGuard failed with exit code $status." -ForegroundColor Red
    exit $status
}
```
</details>

---

## 常见问题

### Windows: ANSI 颜色显示为原始转义字符

使用 **Windows Terminal**（Windows 10/11 自带）而非旧版 cmd.exe。也可添加 `--no-color` 禁用 ANSI 输出：

```powershell
flutterguard scan . --no-color
```

### Windows: "API key required" 错误

说明当前 shell 解析到了旧版全局二进制。显式运行当前目录编译产物：

```powershell
.\flutterguard.exe scan .
```

或重新安装：

```powershell
dart pub global deactivate flutterguard_cli
dart pub global activate flutterguard_cli
```

### Windows: 中文输出显示乱码

```powershell
# PowerShell 中设置 UTF-8 编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# 推荐使用 Windows Terminal，默认支持 UTF-8
```

### glob 模式始终使用正斜杠

在 `flutterguard.yaml` 中，所有平台的路径模式均使用 `/`：

```yaml
# 正确
path: lib/presentation/**

# 错误（Windows 也不要用反斜杠）
path: lib\presentation\**
```

---

## 仓库结构

```
flutterguard/
├── packages/
│   └── flutterguard_cli/   CLI 实现（主开发路径）
├── archive/                已归档的运行时追踪包
└── examples/
    └── scan_demo/          扫描示例项目
```

## 开发

```bash
# 全平台通用
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub get
dart pub global activate melos
melos bootstrap

# 常用命令
dart run melos run analyze     # 静态分析
dart run melos run test:cli    # 运行测试
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
```

## 扩展阅读

| 文档 | 内容 |
|------|------|
| [docs/USAGE.md](docs/USAGE.md) | 完整使用指南（全平台） |
| [docs/WINDOWS_ASSESSMENT.md](docs/WINDOWS_ASSESSMENT.md) | Windows 兼容性评估报告 |
| [docs/FLUTTERGUARD_SPEC.md](docs/FLUTTERGUARD_SPEC.md) | 技术规格 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构概览 |

## License

MIT
