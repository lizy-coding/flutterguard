import 'dart:async';

// 场景 4：合法委托清理。dispose 调用本类 helper，预期 0 findings。
class DelegatedCleanupScenario {
  StreamSubscription<int>? _subscription;

  bool get isListening => _subscription != null;

  void init() {
    _subscription = const Stream<int>.empty().listen((_) {});
  }

  void dispose() {
    _release();
  }

  void _release() {
    _subscription?.cancel();
  }
}
