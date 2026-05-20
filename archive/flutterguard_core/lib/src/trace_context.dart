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

  static Future<T> runWithTraceId<T>(
    String? traceId,
    FutureOr<T> Function() body,
  ) async {
    if (traceId == null) {
      final result = body();
      if (result is Future<T>) return result;
      return result;
    }
    return runZoned(() async {
      final result = body();
      if (result is Future<T>) return await result;
      return result;
    }, zoneValues: {_keyName: traceId});
  }
}
