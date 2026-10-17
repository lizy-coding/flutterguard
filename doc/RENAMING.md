# FlutterGuard → BoundaryLens

2026-10-16：公开产品名改为 BoundaryLens，定位为项目声明的模块边界与公开入口检查。
这是本地源码和安装包迁移，不代表新名称已获 Marketplace、pub.dev 或商标登记。
公开检索存在其他领域的同名软件，例如 [环境筛查产品](https://boundarylens.com/)
与 [地理数据项目](https://github.com/NeelakshSaxena/BoundaryLens)，名称不主张独占。

| 对象 | 新身份 |
|---|---|
| 项目/IDEA 展示名 | BoundaryLens |
| Dart 包 / CLI | boundarylens_cli / boundarylens |
| Dart 入口 | bin/boundarylens.dart；lib/boundarylens_cli.dart 仍不导出 scanner API |
| IDEA ID / Kotlin package | com.boundarylens |
| IDEA ZIP | boundarylens-idea-0.7.1.zip（本地迭代） |
| 配置 / 输出 | boundarylens.yaml / .boundarylens/ |
| Kotlin 编译器环境变量 | BOUNDARYLENS_KOTLIN_VERSION |

GitHub origin 继续使用 git@github.com:lizy-coding/flutterguard.git，网页、Issues、
Release 的实际 URL 不变；本地工作目录仍为 /Users/forest/code/flutterguard。
未重命名远端仓库或移动工作目录，也未提交、推送、发布或接受协议。

2026-10-17 续评已重新核对包、CLI、插件 ID、ZIP 描述符和唯一的 macOS ARM64
native，43 项更名及相关 CLI/模块/规则契约测试通过。当前发布状态和产物指纹见
[发布计划续评](../idea-plugin/release-review/2026-10-17-release-plan-review.md)。
本地身份迁移完成；仓库地址、工作目录迁移和名称登记没有由此自动完成。

## 已有项目迁移

1. 新 CLI 名称为 boundarylens；从源码本地激活或编译，不假称 pub.dev 已可安装。
2. 默认优先 boundarylens.yaml；不存在时兼容 flutterguard.yaml；显式 --config 优先且
   缺失时仍报错，不偷偷回退。两份配置不会合并。config init 只创建新名称。
3. 新抑制注释使用 // boundarylens: ignore <rule-id>；旧 // flutterguard: ignore 继续有效。
4. ruleId、severity、domain、JSON 2.0、SARIF 2.1 与 baseline 身份规则不变。
   旧 baseline 可通过 --baseline 指定；旧报告目录不自动搬迁。
5. IDEA 新 ID 与 com.flutterguard 是不同插件。安装前停用旧 FlutterGuard，
   避免双重检查；BoundaryLens 项目开关独立，不自动篡改旧插件设置。
6. 本地旧 ZIP/native 仍是旧品牌产物，新包必须由新入口重编译。正式发布前独立验收
   IDE 声明范围、OS 二进制集合及 Plugin Verifier。

旧版权声明、第三方 notices、已日期化审查/ADR/指纹和历史截图保留原文，
不批量改成新名称冒充新验收。活跃指南、构建脚本、示例和测试使用新名称。
