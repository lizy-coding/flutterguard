import 'dart:convert';

import 'package:path/path.dart' as p;

import 'static_issue.dart';

class _Ansi {
  static const reset = '\x1b[0m';
  static const red = '\x1b[31m';
  static const green = '\x1b[32m';
  static const yellow = '\x1b[33m';
  static const cyan = '\x1b[36m';
  static const gray = '\x1b[90m';
  static const bold = '\x1b[1m';
  static const dim = '\x1b[2m';
}

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

  /// Colorized terminal output with module grouping and module-level scores.
  static String generateStdout({
    required String projectPath,
    required List<StaticIssue> issues,
    String groupBy = 'module',
    bool showModuleScore = true,
    int? top,
  }) {
    final buf = StringBuffer();
    final score = _calculateScore(issues);
    final summary = _buildSummary(issues);

    final projectName = p.basename(projectPath);

    buf.writeln(
        '${_Ansi.bold}FlutterGuard Report${_Ansi.reset}  ${_Ansi.gray}$projectName${_Ansi.reset}');
    buf.writeln(
        '${_Ansi.bold}Score:${_Ansi.reset} ${_scoreAnsi(score)}$score/100${_Ansi.reset}  '
        '${_Ansi.red}High: ${summary.high}${_Ansi.reset}  '
        '${_Ansi.yellow}Medium: ${summary.medium}${_Ansi.reset}  '
        '${_Ansi.gray}Low: ${summary.low}${_Ansi.reset}  '
        'Total: ${issues.length}');
    buf.writeln();

    if (issues.isEmpty) {
      buf.writeln('${_Ansi.green}No issues found.${_Ansi.reset}');
      return buf.toString();
    }

    if (groupBy == 'module') {
      _writeModuleGrouped(buf, projectPath, issues, showModuleScore, top);
    } else {
      _writeSeverityGrouped(buf, issues);
    }

    return buf.toString();
  }

  static void _writeModuleGrouped(
    StringBuffer buf,
    String projectPath,
    List<StaticIssue> issues,
    bool showModuleScore,
    int? top,
  ) {
    final groups = <String, List<StaticIssue>>{};
    for (final issue in issues) {
      final rel = p.relative(issue.file, from: projectPath);
      final key = _moduleKey(rel);
      groups.putIfAbsent(key, () => []).add(issue);
    }

    var sorted = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    if (top != null && top > 0) {
      sorted = sorted.take(top).toList();
    }

    for (final entry in sorted) {
      final groupIssues = entry.value;
      final groupScore = _calculateScore(groupIssues);
      final high = groupIssues.where((i) => i.level == RiskLevel.high).length;
      final med = groupIssues.where((i) => i.level == RiskLevel.medium).length;

      buf.writeln(
          '${_Ansi.cyan}${_Ansi.bold}═══ ${entry.key}${_Ansi.reset}'
          '${showModuleScore ? ' ${_Ansi.gray}(Score: ${_scoreAnsi(groupScore)}$groupScore${_Ansi.gray})${_Ansi.reset}' : ''}'
          '${_Ansi.dim}  ${high > 0 ? '${_Ansi.reset}${_Ansi.red}H:$high${_Ansi.reset}${_Ansi.dim} ' : ''}'
          '${med > 0 ? 'M:$med' : ''}${_Ansi.reset}');

      for (final issue in groupIssues) {
        final rel = p.relative(issue.file, from: projectPath);
        final fileName = rel.split('/').last;
        final badge = _severityBadge(issue.level);
        final line = issue.line != null ? 'L${issue.line}' : '';

        buf.writeln(
            '  $badge ${_Ansi.bold}${issue.id}${_Ansi.reset}  '
            '${_Ansi.gray}$fileName${line.isNotEmpty ? ':$line' : ''}${_Ansi.reset}  '
            '${issue.message}');
      }
      buf.writeln();
    }
  }

  static void _writeSeverityGrouped(
    StringBuffer buf,
    List<StaticIssue> issues,
  ) {
    final highIssues =
        issues.where((i) => i.level == RiskLevel.high).toList();
    final mediumIssues =
        issues.where((i) => i.level == RiskLevel.medium).toList();
    final lowIssues = issues.where((i) => i.level == RiskLevel.low).toList();

    void writeGroup(List<StaticIssue> group) {
      for (final issue in group) {
        final badge = _severityBadge(issue.level);
        final line = issue.line != null ? 'L${issue.line}' : '';
        final fileName = issue.file.split('/').last;
        buf.writeln(
            '  $badge ${_Ansi.bold}${issue.id}${_Ansi.reset}  '
            '${_Ansi.gray}$fileName${line.isNotEmpty ? ':$line' : ''}${_Ansi.reset}  '
            '${issue.message}');
      }
    }

    if (highIssues.isNotEmpty) {
      buf.writeln('${_Ansi.red}${_Ansi.bold}═══ High ═══${_Ansi.reset}');
      writeGroup(highIssues);
      buf.writeln();
    }
    if (mediumIssues.isNotEmpty) {
      buf.writeln('${_Ansi.yellow}${_Ansi.bold}═══ Medium ═══${_Ansi.reset}');
      writeGroup(mediumIssues);
      buf.writeln();
    }
    if (lowIssues.isNotEmpty) {
      buf.writeln('${_Ansi.gray}${_Ansi.bold}═══ Low ═══${_Ansi.reset}');
      writeGroup(lowIssues);
      buf.writeln();
    }
  }

  static String _moduleKey(String relativePath) {
    final modulesMatch =
        RegExp(r'modules/[^/]+/([^/]+)').firstMatch(relativePath);
    if (modulesMatch != null) return modulesMatch.group(1)!;
    final parts = relativePath.split('/');
    return parts.length >= 2 ? parts[parts.length - 2] : '(root)';
  }

  static String _severityBadge(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return '${_Ansi.red}${_Ansi.bold}[HIGH]${_Ansi.reset}';
      case RiskLevel.medium:
        return '${_Ansi.yellow}[MED ]${_Ansi.reset}';
      case RiskLevel.low:
        return '${_Ansi.gray}[LOW ]${_Ansi.reset}';
    }
  }

  static String _scoreAnsi(int score) {
    if (score >= 80) return _Ansi.green;
    if (score >= 50) return _Ansi.yellow;
    return _Ansi.red;
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
    final score =
        100 - summary.high * 10 - summary.medium * 4 - summary.low * 1;
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
