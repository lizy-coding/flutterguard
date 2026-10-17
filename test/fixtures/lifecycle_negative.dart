// ignore_for_file: unused_field, inference_failure_on_instance_creation
import 'dart:async';

class OverlayEntry {}

class StreamController<T> {}

// Fixture: lifecycle resources properly disposed
class LifecycleOkWidget {
  late StreamSubscription _subscription;
  late Timer _timer;
  late OverlayEntry _overlayEntry;

  LifecycleOkWidget() {
    _subscription = const Stream.empty().listen((_) {});
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {});
    _overlayEntry = OverlayEntry();
  }

  void dispose() {
    _subscription.cancel();
    _timer.cancel();
    _overlayEntry.remove();
  }
}
