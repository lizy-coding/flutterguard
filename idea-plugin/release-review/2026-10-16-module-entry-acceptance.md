# 模块公开入口保护：下一阶段本地试用记录

日期：2026-10-16。基点 fb86f4f 加未提交工作区；本轮没有提交、推送或发布。

结论：**实现与自动化验证通过，可进入本机试用；新 UI 人工验收待完成，市场发布仍为 HOLD。**
版本仍为 0.7.1 本地迭代，不代表已发布兼容升级。

## 已交付

- 正确区分本包 package URI 与外部包；import/export 及条件分支均纳入检查。
- scan 与 config check 共用边界验证：重名、未知依赖、重叠归属与无效入口不能静默通过。
- entry_points 为项目相对文件/glob；跨模块依赖必须同时满足允许关系与公开入口。
- 同模块内部引用、入口导出自己的实现保持合法；省略入口兼容旧依赖规则并报告 partial。
- JSON/SARIF 明确报告模块覆盖状态与 project/file/changed 范围，诊断不冒充 findings。
- 默认启用架构规则；其他检测器保留注册与测试，需显式开启。
- IDEA 保留完整报告，编辑器只做当前文件投影；新增当前 Dart 包扫描与只读报告。
- 未受信任项目不执行 native CLI；未保存、过期、超时与失败保护继续保留。

## 验证证据

| 检查 | 结果 |
|---|---|
| dart pub get | PASS |
| 格式检查 bin/lib/test | PASS，60 个文件，无格式差异 |
| dart analyze | PASS，无问题 |
| dart test | PASS，68 项；其中模块入口专属 18 项 |
| 原 example 扫描 | PASS，3 文件、0 findings；模块检查明确 not_configured |
| 独立模块示例 native 扫描 | PASS，4/4 项目范围、1 private_entry，匹配 expected-report.json |
| Native 编译与 bundled 字节核对 | PASS，Dart 3.13.2 / macOS arm64 |
| IDEA check/buildPlugin | PASS，18 项，无失败或跳过；IDE261 / Kotlin2.3 / 临时 JDK21 |
| ZIP 回读 | PASS，新包扫描动作、完整报告类、文档、native 与当前资源一致 |
| git diff --check | PASS |
| pub publish --dry-run | WARN / exit 65：未提交文件、已删除但受忽略规则影响的旧 StartupActivity；另有历史版本跨度 hint。没有上传 |

聚焦用例覆盖公开/内部入口、export/条件分支、包身份、同模块合法访问、归属冲突、
旧配置、禁用、未配置、解析缺口、单文件范围、变更范围、抑制、baseline、
严重程度覆盖、CLI exit 1 可用 JSON / exit 2 无效设置及 SARIF 诊断。

产物及源码指纹见 [artifact.json](2026-10-16-module-entry-artifact.json)。
CLI 和 Gradle 门禁逐项记录，不把带警告的 dry-run 标成完整发布门禁通过。

## 开始试用

候选 ZIP：[flutterguard-idea-0.7.1.zip](../build/distributions/flutterguard-idea-0.7.1.zip)。
安装到 IDEA261 后打开 [独立示例](../examples/module_boundary/README.md)，
按文件扫描、包扫描、修复及移除入口声明的顺序验收。
本轮未安装或重启用户 IDEA；不能把 adapter/native 测试当成新的界面实测。

本实现验证文件引用层级的模块约束，不证明符号级 API 泄漏、业务状态机、
完整传递语义或整体设计健康。配置/入口变更后的整体判断需要全包扫描；
changed-only 的 complete 只表示其显式选择范围可检查。

## 独立待办

- 新 IDE 界面人工验收与新的核心场景截图。
- 在获授权的真实项目里小范围试用，确认配置成本与误报。
- 冻结名称、版本、公开源码 revision 和最终协议链接。
- 旧版 IDE、其他 OS/native 目标、Plugin Verifier、原生第三方许可与账户法律步骤。

10 月 10 日的审查、截图与 hash 均保留为历史证据，不作为本次新功能验收。
