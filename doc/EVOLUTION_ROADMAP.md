# FlutterGuard 公共维护计划

更新：2026-10-10。

FlutterGuard 独立维护 CLI 和 IntelliJ adapter，通过 JSON/SARIF 供应用、agent
和工具集调用。消费者的业务契约、生成器、平台证据与门禁留在消费者仓库。

## 当前范围

- 保留单包、单一规则注册表、共享源码缓存和共享依赖边界引擎。
- 保留单文件、changed-only、stdout、suppression、baseline、JSON/SARIF 契约。
- IDE 只保留启用开关与报告展示，不提供未实现的保存扫描、自定义参数或 CI 门禁设置。
- 不加入消费者专用目录、配置 preset、模块列表或 Agent 契约解析器。
- 现有 16 条规则是实现清单，尚不能作为全规则门禁质量认证。

## 后续执行顺序

1. 用独立最小项目验证 dependency boundary 的正例、反例和增量扫描。
2. 修正 package URI、export、conditional import 的解析边界后再扩大适用范围。
3. 检查扫描范围降级、解析诊断和 IDE 失败可见性，避免零 findings 被误当作完整验证。
4. 按真实缺陷与生态工具覆盖逐条删减或修正 heuristics，不按规则数量扩展能力。

每条规则必须说明具体缺陷、已有工具为何不足、所需输入、误报边界和修复动作。
无法以有限成本明确判定的需求交给业务测试或人工 review，不扩展通用调用图、
数据流系统、动态插件机制或第二套治理平台来支撑它。

## 验证与证据

执行根 `AGENTS.md` 的适用 gate。CLI 测试不证明 IDE 宿主、原生设备或平台验收；
本计划不宣称待办已经实现。发布、版本升级与迁移单独执行，不自动提交或发布。

历史 v0.7 迁移证据见根 `EVOLUTION_PLAN.md`，不得用历史测试数和工作区状态续跑。
