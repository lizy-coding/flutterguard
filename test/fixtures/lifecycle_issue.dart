// ignore_for_file: unused_field, inference_failure_on_instance_creation
import 'dart:async';

class OverlayEntry {}

// Fixture: lifecycle resource not disposed
class LifecycleIssueWidget {
  late StreamSubscription _subscription;
  late Timer _timer;
  late OverlayEntry _overlayEntry;

  LifecycleIssueWidget() {
    _subscription = const Stream.empty().listen((_) {});
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {});
    _overlayEntry = OverlayEntry();
  }

  void dispose() {
    // _subscription.cancel() is missing
    // _timer.cancel() is missing
    // _overlayEntry.remove() is missing
  }
}
