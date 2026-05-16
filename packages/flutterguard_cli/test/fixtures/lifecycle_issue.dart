// ignore_for_file: unused_field, inference_failure_on_instance_creation
import 'dart:async';

// Fixture: lifecycle resource not disposed
class LifecycleIssueWidget {
  late StreamSubscription _subscription;
  late Timer _timer;

  LifecycleIssueWidget() {
    _subscription = const Stream.empty().listen((_) {});
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {});
  }

  void dispose() {
    // _subscription.cancel() is missing
    // _timer.cancel() is missing
  }
}
