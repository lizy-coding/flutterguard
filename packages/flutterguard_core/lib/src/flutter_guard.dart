import 'dart:async';
import 'dart:math';

import 'guard_config.dart';
import 'trace_context.dart';
import 'trace_model.dart';
import 'trace_store.dart';
import 'json_exporter.dart';
import 'markdown_exporter.dart';

class FlutterGuard {
  static FlutterGuardConfig _config = const FlutterGuardConfig();
  static final Random _random = Random();

  static void configure(FlutterGuardConfig config) {
    _config = config;
    TraceStore.instance.configure(maxTraces: config.maxTraces);
  }

  static String? get currentTraceId => TraceContext.currentTraceId;

  static Future<T> action<T>(
    String name,
    FutureOr<T> Function() body, {
    Map<String, Object?> tags = const {},
  }) async {
    if (!_config.enabled) return body();

    final traceId = _generateId();
    final trace = FlowTrace(
      id: traceId,
      name: name,
      startTime: DateTime.now(),
      tags: Map.unmodifiable({
        ...tags,
        'traceId': traceId,
      }),
    );

    TraceStore.instance.beginFlow(trace);

    bool failed = false;
    T result;

    try {
      result = await TraceContext.runWithTraceId<T>(traceId, () async {
        return await Future.value(body());
      });
    } catch (e, st) {
      failed = true;
      trace.errors.add(ErrorTrace(
        flowId: traceId,
        errorType: e.runtimeType.toString(),
        message: e.toString(),
        stackTrace: st.toString(),
        time: DateTime.now(),
      ));
      trace.status = FlowStatus.failed;
      rethrow;
    } finally {
      if (!failed) {
        TraceStore.instance.endFlow(traceId, failed: false);
      } else {
        trace.endTime = DateTime.now();
      }
    }

    return result;
  }

  static Future<T> span<T>(
    String name,
    FutureOr<T> Function() body, {
    Map<String, Object?> tags = const {},
  }) async {
    if (!_config.enabled) return body();

    final flowId = TraceContext.currentTraceId;
    if (flowId == null) return body();

    final span = SpanTrace(
      id: _generateId(),
      flowId: flowId,
      name: name,
      startTime: DateTime.now(),
      tags: tags,
    );

    TraceStore.instance.addSpanToActive(flowId, span);

    try {
      final result = await Future.value(body());
      span.endTime = DateTime.now();
      return result;
    } catch (e, st) {
      span.endTime = DateTime.now();
      span.errorType = e.runtimeType.toString();
      span.errorMessage = e.toString();
      span.stackTrace = st.toString();
      TraceStore.instance.addErrorToActive(
        flowId,
        ErrorTrace(
          flowId: flowId,
          errorType: e.runtimeType.toString(),
          message: e.toString(),
          stackTrace: st.toString(),
          time: DateTime.now(),
        ),
      );
      rethrow;
    }
  }

  static void recordNetwork(NetworkTrace trace) {
    if (!_config.enabled) return;
    final flowId = trace.flowId ?? TraceContext.currentTraceId;
    TraceStore.instance.addNetworkToActive(flowId, trace);
  }

  static void recordRoute(RouteTrace trace) {
    if (!_config.enabled || !_config.collectRoutes) return;
    final flowId = trace.flowId ?? TraceContext.currentTraceId;
    TraceStore.instance.addRouteToActive(flowId, trace);
  }

  static void recordError(ErrorTrace trace) {
    if (!_config.enabled || !_config.collectErrors) return;
    final flowId = trace.flowId ?? TraceContext.currentTraceId;
    TraceStore.instance.addErrorToActive(flowId, trace);
  }

  static void recordFrame(FrameTrace trace) {
    if (!_config.enabled || !_config.collectFrames) return;
    final flowId = trace.flowId ?? TraceContext.currentTraceId;
    TraceStore.instance.addFrameToActive(flowId, trace);
  }

  static void recordBuild(String boundaryName) {
    if (!_config.enabled || !_config.collectBuilds) return;
    TraceStore.instance.recordBuild(TraceContext.currentTraceId, boundaryName);
  }

  static String exportJson() {
    final traces = TraceStore.instance.getAllTraces();
    return JsonExporter.export(traces);
  }

  static String exportMarkdown() {
    final traces = TraceStore.instance.getAllTraces();
    return MarkdownExporter.export(traces);
  }

  static void reset() {
    TraceStore.instance.reset();
  }

  static String _generateId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .substring(0, 12);
  }
}
