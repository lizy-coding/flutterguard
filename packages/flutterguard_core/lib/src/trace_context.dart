import 'dart:async';

class TraceContext {
  static const String _keyName = 'flutter_guard_trace_id';

  static String? get currentTraceId {
    try {
      return Zone.current[_keyName] as String?;
    } on TypeError {
      return null;
    }
  }

  static R runWithTraceId<R>(
    String? traceId,
    R Function() body,
  ) {
    if (traceId == null) return body();
    return runZoned(
      body,
      zoneValues: {_keyName: traceId},
    );
  }

  static Future<R> runGuardedWithTraceId<R>(
    String? traceId,
    Future<R> Function() body, {
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    if (traceId == null) return body();
    return runZonedGuarded(
      body,
      onError ?? (_, __) {},
      zoneValues: {_keyName: traceId},
    );
  }
}
