import 'trace_model.dart';

class TraceStore {
  TraceStore._();

  static final TraceStore instance = TraceStore._();

  final Map<String, FlowTrace> _activeTraces = {};
  final List<FlowTrace> _completedTraces = [];
  int _maxTraces = 100;

  void configure({required int maxTraces}) {
    _maxTraces = maxTraces;
  }

  FlowTrace beginFlow(FlowTrace trace) {
    _activeTraces[trace.id] = trace;
    return trace;
  }

  FlowTrace? endFlow(String traceId, {required bool failed}) {
    final trace = _activeTraces.remove(traceId);
    if (trace == null) return null;
    trace.endTime = DateTime.now();
    trace.status = failed ? FlowStatus.failed : FlowStatus.success;
    _completedTraces.add(trace);
    while (_completedTraces.length > _maxTraces) {
      _completedTraces.removeAt(0);
    }
    return trace;
  }

  FlowTrace? getActiveTrace(String traceId) {
    return _activeTraces[traceId];
  }

  List<FlowTrace> get completedTraces => List.unmodifiable(_completedTraces);

  void addSpanToActive(String traceId, SpanTrace span) {
    final trace = _activeTraces[traceId];
    if (trace != null) {
      trace.spans.add(span);
    }
  }

  void addNetworkToActive(String? traceId, NetworkTrace network) {
    if (traceId == null) return;
    final trace = _activeTraces[traceId] ?? _getLatestCompleted(traceId);
    trace?.networks.add(network);
  }

  void addRouteToActive(String? traceId, RouteTrace route) {
    if (traceId == null) return;
    final trace = _activeTraces[traceId] ?? _getLatestCompleted(traceId);
    trace?.routes.add(route);
  }

  void addErrorToActive(String? traceId, ErrorTrace error) {
    if (traceId == null) return;
    final trace = _activeTraces[traceId] ?? _getLatestCompleted(traceId);
    trace?.errors.add(error);
    if (trace != null && _activeTraces.containsKey(traceId)) {
      trace.status = FlowStatus.failed;
    }
  }

  void addFrameToActive(String? traceId, FrameTrace frame) {
    if (traceId == null) return;
    final trace = _activeTraces[traceId] ?? _getLatestCompleted(traceId);
    trace?.frames.add(frame);
  }

  void recordBuild(String? traceId, String boundaryName) {
    if (traceId == null) return;
    final trace = _activeTraces[traceId] ?? _getLatestCompleted(traceId);
    if (trace != null) {
      trace.buildCounts[boundaryName] =
          (trace.buildCounts[boundaryName] ?? 0) + 1;
    }
  }

  FlowTrace? _getLatestCompleted(String traceId) {
    for (var i = _completedTraces.length - 1; i >= 0; i--) {
      if (_completedTraces[i].id == traceId) return _completedTraces[i];
    }
    return null;
  }

  List<FlowTrace> getAllTraces() {
    return [..._activeTraces.values, ..._completedTraces];
  }

  void reset() {
    _activeTraces.clear();
    _completedTraces.clear();
  }
}
