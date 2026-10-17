# BoundaryLens 公共维护计划

更新：2026-10-17。

本地产品已更名为 BoundaryLens（原 FlutterGuard），GitHub 与工作目录地址保留。
迁移边界见 [RENAMING](RENAMING.md)。下阶段具体改动与逐步验收标准见
[模块检测执行计划](MODULE_DETECTION_NEXT_STEPS.md)：配置定位 → 增量失效提示 → IDE 证据导航 → 获授权试点。

当前发布评估见 [2026-10-17 续评](../idea-plugin/release-review/2026-10-17-release-plan-review.md)。
首版 IDEA 分发范围已确定为 macOS Apple Silicon / ARM64、IDEA 261；
其他 OS/架构不再是这次插件首发的缺失产物。CLI 的可移植性另行验证。

首版范围已进一步收敛为“内置检测＋内部扩展基础”，自定义规则暂缓，见
[ADR-0003](adr/0003-built-in-first-extensible-core.md)。先验证接入契约，再按上述顺序
完善模块使用闭环，不提前建设 DSL/SDK/规则市场。

BoundaryLens 独立维护 CLI 和 IntelliJ adapter，通过 JSON/SARIF 供应用、agent
和工具集调用。消费者的业务契约、生成器、平台证据与门禁留在消费者仓库。

## 当前范围

- 保留单包、单一规则注册表、共享源码缓存和共享依赖边界引擎。
- 保留单文件、changed-only、stdout、suppression、baseline、JSON/SARIF 契约。
- IDE 只保留启用开关与报告展示，不提供未实现的保存扫描、自定义参数或 CI 门禁设置。
- 不加入消费者专用目录、配置 preset、模块列表或 Agent 契约解析器。
- 现有 16 条规则是实现清单，尚不能作为全规则门禁质量认证。

## 后续执行顺序

当前已实现模块公开入口保护：修正 package 身份、export/条件分支、重叠归属；
项目通过 entry_points 声明入口。旧模块配置仍可用，明确报告 partial。
默认仅启用架构规则，其他规则显式 opt-in；IDE 保留完整报告并新增当前包扫描。

1. 最小示例的核心 UI 与布局已在 2026-10-16 完成人工验收；按
   [截图清单](../idea-plugin/release-review/module-screenshot-checklist.md) 补齐最终候选的模块场景媒体与安装记录。
2. 在真实项目选取两个模块，小范围验证约定维护成本和误报，不自动遍历消费者仓库。
3. 验证配置/入口变化影响未改动调用者的流程；当前需全包扫描，changed-only 只保证其声明范围。
4. 继续按真实缺陷与生态工具覆盖删减 heuristics，不加入评分或通用业务状态机推断。
5. 名称已确认为 BoundaryLens，首版平台已收敛；按最新发布评估完成源码冻结、
   不发布的远端验证入口、最终产物依赖验证和公开材料，不自动发布。

每条规则必须说明具体缺陷、已有工具为何不足、所需输入、误报边界和修复动作。
无法以有限成本明确判定的需求交给业务测试或人工 review，不扩展通用调用图、
数据流系统、动态插件机制或第二套治理平台来支撑它。

## 验证与证据

原 [发布验收](../idea-plugin/release-review/2026-10-16-release-acceptance.md) 保留为整改前快照。
[整改记录](../idea-plugin/release-review/2026-10-16-release-remediation.md) 已关闭内部接入
基础和参数预校验缺口，并记录核心示例与布局 UI 验收。它绑定当时的 ZIP，保留为历史证据。
最新 [续评](../idea-plugin/release-review/2026-10-17-release-plan-review.md) 记录当前候选：
43 项 Dart 聚焦测试、23 项 IDEA 测试和本机单平台 preflight 通过。默认离线 Verifier
未解析可选 Dart；固定 ZIP 副本另已提供 Dart 510.0.0 并通过 API 补验，使用
`-ignore-os-arch`，平台投递与实际安装继续独立验收。正式流水线仍需保留同等依赖证据。
发布仍为 NO-GO；源码冻结、同源远端构建、最终媒体与公开材料继续独立验收。

当前更名验证见 [BoundaryLens 本地记录](../idea-plugin/release-review/2026-10-16-boundarylens-rename.md)：
72 项 Dart 测试、18 项 IDEA 测试通过；入口保护原始基线另见
[更名前试用记录](../idea-plugin/release-review/2026-10-16-module-entry-acceptance.md)。代码已进入模块入口保护阶段，
不要重新立项 IoT 会话状态机或扩张默认检测集合。

下一阶段将最终候选的单文件标注、当前包报告、修复后消失及 partial/未配置提示
与实际安装包指纹绑定；历史 UI 结果不自动转移到重打包产物。真实项目与两个目标
模块继续由用户指定。没有明确授权前不扩大扫描范围、不推送、不发布。
ZIP/native 属于忽略的本地产物，换环境时应由对应源码重新构建，不能假定随 Git 提交存在。

执行根 `AGENTS.md` 的适用 gate。CLI 测试不证明 IDE 宿主、原生设备或平台验收；
本计划不宣称待办已经实现。发布、版本升级与迁移单独执行，不自动提交或发布。

历史 v0.7 迁移证据见根 `EVOLUTION_PLAN.md`，不得用历史测试数和工作区状态续跑。
