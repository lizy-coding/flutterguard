# BoundaryLens 发布验收 — 2026-10-16

结论：**NO-GO，当前不得作为首版完成或可提交市场的产物放行。**

当前功能回归通过，但用户确认的首版范围是“内置检测＋可验证的内部扩展基础”，
后半部分尚未实施。另有源码冻结、平台产物、兼容线与发布材料阻塞。
本次进行了本地预检、编译、打包、Verifier 与公开链接核验；未安装新插件、
推送源码、上传市场、修改账户或接受任何协议。此报告不是 JetBrains 审批结果。

## 最终产物

- 工作区基点：ca80925，BoundaryLens 更名及后续文档仍未提交。
- 候选：[boundarylens-idea-0.7.1.zip](../build/distributions/boundarylens-idea-0.7.1.zip)。
- ID/version：com.boundarylens / 0.7.1（本地迭代）。
- SHA-256：362146023e34b90155762454c9c3e1cd825a07083b68c9eb1d08e15cdb97ca0f。
- 大小：4,209,037 bytes；声明 261 至 261.*；仅携带 macOS arm64 native。
- 本次新编译 native 已用于最终 ZIP，字节一致，--version 为 boundarylens 0.7.1。
  原 native 与新编译文件不同不单独证明语义漂移，本次用当前编译结果固定验收对象。
- [机器记录及源码指纹](2026-10-16-release-acceptance.json)。

## 已执行的验收

| 项目 | 结果 | 边界 |
|---|---|---|
| pub get、format、analyze | PASS | 当前工作区 |
| Dart 全量测试 | PASS | 72 项，不等于真实项目准确率 |
| 原 example smoke | PASS | 3 文件、0 findings；moduleBoundary 明确 not_configured |
| native 编译 / 版本 | PASS | Dart 3.13.2，macOS arm64 |
| 原生 CLI 场景 | PASS | 12 个：包/单文件、修复、旧模式、空入口、失效配置、重叠、条件 export、迁移、未配置 |
| IDEA check/buildPlugin | PASS | 重跑 18 项，0 fail/skip；JDK21、Kotlin2.3、本机 IU261 |
| ZIP 资源一致性 | PASS | 新 ID/类、native、MIT、指南/更新记录/许可/隐私/第三方文本；无旧 namespace 类 |
| runtime 许可库存 | PASS（库存） | 19 包版本与 LICENSE SHA 匹配；不等于 native VM 第三方许可闭环 |
| Plugin Verifier | PASS（单目标）/ WARN | 最终同一 SHA；IU-261.27258.48 Compatible，3 处 deprecated API；可选 Dart 未解析 |
| CLI 发布 preflight | FAIL | exit1：工作区不干净、pub.dev dry-run 有警告 |
| pub dry-run | FAIL | exit65，2 warnings，主要来自未提交/删除中的旧命名文件；没有上传 |
| IDEA 发布 preflight | FAIL | exit1，版本化 dist 为 0/4；在复制前停止，原资源未被覆盖 |
| 新 IDEA UI / Dart 插件联动 | PENDING | 本轮未安装当前包、未进行人工 UI 验收；新标准目录未发现安装 |
| 公开源码/隐私路径 | FAIL（提交材料） | 仓库 public、默认 main；新 CLI 与 privacy.md 匿名 API 均 HTTP404 |

完整原始日志本地位于 /private/tmp/boundarylens-release-acceptance-20261016。
可长期复核的 Verifier 摘要存于 [verdict](2026-10-16-release-evidence/verification-verdict.txt)
和 [deprecated usages](2026-10-16-release-evidence/deprecated-usages.txt)。

## 阻塞项及复核标准

### R1 — 首版内部扩展基础未交付

[ADR-0003](../../doc/adr/0003-built-in-first-extensible-core.md) 明确标为待实施。
RuleDefinition 仍只有默认 options，没有独立参数 schema/输入需求声明；
registry 仍按 layer/module/cycle 配置决定是否建图，未在中央统一跳过 disabled，
也没有以内部测试规则证明“接入不改 scanner/IDE”。coverage 仍绑定模块。

复核标准：按 [第0步](../../doc/MODULE_DETECTION_NEXT_STEPS.md) 完成最小接入契约、
禁用/无效参数/事实不足/输出回归；不为赶发布改文档声称已经实现，也不扩张为自定义平台。

### R2 — 参数校验随源代码形状变化

临时项目使用相同配置：iot_security.enabled=true，requireTls: invalid。

| 命令/源输入 | 当前退出码 |
|---|---|
| config check | 0 |
| scan，只有 class Example {} | 0 |
| scan，出现变量声明 | 2：requireTls must be a boolean |

参数是否有效不应取决于被扫描源码碰巧触发哪个 visitor。此缺口对当前公开 opt-in
规则也可复现；需要 config check/scan 在规则执行前共用类型校验。
不能用现有72项测试通过代替该新增反例。复核需将此配置在两入口都稳定判为无效。

### R3 — 可重建的源码版本与公开材料未冻结

HEAD 仍是更名前的 ca80925，不能仅由该提交重建当前候选；构建成功不等于源码已公开。
本次匿名检查 main 的 bin/boundarylens.dart 和 idea-plugin/docs/privacy.md 均为404。

复核标准：用户授权后提交所需源码，冻结版本/revision，再单独授权推送；匿名验证
最终 revision 的源码/EULA/隐私链接。不得为了干净门禁撤销当前工作区或自动推送。

### R4 — native 目标集合与 CI 未形成发布链路

现有通用包只携带 macOS arm64。preflight 所需的四个 boundarylens 版本化 dist 均缺失；
旧 flutterguard dist 不能仅凭同为0.7.1拷入新包。

复核标准：冻结声明平台，构建同源目标并做对应宿主 smoke；若首发仅 macOS arm64，
需正式收窄分发与平台约束并验证，不能只写一句说明。release.yml 仍用已退役的
macos-13，以及即将结束支持的 macos-14，需要更新后再跑远端链路。
依据：[macOS13 退役](https://github.blog/changelog/2025-09-19-github-actions-macos-13-runner-image-is-closing-down/)、
[macOS14 支持时间](https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md)。

### R5 — 兼容线、依赖与人工功能验收未完成

最终包仅对 IU-261.27258.48 获得 Compatible；Dart optional dependency 未解析。
默认 Gradle SDK/Kotlin/since-build/Verifier 仍是 2024.3/2.0.21/243，与本机261候选不同。
3处弃用调用为 DaemonCodeAnalyzer.restart 两种重载和 ReadAction.compute。
弃用使用不单独冒称自动拒审，但须记录并制定迁移；不能将单目标结论扩大为全范围。

复核标准：统一正式兼容声明与构建目标，带真实 Dart 依赖验证；安装当前包检查
坏引用、合法入口、修复消失、包报告、partial/未配置/配置错误、嵌套包与信任提示。
旧 FlutterGuard 截图不能替代新界面验收。

### R6 — 协议与媒体仍是发布准备材料

MIT 和依赖许可已随包，EULA/隐私仍有 release draft、发布者身份匹配及支持消息
处理流程待定文字；native SDK/VM 许可库存也未完全闭环。
按本项目准备的提交材料，最终公开链接需待定稿和推送后核验。
Vendor account、开发者协议及 trader/non-trader 声明由发布者按实际情况完成。
本次没有代填或接受。新核心功能截图与名称/版本可用性也需最终核对。

依据：[Marketplace 审批要求](https://plugins.jetbrains.com/docs/marketplace/jetbrains-marketplace-approval-guidelines.html)、
[法律协议](https://plugins.jetbrains.com/docs/marketplace/legal-agreements.html)、
[EULA 要求](https://plugins.jetbrains.com/docs/marketplace/eula.html)。

## 建议整改顺序

先补 R1/R2 并跑新增反例 → 固定源码与版本 → 统一兼容线/native范围 → 当前包 UI 验收
及新示例素材 → 定稿公开合规材料 → 对最终 SHA 重跑发布门禁 → 再申请上传授权。
本次结论已完成验收工作，但不构成发布通过；没有为通过验收修改生产逻辑或降低门槛。
