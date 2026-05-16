import 'dart:convert';

import 'static_issue.dart';

class ReportGenerator {
  static String generateJson({
    required String projectPath,
    required List<StaticIssue> issues,
  }) {
    final summary = _buildSummary(issues);
    final score = _calculateScore(issues);

    final payload = {
      'version': '1.0.0',
      'generatedAt': DateTime.now().toIso8601String(),
      'projectPath': projectPath,
      'score': score,
      'summary': {
        'high': summary.high,
        'medium': summary.medium,
        'low': summary.low,
        'total': issues.length,
      },
      'staticIssues': issues.map((i) => i.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static String generateMarkdown({
    required String projectPath,
    required List<StaticIssue> issues,
    String? runtimeTracesJson,
  }) {
    final buf = StringBuffer();
    final score = _calculateScore(issues);
    final summary = _buildSummary(issues);

    buf.writeln('# FlutterGuard Flow Report');
    buf.writeln();
    buf.writeln('**Project**: $projectPath');
    buf.writeln('**Generated**: ${DateTime.now().toIso8601String()}');
    buf.writeln('**Score**: $score / 100');
    buf.writeln();

    buf.writeln('## Summary');
    buf.writeln();
    buf.writeln('| Level | Count |');
    buf.writeln('|-------|-------|');
    buf.writeln('| High | ${summary.high} |');
    buf.writeln('| Medium | ${summary.medium} |');
    buf.writeln('| Low | ${summary.low} |');
    buf.writeln('| **Total** | **${issues.length}** |');
    buf.writeln();

    if (issues.isEmpty) {
      buf.writeln('*No static issues found.*');
      return buf.toString();
    }

    final highIssues = issues.where((i) => i.level == RiskLevel.high).toList();
    final mediumIssues =
        issues.where((i) => i.level == RiskLevel.medium).toList();
    final lowIssues = issues.where((i) => i.level == RiskLevel.low).toList();

    buf.writeln('## Static Issues');
    buf.writeln();

    if (highIssues.isNotEmpty) {
      buf.writeln('### High');
      buf.writeln();
      _writeIssueTable(buf, highIssues);
    }

    if (mediumIssues.isNotEmpty) {
      buf.writeln('### Medium');
      buf.writeln();
      _writeIssueTable(buf, mediumIssues);
    }

    if (lowIssues.isNotEmpty) {
      buf.writeln('### Low');
      buf.writeln();
      _writeIssueTable(buf, lowIssues);
    }

    if (runtimeTracesJson != null && runtimeTracesJson.isNotEmpty) {
      buf.writeln('## Runtime Flows');
      buf.writeln();
      buf.writeln('```json');
      buf.writeln(runtimeTracesJson);
      buf.writeln('```');
      buf.writeln();
    }

    buf.writeln('## CI Result');
    buf.writeln();
    if (summary.high > 0) {
      buf.writeln('**FAIL**: ${{summary.high}} high-severity issues found.');
    } else if (summary.medium > 0) {
      buf.writeln(
          '**WARNING**: ${{summary.medium}} medium-severity issues found.');
    } else {
      buf.writeln('**PASS**: No high or medium severity issues.');
    }
    buf.writeln();

    return buf.toString();
  }

  static void _writeIssueTable(StringBuffer buf, List<StaticIssue> issues) {
    buf.writeln('| ID | File | Message | Suggestion |');
    buf.writeln('|----|------|---------|------------|');
    for (final issue in issues) {
      final fileShort = issue.file.split('/').last;
      buf.writeln(
          '| ${issue.id} | $fileShort (L${issue.line ?? "?"}) | ${issue.message} | ${issue.suggestion} |');
    }
    buf.writeln();
  }

  static ({int high, int medium, int low}) _buildSummary(
      List<StaticIssue> issues) {
    return (
      high: issues.where((i) => i.level == RiskLevel.high).length,
      medium: issues.where((i) => i.level == RiskLevel.medium).length,
      low: issues.where((i) => i.level == RiskLevel.low).length,
    );
  }

  static int _calculateScore(List<StaticIssue> issues) {
    final summary = _buildSummary(issues);
    var score = 100 - summary.high * 10 - summary.medium * 4 - summary.low * 1;
    return score.clamp(0, 100);
  }

  static bool shouldFail(List<StaticIssue> issues, String failOn) {
    final summary = _buildSummary(issues);
    switch (failOn) {
      case 'high':
        return summary.high > 0;
      case 'medium':
        return summary.high > 0 || summary.medium > 0;
      case 'low':
        return summary.high > 0 || summary.medium > 0 || summary.low > 0;
      default:
        return false;
    }
  }
}
