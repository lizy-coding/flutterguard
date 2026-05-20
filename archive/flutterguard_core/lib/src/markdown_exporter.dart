import 'trace_model.dart';

class MarkdownExporter {
  static String export(List<FlowTrace> traces) {
    final buf = StringBuffer();

    buf.writeln('# FlutterGuard Flow Report');
    buf.writeln();
    buf.writeln('## Summary');
    buf.writeln();
    final total = traces.length;
    final success = traces.where((t) => t.status == FlowStatus.success).length;
    final failed = traces.where((t) => t.status == FlowStatus.failed).length;
    buf.writeln('| Metric | Count |');
    buf.writeln('|--------|-------|');
    buf.writeln('| Total Flows | $total |');
    buf.writeln('| Success | $success |');
    buf.writeln('| Failed | $failed |');
    buf.writeln();

    if (traces.isEmpty) {
      buf.writeln('*No flows recorded.*');
      return buf.toString();
    }

    buf.writeln('## Runtime Flows');
    buf.writeln();
    for (final trace in traces) {
      buf.writeln('### ${trace.name} `${trace.id}`');
      buf.writeln();
      buf.writeln('- **Status**: ${trace.status.name}');
      buf.writeln('- **Duration**: ${trace.durationMs}ms');
      buf.writeln('- **Started**: ${trace.startTime.toIso8601String()}');
      if (trace.endTime != null) {
        buf.writeln('- **Ended**: ${trace.endTime!.toIso8601String()}');
      }
      buf.writeln();

      if (trace.spans.isNotEmpty) {
        buf.writeln('#### Spans');
        buf.writeln();
        buf.writeln('| Name | Duration | Error |');
        buf.writeln('|------|----------|-------|');
        for (final span in trace.spans) {
          final error = span.errorType ?? '-';
          buf.writeln('| ${span.name} | ${span.durationMs}ms | $error |');
        }
        buf.writeln();
      }

      if (trace.networks.isNotEmpty) {
        buf.writeln('#### Network');
        buf.writeln();
        buf.writeln('| Method | Path | Status | Duration |');
        buf.writeln('|--------|------|--------|----------|');
        for (final net in trace.networks) {
          buf.writeln(
              '| ${net.method} | ${net.path} | ${net.statusCode ?? '-'} | ${net.durationMs}ms |');
        }
        buf.writeln();
      }

      if (trace.routes.isNotEmpty) {
        buf.writeln('#### Routes');
        buf.writeln();
        buf.writeln('| Type | From | To |');
        buf.writeln('|------|------|----|');
        for (final route in trace.routes) {
          buf.writeln(
              '| ${route.type} | ${route.from ?? '-'} | ${route.to ?? '-'} |');
        }
        buf.writeln();
      }

      if (trace.errors.isNotEmpty) {
        buf.writeln('#### Errors');
        buf.writeln();
        for (final error in trace.errors) {
          buf.writeln('- **${error.errorType}**: ${error.message}');
          if (error.stackTrace != null) {
            buf.writeln('  ```');
            buf.writeln('  ${error.stackTrace}');
            buf.writeln('  ```');
          }
        }
        buf.writeln();
      }

      if (trace.frames.isNotEmpty) {
        buf.writeln('#### Frames');
        buf.writeln();
        buf.writeln('| Total | Build | Raster | Janky |');
        buf.writeln('|-------|-------|--------|-------|');
        for (final frame in trace.frames) {
          buf.writeln(
              '| ${frame.totalSpanMs}ms | ${frame.buildDurationMs}ms | ${frame.rasterDurationMs}ms | ${frame.janky} |');
        }
        buf.writeln();
      }

      if (trace.buildCounts.isNotEmpty) {
        buf.writeln('#### Build Boundaries');
        buf.writeln();
        for (final entry in trace.buildCounts.entries) {
          buf.writeln('- **${entry.key}**: ${entry.value} rebuilds');
        }
        buf.writeln();
      }

      buf.writeln('---');
      buf.writeln();
    }

    return buf.toString();
  }
}
