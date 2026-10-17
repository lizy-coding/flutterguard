# BoundaryLens 模块场景人工截图清单

首发平台：macOS Apple Silicon。使用 examples/module_boundary，配置示例自己的
Dart SDK；不使用 Forge 业务源码。安装最终候选后由发布者人工截图，不合成告警画面。

1. bad.dart 编辑器＋Problems：第1行 module_violation，说明绕过 payment 公开入口。
2. 当前包报告：1 finding、0 diagnostics、scope=project、4/4 文件，展示来源路径和修复建议。
3. 将 bad.dart 导入改为 ../payment/payment.dart，保存重扫：0 findings，仍显示本次覆盖范围。
4. 省略 payment.entry_points 后重扫：partial 与 entry_points_not_declared。
5. 无效规则参数：显示扫描失败、exit2 与字段名，不能截成零发现。
6. 使用指南与更新记录：新名称、模块入口说明和本轮版本记录，段落正常换行。

完成后恢复 bad.dart 和配置；现有 expected-report.json 不改。
截图避开操控悬浮图标、账户/试用入口及无关通知，保留可读字号和必要上下文。
五张旧图仍可作为辅助规则历史示例，不作为当前模块入口保护的证据。
