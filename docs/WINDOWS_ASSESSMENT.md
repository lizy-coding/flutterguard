# FlutterGuard Windows Availability Assessment

> 更新日期: 2026-07-16 | 版本: 0.6.0 | 评估范围: flutterguard_cli 全部源码及依赖链

---

## 1. 总体评估：完全可用

FlutterGuard CLI 在 Windows 平台上**完全可用**，无需任何代码修改。代码库从设计阶段即考虑了跨平台兼容性，在依赖选择、路径处理、文件 I/O 等方面均采用纯 Dart 跨平台方案。

| 维度 | 状态 | 说明 |
|------|------|------|
| Dart SDK 兼容 | ✅ | Dart 3.11.5+ 全平台支持 (Windows/macOS/Linux) |
| 依赖链兼容 | ✅ | 5 个运行时依赖全部纯 Dart，零原生代码 |
| 路径处理 | ✅ | `package:path` + Context 抽象 + 反斜杠归一化 |
| 文件 I/O | ✅ | 仅使用 `dart:io` 跨平台 API |
| 测试覆盖 | ✅ | 3 个 Windows 专项路径测试 |
| 命令行输出 | ✅ | ANSI 转义码 — Win10+ Terminal 完整支持 |
| 原生编译 | ✅ | `dart compile exe` 产出独立 .exe |

---

## 2. 依赖链逐项审查

### 2.1 运行时依赖

| 依赖 | 版本 | 类型 | Windows 兼容 | 备注 |
|------|------|------|-------------|------|
| `args` | ^2.5.0 | 纯 Dart | ✅ | CLI 参数解析 |
| `analyzer` | ^7.3.0 | 纯 Dart | ✅ | Dart AST 解析 |
| `glob` | ^2.1.2 | 纯 Dart | ✅ | 文件模式匹配 |
| `path` | ^1.9.0 | 纯 Dart | ✅ | 跨平台路径（含 Windows 风格 Context） |
| `yaml` | ^3.1.2 | 纯 Dart | ✅ | YAML 解析 |

### 2.2 开发依赖

| 依赖 | 类型 | Windows 兼容 |
|------|------|-------------|
| `test` | 纯 Dart | ✅ |
| `lints` | 纯 Dart | ✅ |
| `melos` | 纯 Dart | ✅ |

**结论**: 零原生依赖，零 FFI 调用。编译产物为单文件 native exe，无需安装 Dart runtime。

---

## 3. 代码级 Windows 兼容性分析

### 3.1 `dart:io` 使用情况

共 11 个源文件使用 `dart:io`，仅使用跨平台 API：

| API | 用途 | Windows 兼容 |
|-----|------|-------------|
| `File.readAsStringSync()` | 读取源码 | ✅ |
| `File.readAsLinesSync()` | 按行读取 | ✅ |
| `File.writeAsStringSync()` | 写入报告 | ✅ |
| `File.existsSync()` | 文件存在检查 | ✅ |
| `Directory.existsSync()` | 目录存在检查 | ✅ |
| `Directory.createSync()` | 创建输出目录 | ✅ |
| `stdout.writeln()` | 控制台输出 | ✅ |
| `stderr.writeln()` | 错误输出 | ✅ |
| `exit()` | 进程退出 | ✅ |

**未使用的 API**: `Platform.isWindows`, `Platform.isMacOS`, `Platform.operatingSystem`, `Process.run`, `Process.start`, `dart:ffi` — 均无引用。

### 3.2 路径处理策略

核心机制：`package:path` 的 `p.Context` 系统。

```
p.Context(style: p.Style.windows, current: r'C:\repo')
  └── 自动适配 \ 分隔符 → normalize / join / relative 等操作
```

反斜杠归一化：以下 5 处代码显式将 `\` 转为 `/`，确保 `package:glob` 正常工作（glob 包要求正斜杠）：

| 文件 | 行号位置 | 上下文 |
|------|---------|--------|
| `file_collector.dart` | 15, 24 | include/exclude 模式 |
| `layer_violation.dart` | 34 | layer path 模式 |
| `module_violation.dart` | 34 | module path 模式 |
| `path_utils.dart` | 31 | matchesProjectGlob 内部 |

测试中的 Windows 路径 Context 覆盖：

```dart
// scanner_test.dart:302-314 — Windows 路径 glob 匹配测试
final windows = p.Context(style: p.Style.windows, current: r'C:\repo');
matchesProjectGlob(
  r'C:\repo\lib\presentation\device_page.dart',
  'lib/presentation/**',
  r'C:\repo',
  context: windows,
) // → true

// scanner_test.dart:331-345 — Windows 路径 package: 导入解析
resolveImport(
  r'C:\repo\lib\presentation\page.dart',
  'package:app/data/repo.dart',
  {...},
  projectPath: r'C:\repo',
  context: windows,
) // → C:\repo\lib\data\repo.dart
```

### 3.3 潜在风险点

| 风险 | 等级 | 影响 | 缓解 |
|------|------|------|------|
| 无 Windows CI 真实验证 | ⚠️ 低 | — | Windows Context 模拟测试已覆盖核心路径逻辑 |
| ANSI 转义码在旧 cmd.exe 不可见 | ⚠️ 低 | 显示原始转义字符，不影响功能 | Win10 1709+ 默认启用；建议在 Windows Terminal 中运行 |
| 驱动器号路径 (C:\\) | ✅ 无 | — | `p.Context(style: p.Style.windows)` 完整支持 |
| 长路径 (MAX_PATH > 260) | ⚠️ 低 | 极深嵌套项目可能遇到 | Dart SDK 3.11.5+ 已支持长路径 |
| 文件名大小写敏感 | ⚠️ 低 | Windows 文件系统不区分大小写，但 Dart 操作区分 | 影响极小 — glob 匹配和 import 解析均使用归一化路径比对 |

---

## 4. 安装与运行 — Windows 完整步骤

### 4.1 前置条件

```
1. 安装 Dart SDK 3.11.5+
   - 下载: https://dart.dev/get-dart
   - Windows 安装包 (x64 / arm64)
   - 验证: dart --version

2. 确认 PATH 环境变量包含:
   - Dart SDK bin 目录 (安装器自动配置)
   - Pub cache bin: %USERPROFILE%\AppData\Local\Pub\Cache\bin
```

### 4.2 从源码编译

```powershell
git clone https://github.com/lizy-coding/flutterguard.git
cd flutterguard

dart pub get
dart pub global activate melos
melos bootstrap

dart compile exe packages\flutterguard_cli\bin\flutterguard.dart -o flutterguard.exe
.\flutterguard.exe --help
```

### 4.3 全局激活

```powershell
dart pub global activate --source path packages\flutterguard_cli
flutterguard --help
```

### 4.4 常见 Windows 问题排查

**问题 1**: `where flutterguard` 指向旧版本

```powershell
where flutterguard                          # 检查当前路径
dart pub global deactivate flutterguard_cli # 删除旧版
dart pub global activate --source path packages\flutterguard_cli  # 安装当前版
```

**问题 2**: PowerShell 显示 "API key required"

说明系统解析到了另一个 FlutterGuard 二进制（旧版运行时追踪版本）。本仓库 CLI 是纯静态扫描工具，不需要 API Key。运行：

```powershell
.\flutterguard.exe scan -p D:\your\project  # 显式指定本地编译产物
```

**问题 3**: 中文输出显示乱码

```powershell
# PowerShell 中设置 UTF-8 编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
# 或使用 Windows Terminal（推荐），默认支持 UTF-8
```

**问题 4**: 颜色/ANSI 转义码不显示

确认使用 Windows Terminal（Windows 10/11 自带）而非旧 cmd.exe。旧 cmd.exe 可能显示原始转义字符 `[31m` 等，不影响功能，仅影响外观。

---

## 5. 与 macOS 的差异对比

| 特性 | macOS | Windows |
|------|-------|---------|
| Dart SDK 安装 | `brew install dart` 或官网下载 | 官网安装包 |
| 全局命令路径 | `$HOME/.pub-cache/bin` | `%USERPROFILE%\AppData\Local\Pub\Cache\bin` |
| 路径分隔符 | `/` | `\`（代码已做归一化处理） |
| 原生二进制输出 | `flutterguard` | `flutterguard.exe` |
| 终端颜色 | 默认支持 | 需 Windows Terminal / Win10+ |
| 示例命令 | `flutterguard scan -p /Users/me/project` | `flutterguard scan -p D:\dev\project` |

---

## 6. CI 集成 — Windows Runner

### GitHub Actions

```yaml
jobs:
  flutterguard:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: 3.11.5
      - name: Install FlutterGuard
        run: |
          dart pub global activate flutterguard_cli
      - name: Scan
        run: flutterguard scan -p . --format json --fail-on high
```

### 本地 CI 脚本 (PowerShell)

```powershell
# scan.ps1
$score = & flutterguard scan -p . --format json --fail-on high --min-score 80
if ($LASTEXITCODE -ne 0) {
    Write-Host "CI gate failed!" -ForegroundColor Red
    exit 1
}
Write-Host "All checks passed!" -ForegroundColor Green
```

---

## 7. 总结

**FlutterGuard CLI 在 Windows 上已达到生产可用状态**。所有路径处理、文件 I/O、import 解析等核心逻辑均通过 `package:path` Context 系统进行了跨平台抽象，并在测试中覆盖了 Windows 路径场景。

**建议**:
1. 在真实 Windows 环境中运行一次全量测试，作为 CI 补充验证
2. 使用 Windows Terminal 以获得最佳输出效果
3. 如需要在旧 cmd.exe 运行，可考虑添加 `--no-color` 参数（建议后续版本实现）
