# BoundaryLens 首版标准整改 — 2026-10-16

结论：核心接入基础与参数预校验缺口已关闭；市场发布仍为 **NO-GO**。
本记录承接 [整改前验收](2026-10-16-release-acceptance.md)，不修改历史结论。
工作区基点仍是 ca80925，包含未提交的更名与本轮整改；未推送、上传市场或接受协议。

## 已完成

| 缺口 | 改动与验证 | 状态 |
|---|---|---|
| R1 内部扩展基础 | RuleDefinition 声明输入/范围/激活条件/参数类型；唯一注册表验证定义；RuleRunner 统一准备共享事实、禁用跳过、归属校验、逐规则执行覆盖与诊断隔离 | PASS（本地契约） |
| R2 参数随源码形状变化 | config check / scan 执行前共用校验；空类与变量两种输入都拒绝无效 requireTls，退出分别为 1 / 2 | PASS |
| R4 构建链路 | macOS runner 更新为 macos-15 / macos-15-intel；插件 job 依赖四份 native，GitHub release 依赖插件构建 | 实现完成，远端待跑 |
| R5 默认兼容线 | SDK/Verifier 默认 IDEA2026.1.5 / 261，Kotlin2.3；替换三处弃用 API | PASS（单目标） |
| CLI→IDE 执行证据 | coverage.rules 保留状态、范围、原因；未知新增内置规则 ID 无需修改 IDE 目录即可显示 | PASS（协议） |

不开放自定义规则 DSL、脚本执行、外部规则 SDK 或第二套注册表。模块配置定位、
增量失效提示及可点击证据导航仍按 [执行计划](../../doc/MODULE_DETECTION_NEXT_STEPS.md)
后续步骤实施，本轮不冒称已经交付。

## 当前产物与验证

- 最终候选 ZIP：boundarylens-idea-0.7.1.zip，4,225,520 bytes。
- SHA-256：14dc0f7f17516e2c7a88d01ce6d0430018c1b864516b978354ad5b60bff8646d。
- Dart：pub get、format、analyze、83 项测试、example smoke、macOS ARM native 编译通过。
- IDEA：check / buildPlugin，21 项测试，0 failure / error / skip；其中含 3 项真实 bundled CLI smoke。
- 最终同一 ZIP 的 Plugin Verifier：IU-261.27258.48 **Compatible**，解析实际 Dart510.0.0，
  未生成 deprecated usages 报告。仅覆盖这一宿主组合，不能推及全部 261 构建或其他 OS。
- 无效参数四组合与 native preflight 证据见
  [证据目录](2026-10-16-remediation-evidence/typed-option-regression.json)；
  Verifier [verdict](2026-10-16-remediation-evidence/verification-verdict.txt) 与
  [依赖解析](2026-10-16-remediation-evidence/dependencies.txt) 绑定该候选。
- [机器记录](2026-10-16-release-remediation.json) 保留产物 SHA 与独立状态。

## 本地安装与示例 UI

已获用户授权安装本地插件、停用旧 FlutterGuard，并仅为 module_boundary 示例
配置 Dart SDK。初次安装 JAR 与 SHA 为 0d07f2b21ada3d210838b9618e10b9870086138100368e308ba8923d7023bcf3
的 ZIP 字节一致，旧 com.flutterguard 已写入 disabled_plugins.txt。未重启或停止 Forge。
示例在独立窗口打开，SDK 为本机 Dart3.13.2；未改变项目的信任配置。

| 实测场景 | UI 反馈 |
|---|---|
| 坏引用编辑器与 Problems | bad.dart:1，module_violation，说明绕过 payment 公开入口 |
| 当前包报告 | 1 findings / 0 diagnostics，scope=project，4/4；保留 CHECK 状态及原因 |
| 改为公开入口再扫 | 0 findings / 0 diagnostics，4/4 |
| 省略 payment entry_points | 检查不完整，module_violation partial，entry_points_not_declared |
| 未配置架构 | 未配置模块约束，0/4，not_configured |
| 无效 requireTls | 扫描失败（exit2），显示 rules.iot_security.requireTls must be boolean |
| 单文件扫描 | 1 finding，scope=file，1/4；circular_dependency 明确 unsupported_scope |
| 离线指南与更新记录 | 能加载；显示本轮整改、更名及未发布状态 |

上述源码与配置临时改动均已与备份逐字节比对恢复。配置错误没有被显示成扫描成功。
这证明本机示例路径，不覆盖取消、嵌套包、未信任项目或其他平台的全部人工验收。

实看另发现指南长段落在设置页右侧被裁切。已缩小文档视图首选尺寸，并允许视图与
根面板收缩；重新通过 21 项插件测试及同一 Verifier，形成上面的最终 ZIP。
更新初次提示重启时，为保留 Forge 会话先选 Not Now。随后用户明确允许停止 Forge
并重启验收；检查编辑窗口并保存编辑内容、停止 Forge 后完成重启。
重启提示 Plugin updates installed / BoundaryLens，安装 JAR 与最终 ZIP 字节一致。
**布局修正 UI PASS**：设置页指南长段落正常换行、截图完整落在内容区内，
更新记录的整改与更名段落均正常换行，无原先右侧裁切。验收窗口为当前本机设置页，
不扩展为所有窗口尺寸或其他 OS 的布局保证。此前扫描实测与最终布局包分别记录，未混用 SHA。

本地完整日志：/private/tmp/boundarylens-standards-tests.log、
/private/tmp/boundarylens-standards-analyze.log、
/private/tmp/boundarylens-standards-idea-final.log、
/private/tmp/boundarylens-standards-verifier.log。

## 尚未放行

1. 源码未提交冻结；pub publish --dry-run 仍 exit65 / 2 warnings。不得删除当前改动来凑干净门禁。
2. 当前 native 集合为 1/4；macOS x64、Linux x64、Windows x64 缺失。IDEA preflight
   在复制前失败且保留原资源。CI 修改通过本地 YAML 结构检查，尚无远端执行证据。
3. 核心示例及最终布局 UI 已通过。完整宿主/异常操作矩阵仍待验收，
   构建、协议测试与 Verifier 不替代其余人工实测。
4. 公开源码及合规材料仍未推送，之前 404 的链接尚未关闭；不把本地 Markdown 当成公开政策。
5. 用户明确首版不承诺支持材料固定保留期、继续待定。privacy.md 保持发布草案，
   不编造期限或标为合规完成；发布者账户、EULA/市场声明和新产品媒体仍需最终核对。

下次从源码冻结、多平台同源产物、新 UI 及公开材料继续验收，不再重复立项 R1/R2。
