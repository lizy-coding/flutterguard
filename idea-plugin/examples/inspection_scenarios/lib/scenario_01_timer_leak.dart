import 'dart:async';

// 场景 1：应该出现黄色告警。Timer 在 init 中创建，却没有释放。
// 截图：把鼠标停在 _timer 字段上，展示 ruleId 和修复建议。
class TimerLeakScenario {
  Timer? _timer;

  bool get isRunning => _timer?.isActive ?? false;

  void init() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {});
  }
}
