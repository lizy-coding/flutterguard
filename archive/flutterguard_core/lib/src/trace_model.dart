import 'dart:math';

enum FlowStatus { running, success, failed }

class SpanTrace {
  final String id;
  final String flowId;
  final String name;
  final DateTime startTime;
  DateTime? endTime;
  final Map<String, Object?> tags;
  String? errorType;
  String? errorMessage;
  String? stackTrace;

  SpanTrace({
    required this.id,
    required this.flowId,
    required this.name,
    required this.startTime,
    this.endTime,
    Map<String, Object?>? tags,
    this.errorType,
    this.errorMessage,
    this.stackTrace,
  }) : tags = tags ?? {};

  int get durationMs {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inMilliseconds;
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'flowId': flowId,
        'name': name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationMs': durationMs,
        'tags': tags,
        'errorType': errorType,
        'errorMessage': errorMessage,
        'stackTrace': stackTrace,
      };
}

class NetworkTrace {
  final String? flowId;
  final String method;
  final String path;
  final int? statusCode;
  final int durationMs;
  final int? requestSize;
  final int? responseSize;
  final bool success;
  final String? errorType;
  final String? errorMessage;

  NetworkTrace({
    this.flowId,
    required this.method,
    required this.path,
    this.statusCode,
    required this.durationMs,
    this.requestSize,
    this.responseSize,
    required this.success,
    this.errorType,
    this.errorMessage,
  });

  Map<String, Object?> toJson() => {
        'flowId': flowId,
        'method': method,
        'path': path,
        'statusCode': statusCode,
        'durationMs': durationMs,
        'requestSize': requestSize,
        'responseSize': responseSize,
        'success': success,
        'errorType': errorType,
        'errorMessage': errorMessage,
      };
}

class RouteTrace {
  final String? flowId;
  final String type;
  final String? from;
  final String? to;
  final DateTime time;

  RouteTrace({
    this.flowId,
    required this.type,
    this.from,
    this.to,
    required this.time,
  });

  Map<String, Object?> toJson() => {
        'flowId': flowId,
        'type': type,
        'from': from,
        'to': to,
        'time': time.toIso8601String(),
      };
}

class ErrorTrace {
  final String? flowId;
  final String errorType;
  final String message;
  final String? stackTrace;
  final DateTime time;
  final String? route;

  ErrorTrace({
    this.flowId,
    required this.errorType,
    required this.message,
    this.stackTrace,
    required this.time,
    this.route,
  });

  Map<String, Object?> toJson() => {
        'flowId': flowId,
        'errorType': errorType,
        'message': message,
        'stackTrace': stackTrace,
        'time': time.toIso8601String(),
        'route': route,
      };
}

class FrameTrace {
  final String? flowId;
  final int totalSpanMs;
  final int buildDurationMs;
  final int rasterDurationMs;
  final bool janky;
  final DateTime time;

  FrameTrace({
    this.flowId,
    required this.totalSpanMs,
    required this.buildDurationMs,
    required this.rasterDurationMs,
    required this.janky,
    required this.time,
  });

  Map<String, Object?> toJson() => {
        'flowId': flowId,
        'totalSpanMs': totalSpanMs,
        'buildDurationMs': buildDurationMs,
        'rasterDurationMs': rasterDurationMs,
        'janky': janky,
        'time': time.toIso8601String(),
      };
}

class FlowTrace {
  final String id;
  final String name;
  final DateTime startTime;
  DateTime? endTime;
  final Map<String, Object?> tags;
  final List<SpanTrace> spans;
  final List<NetworkTrace> networks;
  final List<RouteTrace> routes;
  final List<ErrorTrace> errors;
  final List<FrameTrace> frames;
  final Map<String, int> buildCounts;
  FlowStatus status;

  FlowTrace({
    required this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    Map<String, Object?>? tags,
    List<SpanTrace>? spans,
    List<NetworkTrace>? networks,
    List<RouteTrace>? routes,
    List<ErrorTrace>? errors,
    List<FrameTrace>? frames,
    Map<String, int>? buildCounts,
    this.status = FlowStatus.running,
  })  : tags = tags ?? {},
        spans = spans ?? [],
        networks = networks ?? [],
        routes = routes ?? [],
        errors = errors ?? [],
        frames = frames ?? [],
        buildCounts = buildCounts ?? {};

  int get durationMs {
    final end = endTime ?? DateTime.now();
    return max(0, end.difference(startTime).inMilliseconds);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'durationMs': durationMs,
        'tags': tags,
        'status': status.name,
        'spans': spans.map((s) => s.toJson()).toList(),
        'networks': networks.map((n) => n.toJson()).toList(),
        'routes': routes.map((r) => r.toJson()).toList(),
        'errors': errors.map((e) => e.toJson()).toList(),
        'frames': frames.map((f) => f.toJson()).toList(),
        'buildCounts': buildCounts,
      };
}
