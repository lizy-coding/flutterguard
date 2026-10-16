# 模块公开入口保护：最小验收项目

配置将 checkout 与 payment 分成两个模块，允许 checkout 依赖 payment，
但 payment 仅通过 payment.dart 对外暴露。入口可以 export 本模块内部文件。

1. 在 IDEA 打开本目录，启用 Dart 支持并配置 SDK。
2. 保存并扫描 lib/checkout/bad.dart：第 1 行应出现 module_violation，说明绕过公开入口。
3. 保存并扫描 lib/checkout/good.dart：没有该违规；coverage 为 complete、scope 为 file。
4. 从任一 Dart 文件执行 Tools → FlutterGuard: Scan Current Dart Package：
   完整只读报告显示 scope=project、4/4 files、1 finding，来源是 bad.dart。
5. 将 bad.dart 的引用改为 ../payment/payment.dart，再扫描整个包：0 findings。
6. 恢复文件；移除 payment 的 entry_points，结果必须显示 partial，不能表示入口保护通过。

expected-report.json 是未修改输入的验收摘要，不是自动生成的扫描报告。
此示例只验证文件级模块入口，不验证业务行为、符号级 API 泄漏或外部包依赖正确性。
