import 'dart:async';

// 场景 3：应该告警。泛型 + nullable 订阅仍需 cancel。
class StreamLeakScenario {
  StreamSubscription<int>? _subscription;

  bool get isListening => _subscription != null;

  void init() {
    _subscription = const Stream<int>.empty().listen((_) {});
  }
}
