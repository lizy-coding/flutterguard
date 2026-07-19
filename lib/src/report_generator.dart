import 'dart:convert';

import 'package:path/path.dart' as p;

import 'source_workspace.dart';
import 'static_issue.dart';

class _Ansi {
  static const reset = '\x1B[0m';
  static const red = '\x1B[31m';
  static const yellow = '\x1B[33m';
  static const gray = '\x1B[90m';
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';
  static const green = '\x1B[32m';
}

const _domainLabels = {
  IssueDomain.architecture: '架构与安全',
  IssueDomain.performance: '生命周期与性能',
  IssueDomain.standards: '工程标准',
};

const _levelLabels = {
  RiskLevel.high: 'HIGH',
  RiskLevel.medium: 'MEDIUM',
  RiskLevel.low: 'LOW',
};

class ReportGenerator {
  static String generateJson({
    required String projectPath,
    required List<StaticIssue> issues,
    required String scanMode,
    int suppressedCount = 0,
    int suppressedByBaselineCount = 0,
    List<ScanDiagnostic> diagnostics = const [],
  }) {
    final payload = <String, Object?>{
      'schemaVersion': '2.0.0',
      'projectPath': projectPath,
      'scanMode': scanMode,
      'summary': {
        'total': issues.length,
        'high': issues.where((issue) => issue.level == RiskLevel.high).length,
        'medium': issues
            .where((issue) => issue.level == RiskLevel.medium)
            .length,
        'low': issues.where((issue) => issue.level == RiskLevel.low).length,
        'suppressed': suppressedCount,
        'suppressedByBaseline': suppressedByBaselineCount,
        'diagnostics': diagnostics.length,
        'byDomain': _summaryByDomain(issues),
      },
      'issues': issues.map((issue) => issue.toJson()).toList(),
      'diagnostics': diagnostics.map((item) => item.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static String generateStdout({
    required String projectPath,
    required List<StaticIssue> issues,
    int? scannedFileCount,
    bool verbose = false,
    bool noColor = false,
  }) {
    final buffer = StringBuffer();
    final bold = noColor ? '' : _Ansi.bold;
    final reset = noColor ? '' : _Ansi.reset;
    buffer
      ..writeln('$bold FlutterGuard Report$reset — ${p.basename(projectPath)}')
      ..writeln(
        ' Files: ${scannedFileCount ?? issues.map((issue) => issue.file).toSet().length}  '
        'Issues: ${issues.length}',
      );
    if (issues.isEmpty) {
      buffer.writeln(' No issues found.');
      return buffer.toString();
    }

    for (final domain in IssueDomain.values) {
      final domainIssues = issues
          .where((issue) => issue.domain == domain)
          .toList();
      if (domainIssues.isEmpty) continue;
      buffer
        ..writeln()
        ..writeln('${_domainLabels[domain]} (${domainIssues.length})');
      domainIssues.sort(
        (a, b) => _severityOrder(a).compareTo(_severityOrder(b)),
      );
      for (final issue in domainIssues) {
        _writeIssue(
          buffer,
          issue,
          projectPath,
          verbose: verbose,
          noColor: noColor,
        );
      }
    }
    return buffer.toString();
  }

  static bool shouldFail(List<StaticIssue> issues, String failOn) {
    final threshold = switch (failOn) {
      'high' => 2,
      'medium' => 1,
      'low' => 0,
      _ => 3,
    };
    return issues.any((issue) => issue.level.index >= threshold);
  }

  static void _writeIssue(
    StringBuffer buffer,
    StaticIssue issue,
    String projectPath, {
    required bool verbose,
    required bool noColor,
  }) {
    final color = noColor
        ? ''
        : switch (issue.level) {
            RiskLevel.high => _Ansi.red,
            RiskLevel.medium => _Ansi.yellow,
            RiskLevel.low => _Ansi.gray,
          };
    final reset = noColor ? '' : _Ansi.reset;
    final bold = noColor ? '' : _Ansi.bold;
    final dim = noColor ? '' : _Ansi.dim;
    final green = noColor ? '' : _Ansi.green;
    final path = p.isWithin(projectPath, issue.file)
        ? p.relative(issue.file, from: projectPath)
        : issue.file;
    final line = issue.line == null ? '' : ':${issue.line}';
    buffer
      ..writeln('  $color${_levelLabels[issue.level]}$reset ${issue.id}')
      ..writeln('    $bold${issue.title}$reset')
      ..writeln('    $path$line — ${issue.message}');
    if (verbose && issue.detail.isNotEmpty) {
      for (final detail in issue.detail.split('\n')) {
        buffer.writeln('    $dim$detail$reset');
      }
    }
    if (verbose) {
      for (final evidence in issue.evidence.take(5)) {
        buffer.writeln('    $dim evidence: $evidence$reset');
      }
    }
    buffer.writeln('    $green fix: ${issue.suggestion}$reset');
  }

  static int _severityOrder(StaticIssue issue) => switch (issue.level) {
    RiskLevel.high => 0,
    RiskLevel.medium => 1,
    RiskLevel.low => 2,
  };

  static Map<String, Map<String, int>> _summaryByDomain(
    List<StaticIssue> issues,
  ) {
    final result = <String, Map<String, int>>{};
    for (final domain in IssueDomain.values) {
      final values = issues.where((issue) => issue.domain == domain).toList();
      if (values.isEmpty) continue;
      result[domain.name] = {
        'high': values.where((issue) => issue.level == RiskLevel.high).length,
        'medium': values
            .where((issue) => issue.level == RiskLevel.medium)
            .length,
        'low': values.where((issue) => issue.level == RiskLevel.low).length,
        'total': values.length,
      };
    }
    return result;
  }
}
