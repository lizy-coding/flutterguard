# FlutterGuard 演进路线图

本文档描述 FlutterGuard v0.7 之后的架构演进方向，按优先级分为四个阶段。
当前收敛重构的进度跟踪请参考仓库根目录下的 `EVOLUTION_PLAN.md`。

---

## 架构速览

```
bin/flutterguard.dart          唯一入口，路由四个命令族
lib/src/scanner.dart           扫描编配
lib/src/scan_context.dart      不可变 scan 作用域载体
lib/src/source_workspace.dart  单次读取/解析 AST 缓存
lib/src/import_graph.dart      共享项目导入图
lib/src/boundary_engine.dart   layer/module 共享边界引擎
lib/src/config_loader.dart     YAML → 泛型 RuleConfig
lib/src/report_generator.dart  表格/JSON 输出
lib/src/sarif_report.dart      SARIF 2.1.0 输出
lib/src/rules/registry.dart    规则元数据/默认值/执行的唯一数据源
lib/src/rules/*.dart           16 个检测器实现
```

---

## 第一阶段：收尾当前收敛重构（短期，已计划） ✅ 已完成 (2026-07-17)

参考 `EVOLUTION_PLAN.md` 中定义的 3 批提交：

### 1.1 根包与内核收敛

```
refactor: flatten and simplify the flutterguard CLI
```

- 提交根 `pubspec.yaml`、`analysis_options.yaml`、`.gitignore`、`.pubignore`
- 删除 `melos.yaml`，删除旧 `packages/flutterguard_cli/**`
- 新增 `bin/**`、`lib/**`、`test/**`、`example/**`

### 1.2 CI 与发布脚本收敛

```
ci: align workflows with the root Dart package
```

- 对齐 `.github/workflows/flutterguard.yml`、`release.yml`
- 更新 `scripts/package_release.sh`、`scripts/package_release.ps1`
- 删除废弃编译/扫描脚本

### 1.3 文档与检查点

```
docs: document the simplified v0.7 architecture
```

- 定稿 `README.md`、`CHANGELOG.md`、`AGENTS.md`
- 定稿 `doc/ARCHITECTURE.md`、`doc/FLUTTERGUARD_SPEC.md`
- 提交本文件 `doc/EVOLUTION_ROADMAP.md`

---

## 第二阶段：检测质量提升（短期，已计划）

### 2.1 OverlayEntry 生命周期检测 ✅ 已完成 (2026-07-21)

- ~~检测 `OverlayEntry.remove()` 和 `OverlayEntry.dispose()` 的调用遗漏~~ (已添加 `OverlayEntry` → `remove` 到 `lifecycle_resource.dart` 的 `_resourceTypes`)
- ~~归属到 `lifecycle_resource.dart`~~

### 2.2 AST 化字符串检测 ✅ 已完成 (2026-07-21)

**问题**：`iot_security.dart` 和 `ble_scanning.dart` 当前使用正则和字符串匹配：

| 文件 | 方法 | 脆弱点 |
|---|---|---|
| `iot_security.dart` | `_secretPattern` 正则 | 误匹配注释/字符串常量中的模式 |
| `iot_security.dart` | `_cleartextMqttPatterns` 正则 | URL 格式变更需同步 |
| `ble_scanning.dart` | `body.contains('timeout')` | 方法名重命名后漏检 |

**改进**：升级为 `analyzer` 库的 AST 节点遍历，通过类型信息和解析引用语义进行检测：

1. 密钥检测 → 遍历 `VariableDeclaration` / `AssignmentExpression`，检查赋值右侧是否为明文密钥模式，排除注释和文档字符串
2. 明文 MQTT/HTTP 检测 → 解析 URI 字符串常量的 scheme，利用 `Uri.parse`
3. BLE timeout 检测 → 遍历 `MethodInvocation`，查找 `FlutterBluePlus.startScan` 或 `ScanMode` 相关调用及其 `timeout` 命名参数

### 2.3 新规则质量门槛 ✅ 已完成 (2026-07-21)

每条规则已覆盖五种测试场景：

| 场景 | 含义 | 覆盖情况 |
|---|---|---|
| positive | 预期触发发现的代码，确认检测生效 | `iot_security_issue.dart`, `ble_scanning_issue.dart`, `lifecycle_issue.dart` |
| negative | 不会触发的合法代码，确认无误报 | `iot_security_negative.dart`, `ble_scanning_negative.dart`, `lifecycle_negative.dart` |
| disabled | `enabled: false` 后不产出发现 | rules_test.dart 中 `_disabled` 测试 |
| suppression | 行内注释 `// flutterguard:ignore` 可抑制 | `iot_security_suppression.dart`, `ble_scanning_suppression.dart` |
| report-contract | 验证 JSON 输出中 `ruleId`/`severity`/`domain`/`message` 正确 | `iot_security` report contract test |

---

## 第三阶段：架构内聚深化（中期）

### 3.1 大文件拆分

当前三个文件包含多条规则，与 `ble_scanning.dart` / `iot_security.dart` 等"一文件一规则"的惯例不一致：

| 当前文件 | 行数 | 应拆分为 |
|---|---|---|
| `generic_state_management.dart` | 449 | `side_effect_in_build.dart`、`state_manager_created_in_build.dart`、`mutable_state_exposed.dart`、`state_layer_ui_dependency.dart` |
| `provider_state_management.dart` | 326 | `provider_value_lifecycle_misuse.dart`、`notify_listeners_in_loop.dart` |
| `riverpod_state_management.dart` | 276 | `riverpod_read_used_for_render.dart`、`riverpod_watch_in_callback.dart` |

拆分后共享逻辑保留在 `state_management_utils.dart` 中。

### 3.2 消除工具函数重复

| 重复项 | 位置 | 解决方案 |
|---|---|---|
| `sourceLine` vs `lineNumberForOffset` | `state_management_utils.dart:97` / `source_workspace.dart:10` | 统一使用 `SourceWorkspace` 的 `lineNumberForOffset`，移除 `state_management_utils.dart` 中的版本 |
| `_FirstOrNull` 扩展 | `provider_state_management.dart` | Dart 3.x 已内置 `firstOrNull`，直接移除自定义扩展 |
| BLE 资源类型列表 | `lifecycle_resource.dart`、`ble_scanning.dart`、`generic_state_management.dart` | 抽取共享类型常量到 `flutter_resource_types.dart` 或统一通过 AST 类型判断 |

### 3.3 `notify_listeners_in_loop` 的 `_provablyShortFor` AST 化

当前使用正则判断 for 循环是否"显然很短"：

```dart
RegExp(r'= 0; [A-Za-z_$][\w$]* < 1;')
```

对格式化差异和变量命名敏感。应改为：

- 获取 `ForStatement` 的 `forLoopParts`，解析初始化表达式和条件表达式
- 若初始化将循环变量设为常量 0，且条件为 `变量 < 1`，则判定为短循环
- 排除循环体内包含 `await` 或嵌套循环的情况

### 3.4 共享类型注册表

建立 `lib/src/rules/flutter_resource_types.dart`，集中声明需要追踪生命周期的 Flutter 资源类型：

```dart
// 示例结构
const _disposableTypes = {
  'StreamSubscription', 'Timer', 'AnimationController',
  'TextEditingController', 'ScrollController',
  'BluetoothDevice', 'BluetoothCharacteristic',
  // ...
};
```

供 `lifecycle_resource.dart`、`ble_scanning.dart`、`generic_state_management.dart` 统一引用。

---

## 第四阶段：能力扩展（中长期）

### 4.1 IoT 专项规则扩展

| 规则方向 | 检测内容 | 复杂度 |
|---|---|---|
| Wi-Fi 配置安全 | 检测代码中硬编码的 Wi-Fi SSID/密码，建议使用设备 provisioning API | 中 |
| 固件 OTA 校验 | 检测 `http.get(url)` 下载固件但未验证签名/哈希的模式 | 高 |
| MQTT QoS 检测 | 检测 QoS 0 发布关键消息（命令/配置）的场景 | 中 |
| 蓝牙配对模式 | 检测 `createBond` / `JustWorks` 配对且无用户确认 | 中 |

### 4.2 状态管理规则扩展

| 规则方向 | 检测内容 | 复杂度 |
|---|---|---|
| Cubit 泄漏 | 检测 `BlocProvider` 创建但未在 dispose 中 `close()` 的 Cubit | 中 |
| GetX 滥用 | 检测 `Get.to` 在 build 中调用、`Get.find` 在 initState 外使用 | 中 |
| MobX reaction 泄漏 | 检测未 dispose 的 `ReactionDisposer` | 中 |
| ValueNotifier dispose | 检测 `ValueNotifier` / `ChangeNotifier` 未 dispose | 低 |

### 4.3 测试体系增强

- 核心算法补充单元测试：
  - `TarjanSccFinder._stronglyConnectedComponents`（`state_dependency_cycle.dart`）
  - `_reconstructCycle` BFS 最短环路径重建
  - `_shortestCycle` 全节点对最短环
  - `ImportGraph.build` 多文件解析图构建
- 添加规则级别的 golden-file 测试，验证 JSON/SARIF 报告输出结构

### 4.4 跨文件数据流分析

当前所有规则均为单文件分析。对 `iot_security` 规则引入有限的跨文件追踪：

- 追踪 `static const` 密钥常量从一个文件被导出/导入到使用点的路径
- 检测通过 `export` 间接暴露的密钥
- 限制追踪深度为 1 层导入（通过 `ImportGraph` 即可实现，无需完整的数据流引擎）

---

## 架构约束（不可逾越的红线）

以下设计决策在 v0.7 收敛中已确认，后续演进不得逆转：

| 约束 | 说明 |
|---|---|
| 不恢复 Melos | 仓库根目录就是唯一的 Dart 包 |
| 不恢复 runtime SDK | 没有运行时 instrumentation、APM、云服务 |
| 不暴露公共 API | `lib/src` 是私有实现，集成边界仅 CLI + JSON/SARIF |
| 不添加冗余元数据 | 无 score/priority/confidence/兼容别名 |
| 不添加通用风格规则 | 无 generic-size、missing-const、格式化类规则 |
| 单一注册点 | `RuleRegistry.registrations` 是唯一的规则注册源 |
| 资源复用 | `SourceWorkspace` 和 `ImportGraph` 扫描生命周期内各构建一次 |
| 每个 finding 有唯一 owner | 同一代码模式不会被多个规则重复报告 |
| 框架自动检测 | 框架规则通过 import 检测激活，无全局配置开关 |

---

## 相关文档

- 仓库根 `EVOLUTION_PLAN.md` — 当前收敛重构的续跑检查点和提交拆分
- `doc/ARCHITECTURE.md` — 内部架构边界和 scan 流程
- `doc/FLUTTERGUARD_SPEC.md` — 外部契约（CLI / JSON / SARIF）
- 根 `AGENTS.md` — 仓库级约束和命令入口
