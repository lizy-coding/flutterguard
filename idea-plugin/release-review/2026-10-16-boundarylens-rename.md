# BoundaryLens 本地更名验证

日期：2026-10-16。基点 ca80925 加当前未提交工作区。
状态：更名与自动化回归通过；未安装、提交、推送或发布。

产品 BoundaryLens、包 boundarylens_cli、CLI boundarylens、插件 com.boundarylens、
Kotlin namespace、可执行资源、ZIP、活跃指南、示例和 CI/打包脚本均已切换。
GitHub origin 与本地工作目录保留原地址；原 LICENSE、第三方原文和日期化历史证据不改写。
CI 工作流仅作身份/路径迁移，没有运行远端任务，也未关闭既有平台门禁。
历史 .hermes 中的旧 CI patch 任务保持原样，不作为当前可执行发布方案重新执行。

迁移行为：新配置优先、旧配置 fallback、显式配置不回退；两种抑制前缀兼容。
新插件 ID 与旧版不同，需要停用旧插件后手动安装新包；项目开关不自动迁移。
更名不改变 finding ID、JSON/SARIF 版本、baseline 指纹或模块检测范围。
新包名与产品名不代表已登记、独占或可在市场安装。

## 验证

| 项目 | 结果 |
|---|---|
| dart pub get / format gate / analyze | PASS，无静态分析问题 |
| 更名及模块聚焦测试 | PASS，29 项 |
| 全套 Dart 测试 | PASS，72 项 |
| example 扫描 | PASS，0 findings，模块明确 not_configured |
| 新 CLI 原生编译与 --version | PASS，boundarylens 0.7.1 |
| 模块示例 native 扫描 | PASS，complete / project、1 private_entry，匹配 expected-report |
| IDEA clean/check/buildPlugin | PASS，18 项；本地 IDE261、Kotlin2.3、JDK21 |
| ZIP 回读 | PASS，新 ID/name/native，未残留 com/flutterguard 类或旧 native；原许可与当前文档一致 |
| pub publish --dry-run | WARN，exit65、2 warnings：Git 中旧命名文件处于删除/忽略状态及未提交改动；未上传 |
| git diff --check / 活跃 Markdown 路径 | PASS |

安装包：[boundarylens-idea-0.7.1.zip](../build/distributions/boundarylens-idea-0.7.1.zip)。
指纹和平台范围见 [artifact](2026-10-16-boundarylens-rename-artifact.json)。
旧 ZIP 仅为忽略的本地备份，未进入新包。

## 下一步

按 [模块检测具体计划](../../doc/MODULE_DETECTION_NEXT_STEPS.md) 的顺序，
先处理配置定位与归属解释，再处理增量失效提示和 IDE 导航，各步单独验收。
本轮未提前实现这些后续行为。新 UI 人工验收、旧 IDE/其他 native 平台、
Plugin Verifier、名称/版本/协议公开链接与账户法律步骤仍独立待办。
