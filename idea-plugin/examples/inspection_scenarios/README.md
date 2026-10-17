# IDEA 截图场景

这是独立的 Dart 示例项目，代码只用于编辑器检查，不需要运行应用、连接设备或修改业务仓库。
先重启 IDEA 加载最新 BoundaryLens，再打开本目录的项目和下列文件。

每次截图前：保存文件 → **Tools → BoundaryLens: Scan Current Saved File**。
告警截图请将鼠标停在对应行上，让 ruleId 和建议一起出现；无告警截图请包含扫描完成通知。
只保留菜单操作后的最新通知，避免把其他文件的通知混入截图。

| 场景 | 文件 | 预期 | 建议截图 |
|---|---|---|---|
| 1. Timer 未释放 | `lib/scenario_01_timer_leak.dart` | medium，字段第 6 行 | 黄色标注和 tooltip |
| 2. Timer 正确释放 | `lib/scenario_02_timer_fixed.dart` | 0 findings | dispose 与完成通知 |
| 3. 泛型 nullable 订阅未释放 | `lib/scenario_03_stream_leak.dart` | medium，字段第 5 行 | 黄色标注和 tooltip |
| 4. 委托清理 | `lib/scenario_04_delegated_cleanup.dart` | 0 findings | dispose/helper 与完成通知 |
| 5. 单次任务 | `lib/scenario_05_one_shot_valid.dart` | 0 findings | init 与完成通知 |
| 6. 显式抑制 | `lib/scenario_06_suppressed.dart` | 0 findings | ignore 注释与完成通知 |
| 7. 演示凭据 | `lib/scenario_07_demo_secret.dart` | high，第 3 行 | 红色标注和 tooltip |
| 8. 非法依赖 | `lib/presentation/scenario_08_bad_boundary.dart` | high，import 第 2 行 | 红色标注和 tooltip |
| 9. 合法依赖 | `lib/presentation/scenario_09_good_boundary.dart` | 0 findings | import 与完成通知 |
| 10. 配置错误 | `setup_failure/lib/setup_failure.dart` | 扫描失败 | 文件级告警和失败通知 |

场景 10 自带独立 pubspec 和错误配置，不会影响前 9 个场景。
所有红/黄色告警都来自真实 CLI finding，没有在 IDE 里伪造结果。
`expected-report.json` 保存正常项目的预期规则、行号和 severity：合计 4 条可见 finding，
2 high、2 medium，1 条显式抑制，0 diagnostics。场景 10 的预期为 exit 2。

首次反馈先给场景 **1、2、7、10** 的截图即可。如果体验异常，也可以直接发你看到的菜单、
通知或 Settings → Tools → BoundaryLens，不需要再解释代码。
