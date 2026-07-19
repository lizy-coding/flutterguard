---
checkpoint_date: 2026-07-17
timezone: Asia/Shanghai
branch: develop
base: origin/develop
head: 3aa32bb
target_version: 0.7.0
target_json_schema: 2.0.0
target_rule_count: 16
checkpoint_state: implementation_complete_commits_pending
---

# FlutterGuard 演进路线与续跑检查点

## 用途

本文件是当前重构的续跑入口。后续执行者应先读取根目录及目标目录的
`AGENTS.md`，再读取本文件和 `git status`，从第一个未完成阶段继续，不要重新
推导已经确认的架构方向。

## 当前结论

FlutterGuard 正从 Melos 历史多包仓库收敛为一个根目录 Dart CLI 包。目标不是
保留旧内部 API，而是减少维护面，同时稳定 CLI、JSON/SARIF、changed-only、
baseline 和抑制注释等用户可见能力。

目标形态：

- 根目录是唯一可发布的 `flutterguard_cli` 包；
- 仅保留 `bin/`、`lib/`、`test/`、`example/`、`doc/` 和发布脚本；
- CLI 只有 `scan`、`baseline create`、`config init|check`、`rules` 四个命令族；
- `RuleRegistry.registrations` 是规则说明、默认值和执行入口的唯一数据源；
- `ScanContext`、`SourceWorkspace` 和共享 `ImportGraph` 是扫描内核边界；
- JSON 使用 schema `2.0.0`，只保留规范字段名；
- 规则集合收敛到 16 个低重复、工程相关的规则。

## 已完成

### 已提交

- [x] `3aa32bb chore: remove obsolete architecture assets`
  - 删除冻结的 runtime archive、IDE 工程文件、过期规划/重复文档和废弃入口；
  - 50 个文件，删除 4,290 行；
  - 当前分支相对 `origin/develop` 领先 1 个提交。

### 已实现但尚未提交

- [x] 将活跃包从 `packages/flutterguard_cli/` 扁平化到仓库根目录；
- [x] 将 `examples/scan_demo/` 收敛为 `example/`；
- [x] 删除 Melos、开发 wrapper 和重复编译/扫描脚本；
- [x] 将 CLI 收敛为四个命令族并移除重复 `--path`；
- [x] 用通用 `RuleConfig` 替换大量逐规则配置类型；
- [x] 合并 catalog、metadata 和 executor registry；
- [x] 合并 layer/module 检测实现并共享 import graph；
- [x] 删除 score、priority、confidence、兼容别名及无执行语义元数据；
- [x] 删除 generic size、missing const、device lifecycle、MQTT 配置和依赖版本规则；
- [x] 去除规则级 allowlist/ignore-path 旁路并拒绝未知规则参数；
- [x] 将测试重组为 CLI、配置、规则和扫描器契约测试；
- [x] 更新 README、外部规格、内部架构和分层 `AGENTS.md`；
- [x] 新增 `.pubignore`，发布包不再包含测试夹具、本地二进制和工程元数据。

## 当前工作区快照

记录时的 `git status --porcelain=v1 --untracked-files=all`：

- 110 个已跟踪文件变更或删除；
- 70 个未跟踪新文件；
- 合计 180 项；
- 暂存区为空；
- 生产 Dart 代码约 4,836 行；
- 测试 Dart 代码约 918 行。

Git 将根目录迁移暂时显示为旧路径删除加新路径未跟踪。不要单独恢复
`packages/flutterguard_cli/`、`examples/scan_demo/` 或 `docs/`；它们分别由
根目录包、`example/` 和 `doc/` 替代。

## 已通过验证

- [x] `dart format --output=none --set-exit-if-changed bin lib test`
- [x] `dart analyze`：无问题
- [x] `dart test`：24 项全部通过
- [x] `dart run bin/flutterguard.dart config check example`
- [x] 示例扫描：3 个文件、0 个问题、`--fail-on high` 通过
- [x] `rules --format json` 输出 16 个规则
- [x] 原生 executable 编译并输出 `flutterguard 0.7.0`
- [x] `git diff --check`
- [x] 干净临时副本 `dart pub publish --dry-run`
  - 退出码 0；
  - 0 warnings；
  - 发布压缩包约 44 KB；
  - 仅有已发布版本从 `0.1.0` 跳到当前版本的非阻塞 hint。

## 下一步：拆分剩余提交

按顺序执行，每批提交前后都确认 `git diff --cached --name-only`，不要混入下一批
文件。

### 1. 根包与内核收敛

建议提交信息：

```text
refactor: flatten and simplify the flutterguard CLI
```

范围：

- 根 `pubspec.yaml`、`analysis_options.yaml`、`.gitignore`、`.pubignore`、
  `flutterguard.yaml`；
- 删除 `melos.yaml`；
- 删除旧 `packages/flutterguard_cli/**`，新增 `bin/**`、`lib/**`、`test/**`；
- 删除 `examples/scan_demo/**`，新增 `example/**`；
- 暂不包含 `.github/**`、`scripts/**`、根文档和 `doc/**`。

提交前门槛：

```bash
dart format --output=none --set-exit-if-changed bin lib test
dart analyze
dart test
dart run bin/flutterguard.dart config check example
dart run bin/flutterguard.dart scan example --format json --no-color --fail-on high
git diff --cached --check
```

### 2. CI 与发布脚本收敛

建议提交信息：

```text
ci: align workflows with the root Dart package
```

范围：

- `.github/workflows/flutterguard.yml`；
- `.github/workflows/release.yml`；
- `scripts/package_release.sh`、`scripts/package_release.ps1`；
- 删除 `scripts/compile.*`、`scripts/flutterguard-dev*`、`scripts/scan_ci.*`。

提交前门槛：

```bash
bash -n scripts/package_release.sh
dart compile exe bin/flutterguard.dart -o /tmp/flutterguard-check
/tmp/flutterguard-check --version
git diff --cached --check
```

Windows PowerShell 包装脚本需要由 Windows workflow 做最终宿主验证。

### 3. 文档与检查点

建议提交信息：

```text
docs: document the simplified v0.7 architecture
```

范围：

- `README.md`、`CHANGELOG.md`、根 `AGENTS.md`；
- 删除旧 `docs/ARCHITECTURE.md`、`docs/FLUTTERGUARD_SPEC.md`；
- 新增 `doc/ARCHITECTURE.md`、`doc/FLUTTERGUARD_SPEC.md`；
- 本文件 `EVOLUTION_PLAN.md`。

提交前门槛：

```bash
rg -n 'melos|packages/flutterguard_cli|examples/scan_demo|docs/' \
  README.md AGENTS.md doc bin lib test example .github scripts || true
git diff --cached --check
```

历史内容允许出现在 `CHANGELOG.md`，活跃说明中不得存在旧路径或已删除能力。

## 所有提交完成后的发布门槛

```bash
dart pub get
dart format --output=none --set-exit-if-changed bin lib test
dart analyze
dart test
dart run bin/flutterguard.dart rules --format json
dart run bin/flutterguard.dart config check .
dart run bin/flutterguard.dart config check example
dart run bin/flutterguard.dart scan example \
  --format json --output .flutterguard/ci --fail-on high --no-color
dart compile exe bin/flutterguard.dart -o /tmp/flutterguard-0.7.0
/tmp/flutterguard-0.7.0 --version
dart pub publish --dry-run
git diff --check
git status --short
```

只有在工作区干净时，根目录 publish dry-run 的 Git 状态检查才代表最终发布结果。
工作区尚未提交时，使用无 `.git` 元数据的干净临时副本验证包内容。

## 后续产品演进

完成当前三批提交和发布门槛后，再进入规则质量阶段：

1. 为 `OverlayEntry` 增加 `remove()` / `dispose()` 生命周期安全检测；
2. 将仍依赖字符串的方法/类型识别逐步升级为 AST 和可解析类型语义；
3. 为新增规则先锁定所有权、低误报边界、changed-only 行为和抑制契约；
4. 每个规则必须有 positive、negative、disabled、suppression 和报告契约覆盖；
5. 保持一次扫描只读/解析一次源文件，并复用 `SourceWorkspace`；
6. 保持 layer/module/cycle 共享项目 import graph。

## 明确不做

- 不恢复 runtime SDK、APM、云服务、Flutter Widget 或动态插件系统；
- 不恢复 Melos、多包发布结构或公共 Dart scanner API；
- 不恢复 score、priority、confidence 或 JSON 兼容别名；
- 不恢复 generic size、missing const、依赖版本或 broker 配置规则；
- 不为降低误报而恢复每条规则的宽泛 allowlist；
- 不在当前收敛提交中夹带新的规则功能。

## 后续会话启动协议

```bash
git log -3 --oneline --decorate
git status --short
dart analyze
dart test
```

然后读取本文件“下一步”部分，从第一个未完成提交开始。每完成一个阶段，更新
front matter 的 `head`、`checkpoint_state`，勾选对应项目，并在“已通过验证”中
记录最新实际结果。
