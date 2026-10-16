import 'dart:async';

// 场景 2：正确修复，同样创建 Timer，但 dispose 中释放。预期 0 findings。
class TimerFixedScenario {
  Timer? _timer;

  bool get isRunning => _timer?.isActive ?? false;

  void init() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {});
  }

  void dispose() {
    _timer?.cancel();
  }
}
