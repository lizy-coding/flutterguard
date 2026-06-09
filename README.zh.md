# FlutterGuard

> 面向 IoT / 智能家居 Flutter 项目的静态架构扫描 CLI，用于架构约束、代码质量检查和 CI 门禁。

[English](README.md) | [中文](README.zh.md)

FlutterGuard 扫描 Flutter/Dart 源码，报告架构边界违规、生命周期资源泄漏、循环依赖、过大文件/类/`build` 方法，以及常见代码规范问题。当前活动开发路径是 `packages/flutterguard_cli/`；旧的运行时追踪包已归档在 `archive/`。

**支持平台**: macOS、Windows、Linux — 纯 Dart CLI，零原生依赖。

**文档**: [使用指南](docs/USAGE.md) | [Windows 评估](docs/WINDOWS_ASSESSMENT.md) | [技术规格](docs/FLUTTERGUARD_SPEC.md) | [架构](docs/ARCHITECTURE.md)

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

- Dart SDK 3.3.0 或更高版本
- 从源码开发时需要 `melos`
- 支持操作系统: macOS、Windows、Linux

## 安装

<details open>
<summary><b>macOS / Linux</b></summary>

```bash
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard

dart pub global activate melos
melos bootstrap

dart pub global activate --source path packages/flutterguard_cli
flutterguard --help
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard

dart pub global activate melos
melos bootstrap

dart pub global activate --source path packages\flutterguard_cli
flutterguard --help
```

Windows 用户如果全局命令不可用，需要确认 `%USERPROFILE%\AppData\Local\Pub\Cache\bin` 已加入 `PATH`。
</details>

### 编译原生二进制

<details open>
<summary><b>macOS / Linux</b></summary>

```bash
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
./flutterguard --help
```
</details>

<details>
<summary><b>Windows (PowerShell)</b></summary>

```powershell
dart compile exe packages\flutterguard_cli\bin\flutterguard.dart -o flutterguard.exe
.\flutterguard.exe --help
```
</details>

## 快速开始

```bash
# 扫描 Flutter 项目（全平台适用）
flutterguard scan -p /path/to/flutter_app     # macOS / Linux
flutterguard scan -p D:\path\to\flutter_app   # Windows

flutterguard scan -p . --format json --fail-on high
flutterguard --help
```

扫描示例项目：

```bash
flutterguard scan -p examples/scan_demo
```

## CLI

命令：

- `flutterguard scan`
- `flutterguard --help`
- `flutterguard --version`

扫描参数：

| 参数 | 含义 | 默认值 |
|------|------|--------|
| `-p`, `--path` | 要扫描的项目路径 | `.` |
| `-c`, `--config` | 项目内配置文件路径 | `flutterguard.yaml` |
| `-f`, `--format` | 输出格式：`table` 或 `json` | `table` |
| `-o`, `--output` | 报告输出目录 | `.flutterguard` |
| `-v`, `--verbose` | 显示详细上下文 | 关闭 |
| `--fail-on` | CI 门禁等级：`none`、`high`、`medium`、`low` | `none` |
| `--min-score` | 最低可接受评分，0-100 | 未设置 |

## 配置文件

`flutterguard.yaml` 示例：

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
```

未提供 `flutterguard.yaml` 时会使用默认规则；架构层和模块规则需要在 `architecture.layers` / `architecture.modules` 中显式声明。

## 开发

```bash
# macOS / Linux
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub global activate melos
melos bootstrap

# Windows
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub global activate melos
melos bootstrap

# 常用命令
dart run melos run analyze
dart run melos run test:cli
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
```

## 常见问题

### Windows: "API key required" 错误

说明当前 shell 解析到了旧版全局二进制。显式运行当前目录编译产物：

```powershell
.\flutterguard.exe scan -p D:\path\to\project
```

或重新安装：

```powershell
dart pub global deactivate flutterguard_cli
dart pub global activate --source path packages\flutterguard_cli
```

### Windows: 终端输出乱码或颜色不显示

使用 **Windows Terminal**（Windows 10/11 自带）而非旧版 cmd.exe。旧终端可能显示 ANSI 原始转义字符，不影响功能。

### glob 模式始终使用正斜杠

在 `flutterguard.yaml` 中，所有平台的路径模式均使用 `/`：

```yaml
# 正确
path: lib/presentation/**

# 错误（Windows 也无需用反斜杠）
path: lib\presentation\**
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
