import 'dart:convert';

import 'trace_model.dart';

class JsonExporter {
  static const String version = '1.0.0';

  static String export(List<FlowTrace> traces) {
    final summary = _buildSummary(traces);
    final payload = {
      'version': version,
      'generatedAt': DateTime.now().toIso8601String(),
      'summary': summary,
      'traces': traces.map((t) => t.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Map<String, int> _buildSummary(List<FlowTrace> traces) {
    final total = traces.length;
    final success = traces.where((t) => t.status == FlowStatus.success).length;
    final failed = traces.where((t) => t.status == FlowStatus.failed).length;
    final running = traces.where((t) => t.status == FlowStatus.running).length;
    return {'total': total, 'success': success, 'failed': failed, 'running': running};
  }
}
