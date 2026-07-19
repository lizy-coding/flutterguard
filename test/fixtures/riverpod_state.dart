import 'package:flutter_riverpod/flutter_riverpod.dart';

class Widget {
  Widget({Object? value, Object? onPressed, Object? onTap});
}

class BuildContext {}

class ConsumerWidget {
  Widget build(BuildContext context, dynamic ref) => Widget();
}

final deviceProvider = Provider((ref) => 1);

class DirectReadWidget extends ConsumerWidget {
  Widget build(BuildContext context, dynamic ref) {
    return Widget(value: ref.read(deviceProvider));
  }
}

class ConditionalReadWidget extends ConsumerWidget {
  Widget build(BuildContext context, dynamic ref) {
    final enabled = ref.read(deviceProvider);
    if (enabled) return Widget();
    return Widget();
  }
}

class SafeReadWidget extends ConsumerWidget {
  Widget build(BuildContext context, dynamic ref) {
    ref.read(deviceProvider.notifier).refresh();
    return Widget(onPressed: () => ref.read(deviceProvider));
  }
}

class WatchCallbackWidget extends ConsumerWidget {
  Widget build(BuildContext context, dynamic ref) {
    final value = ref.watch(deviceProvider);
    return Widget(
      value: value,
      onPressed: () => ref.watch(deviceProvider),
      onTap: () async {
        ref.watch(deviceProvider);
      },
    );
  }
}
