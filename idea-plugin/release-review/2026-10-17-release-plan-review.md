# BoundaryLens 发布计划续评

日期：2026-10-17，Asia/Shanghai。结论：**本地更名已落地；正式发布 NO-GO**。
本轮以 ca8092573a05abd7341b3f05b9c6402c568779d3 加未提交工作区为输入。
未提交、推送、打标签、发布 GitHub Release、上传 Marketplace 或接受账户协议。

## 更名与首发范围

| 对象 | 当前状态 |
|---|---|
| 产品 / Dart 包 / CLI | BoundaryLens / boundarylens_cli / boundarylens |
| IDEA ID / Kotlin namespace | com.boundarylens |
| 配置 / 输出 | boundarylens.yaml / .boundarylens；旧配置与抑制前缀继续按迁移契约兼容 |
| 插件首发 | macOS Apple Silicon / ARM64；IDEA 261，实际验证 IU-261.27258.48 |
| 当前版本 | 0.7.1，本地候选；不宣称已发布 |
| GitHub 与本地目录 | 保留 lizy-coding/flutterguard 与当前工作目录；没有执行远端或目录更名 |

首发平台以当前 scoped AGENTS、描述符和发布工作流为准。昨天四平台方案中的
三个 MISSING 不再是这次 IDEA 首发的阻断项；增加平台需要另行决定分发范围并验证。
描述符同时声明 macOS 与 ARM64 依赖，仅改 ZIP 名称不能限制投递。
[JetBrains 平台分发说明](https://plugins.jetbrains.com/docs/marketplace/os-architecture-specific-plugin-versions.html)
支持从 2026.1 起按依赖选择平台；[GitHub runner 文档](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
确认当前 macos-15 为 ARM64。

## 本轮证据

| 检查 | 结果与边界 |
|---|---|
| 依赖解析 | PASS，Dart 3.13.2，离线 pub get；未升级约束 |
| 格式 / 静态分析 | PASS，63 个 Dart 文件无格式变化；No issues found |
| 聚焦 Dart 回归 | PASS，43 项：更名、CLI、模块入口、规则接入契约；未冒称本轮重跑全套 |
| native | PASS，boundarylens 0.7.1，Mach-O ARM64；dist、资源与 ZIP 中 native 指纹相同 |
| IDEA preflight | PASS，JDK 21.0.12.1，check/buildPlugin、23 项测试与 verifyPlugin；仅本机 |
| Verifier | 默认离线运行 Compatible，但未解析 Dart；固定副本另以 Dart 510.0.0、-ignore-os-arch 补验 API，Compatible |
| ZIP 回读 | PASS，新 ID/name/version，261–261.*，仅一个 native，无旧 com/flutterguard 类 |
| pub.dev dry-run | WARN，联网命令 exit 65，2 项 Git 状态警告；未上传包 |
| 远端证据 | PENDING；最新列出的 CI 仍为旧 FlutterGuard 任务，没有本次未提交源码的运行证据 |

共享工作区在本轮读取期间继续更新产物。为避免混用，单独保存评估副本
`/private/tmp/boundarylens-review-20261017-11196c6c8d7b.zip`，4,226,433 bytes，SHA-256：

```text
11196c6c8d7b8687a52eb6537a363bfe13ef3b3883b9d390e6e3f1593ee736f2
```

内置 native SHA-256：

```text
f41c47c9277b18b2692a70594b0ba8335e2c9200460856a630594397b622029a
```

本轮 preflight 通过后观察到的前一 ZIP 指纹是
`98f6abc602bbf15ec4a760a89d9908d3284d126479bbd2a549cebf76cac594a2`，
4,226,301 bytes；23 项测试属于该次构建。后续固定副本单独回读并执行 Verifier 补验，
没有将两次 ZIP 混写为同一个候选，也不替换 [昨天的整改记录](2026-10-16-release-remediation.md)。

本机 JDK 25 首次构建失败，改用已有 JDK 21 后通过。Gradle Verifier 日志另有缓存清理异常；
其退出 0、verdict 为 Compatible，但依赖图中的 Dart 未解析。固定副本的补验在独立临时缓存中
显式提供已安装的 Dart 510.0.0：默认检查报告两个 OS/架构标记模块未解析；使用官方
`-ignore-os-arch` 后 API verdict 为 Compatible，依赖图确认 Dart 510.0.0。
此参数只跳过平台标记模块检查，不验证 Marketplace 投递或实际宿主安装。
两份补验结果分别留存，进程退出 0 本身不视为 Compatible。

[机器记录](2026-10-17-release-plan-review.json) 与
[证据摘要](2026-10-17-plan-evidence/preflight-summary.txt) 保存状态、命令和指纹。
完整本机日志位于 `/private/tmp/boundarylens-20261017-*.log`；临时日志不属于可长期复现的发布证明。

## 必须关闭的缺口与执行顺序

1. **冻结源码与依赖。** 审阅现有未提交变更，连同根 pubspec.lock 纳入拟发布提交，
   保留其他工作的归属。锁文件当前是未跟踪文件；仅修改 ignore 规则和使用
   `--enforce-lockfile` 不代表远端已有锁文件。冻结后执行完整 Dart gate，
   从同一修订和 SDK 重建 native 与 ZIP，重新记录 source SHA、版本和产物 SHA。
2. **准备不发布的远端验证。** 当前 Release 仅在 v* 标签触发，全部成功后立即发布
   GitHub Release，不能把推标签当作无副作用试跑。建议增加手动验证入口，明确只构建、
   测试和留存 artifacts；发布 job 只允许正式标签。另将实际标签等于 pubspec 版本
   变为硬校验，当前脚本仅打印预期标签与提示。以上工作流改动为待执行方案，本轮未修改。
3. **补齐最终 ZIP 的 IDE 集成证明。** 将本轮显式提供 Dart 插件的补验纳入正式构建，
   检查 dependencies，而不只检查 Compatible 字样。保留 OS/架构选择器；验证最终包在目标宿主
   上的安装和模块示例，记录实际安装 JAR 与 ZIP 的对应关系。按
   [截图清单](module-screenshot-checklist.md) 制作当前模块入口场景媒体。昨天的核心 UI 与
   布局验收继续有效于其记录的候选，不能自动转移到今天的 ZIP。
4. **公开源码与材料。** 获授权推送冻结源码后检查匿名可访问的源码、MIT、EULA、privacy、
   notices 与版本说明链接。本轮查询远端 main 的 privacy 路径仍为 404；
   [最近 CI](https://github.com/lizy-coding/flutterguard/actions/runs/29881226287) 是 2026-07-22 的旧任务，
   [最新列出的 Release](https://github.com/lizy-coding/flutterguard/releases/tag/v0.7.0) 是旧品牌 0.7.0。
   这些历史远端结果不代表本次更名通过或失败。
5. **完成发布者步骤后再上传。** 核对名称/ID、版本、发布者身份、支持材料处理政策和账户声明。
   不替发布者编造保留期，也不把联网 dry-run 当作名称预留。首次上传涉及 Vendor 与
   Developer Agreement，按 [官方上传说明](https://plugins.jetbrains.com/docs/marketplace/uploading-a-new-plugin.html)
   由账户所有者完成。实际上传、审核通过与可安装状态分别留证。

本次只续评发布计划并确认既定更名，不重新立项已关闭的规则接入/参数问题，
不把配置定位、增量提示、导航或其他平台扩张为临时首发工程。
下一步应先形成可审阅的源码冻结范围与不发布的远端验证改动，再进入实际公开和上传。

## 读取与变更边界

初始读取限于根指引、领域词汇、pubspec 与八个发布/更名入口。
为核对入口声明与真实产物，扩展到明确引用的发布脚本、Gradle/描述符、聚焦测试、
指定构建报告和当前 ZIP；未遍历全仓或运行 `scan .`。远端仅查询本仓库元数据、
最近五个 CI、最近三个 Release 和一个明确材料路径。

本轮落盘范围为本记录、机器记录、对应证据目录，以及
`doc/EVOLUTION_ROADMAP.md`、`doc/RENAMING.md` 的当前入口与状态说明。
原有未提交的实现、工作流、历史验收和其他新增材料保持各自归属。
