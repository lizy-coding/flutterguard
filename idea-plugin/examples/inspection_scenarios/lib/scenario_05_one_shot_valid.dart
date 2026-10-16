import 'dart:async';

// 场景 5：单次异步任务，没有需释放的持有资源，预期 0 findings。
// init 方法本身不强制要求 dispose；勿为了配对添加空方法。
class OneShotScenario {
  bool _scheduled = false;

  void init() {
    if (_scheduled) return;
    _scheduled = true;
    unawaited(Future<void>.microtask(() {}));
  }
}
