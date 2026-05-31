# FlutterGuard

> 面向 IoT / 智能家居 Flutter 项目的静态架构扫描 CLI，用于架构约束、代码质量检查和 CI 门禁。

[English](README.md) | [中文](README.zh.md)

FlutterGuard 扫描 Flutter/Dart 源码，报告架构边界违规、生命周期资源泄漏、循环依赖、过大文件/类/`build` 方法，以及常见代码规范问题。当前活动开发路径是 `packages/flutterguard_cli/`；旧的运行时追踪包已归档在 `archive/`。

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

## 安装

### 从源码安装全局命令

```bash
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard

dart pub global activate melos
melos bootstrap
dart pub get

dart pub global activate --source path packages/flutterguard_cli
flutterguard --help
```

Windows 用户如果全局命令不可用，需要确认 `%USERPROFILE%\AppData\Local\Pub\Cache\bin` 已加入 `PATH`。

### 编译原生二进制

```bash
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub get
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
```

Windows 请使用 `.exe` 输出名，并优先运行当前目录下的二进制：

```powershell
dart pub get
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard.exe
.\flutterguard.exe scan -p D:\path\to\flutter_app
```

如果 `flutterguard scan` 输出 `API key required` 或 `Upload an APK for analysis`，说明当前 shell 解析到了旧版全局二进制，而不是本仓库的静态扫描 CLI。用下面命令检查实际路径：

```powershell
where flutterguard
```

处理方式：

```powershell
.\flutterguard.exe scan -p D:\path\to\flutter_app

dart pub global deactivate flutterguard_cli
dart pub global activate --source path packages\flutterguard_cli
```

### Windows 排查

当前 FlutterGuard CLI 支持 Windows，定位是本地静态扫描工具。实现使用 Dart 跨平台文件 API，并已有 Windows 风格项目路径和 import 解析测试覆盖。

当前静态扫描 CLI 不读取 `FG_API_KEY`，也没有 `--api-key` 参数。如果 PowerShell 出现下面输出，说明运行的是另一个 FlutterGuard 二进制：

```powershell
Error: API key required. Pass --api-key or set FG_API_KEY.
```

不要执行 `flutterguard FG_API_KEY.`。这只是把 `FG_API_KEY.` 当作命令参数传给程序，不是在 PowerShell 里设置环境变量。对于本仓库 CLI，没有 key 需要绑定。先确认当前命中的可执行文件：

```powershell
where flutterguard
flutterguard --help
```

正确 help 开头应为：

```text
FlutterGuard — IoT Flutter architecture static analysis CLI
No API key is required. This CLI scans local source code only.
Usage: flutterguard <command> [options]
```

如果 `where flutterguard` 指向旧版全局安装，优先显式运行当前目录编译产物：

```powershell
.\flutterguard.exe scan -p D:\code\xstudio
```

或者重新安装本仓库 CLI 作为全局命令：

```powershell
dart pub global deactivate flutterguard_cli
dart pub global activate --source path packages\flutterguard_cli
flutterguard scan -p D:\code\xstudio
```

## 快速开始

```bash
flutterguard scan -p /path/to/flutter_app
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
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard
dart pub global activate melos
melos bootstrap
dart pub get

dart run melos run analyze
dart run melos run test:cli
dart compile exe packages/flutterguard_cli/bin/flutterguard.dart -o flutterguard
```

## License

MIT
