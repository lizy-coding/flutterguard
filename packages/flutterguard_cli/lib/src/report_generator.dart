import 'dart:convert';

import 'package:path/path.dart' as p;

import 'domain.dart';
import 'priority.dart';
import 'static_issue.dart';

class _Ansi {
  static const reset = '\x1b[0m';
  static const red = '\x1b[31m';
  static const green = '\x1b[32m';
  static const yellow = '\x1b[33m';
  static const gray = '\x1b[90m';
  static const bold = '\x1b[1m';
  static const dim = '\x1b[2m';
  static const orange = '\x1b[38;5;208m';
}

const _domainLabels = {
  IssueDomain.architecture: '架构违规',
  IssueDomain.performance: '性能问题',
  IssueDomain.standards: '代码规范',
};

const _domainAnsi = {
  IssueDomain.architecture: _Ansi.red,
  IssueDomain.performance: _Ansi.yellow,
  IssueDomain.standards: _Ansi.gray,
};

const _levelLabel = {
  RiskLevel.high: 'HIGH',
  RiskLevel.medium: 'MED ',
  RiskLevel.low: 'LOW ',
};

const _levelAnsi = {
  RiskLevel.high: _Ansi.red,
  RiskLevel.medium: _Ansi.yellow,
  RiskLevel.low: _Ansi.gray,
};

const _priorityLabel = {
  Priority.p0: 'P0 优先',
  Priority.p1: 'P1 关注',
  Priority.p2: 'P2 可选',
};

const _priorityAnsi = {
  Priority.p0: _Ansi.red,
  Priority.p1: _Ansi.yellow,
  Priority.p2: _Ansi.gray,
};

class ReportGenerator {
  static String generateJson({
    required String projectPath,
    required List<StaticIssue> issues,
  }) {
    final byDomain = _buildSummaryByDomain(issues);
    final score = _calculateScore(issues);

    final payload = {
      'version': '1.0.0',
      'generatedAt': DateTime.now().toIso8601String(),
      'projectPath': projectPath,
      'score': score,
      'summary': {
        'total': issues.length,
        'high': issues.where((i) => i.level == RiskLevel.high).length,
        'medium': issues.where((i) => i.level == RiskLevel.medium).length,
        'low': issues.where((i) => i.level == RiskLevel.low).length,
        'byDomain': byDomain,
      },
      'issues': issues.map((i) => i.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static String generateStdout({
    required String projectPath,
    required List<StaticIssue> issues,
    bool verbose = false,
  }) {
    final buf = StringBuffer();
    final score = _calculateScore(issues);
    final projectName = p.basename(projectPath);

    _writeHeader(buf, projectName, score, issues);

    if (issues.isEmpty) {
      buf.writeln(
          '  ${_Ansi.green}未发现问题，代码质量良好。${_Ansi.reset}');
      return buf.toString();
    }

    _writeDomainSummaryBar(buf, issues);

    for (final domain in IssueDomain.values) {
      final domainIssues = issues.where((i) => i.domain == domain).toList();
      if (domainIssues.isEmpty) continue;
      _writeDomainSection(buf, domain, domainIssues, verbose);
    }

    return buf.toString();
  }

  static void _writeHeader(
    StringBuffer buf,
    String projectName,
    int score,
    List<StaticIssue> issues,
  ) {
    final scoreAnsi = _scoreAnsi(score);
    final scoreLabel = score >= 80
        ? '优秀'
        : score >= 50
            ? '需关注'
            : '需整改';
    final fileCount =
        issues.map((i) => i.file).toSet().length;

    buf.writeln(
        ' ${_Ansi.bold}FlutterGuard Report${_Ansi.reset}  ${_Ansi.gray}─${_Ansi.reset}  $projectName');
    buf.writeln(
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.write(
        ' 总评分:  $scoreAnsi$score/100${_Ansi.reset}  $scoreAnsi$scoreLabel${_Ansi.reset}');
    buf.writeln(
        '      ${_Ansi.bold}文件总数: $fileCount${_Ansi.reset}  问题总数: ${_Ansi.bold}${issues.length}${_Ansi.reset}');
    buf.writeln(
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln();
  }

  static void _writeDomainSummaryBar(
    StringBuffer buf,
    List<StaticIssue> issues,
  ) {
    for (final domain in IssueDomain.values) {
      final domainIssues = issues.where((i) => i.domain == domain).toList();
      if (domainIssues.isEmpty) continue;

      final count = domainIssues.length;
      final maxLevel = domainIssues
          .map((i) => i.level)
          .reduce((a, b) => a.index > b.index ? a : b);
      final levelLabel = _levelLabel[maxLevel]!;
      final domainAnsi = _domainAnsi[domain]!;

      buf.write(
          '  $domainAnsi${_domainLabels[domain]}${_Ansi.reset}');
      buf.write('  $count items  ');
      buf.write('${_Ansi.gray}▰${_Ansi.reset}  ');
      buf.writeln(
          '${_levelAnsi[maxLevel]}$levelLabel${_Ansi.reset}');
    }
    buf.writeln(
        '────────────────────────────────────────────────────────────────────────────────────');
    buf.writeln();
  }

  static void _writeDomainSection(
    StringBuffer buf,
    IssueDomain domain,
    List<StaticIssue> issues,
    bool verbose,
  ) {
    final sorted = [...issues]
      ..sort((a, b) {
        final order = {
          RiskLevel.high: 0,
          RiskLevel.medium: 1,
          RiskLevel.low: 2,
        };
        return order[a.level]!.compareTo(order[b.level]!);
      });

    for (final issue in sorted) {
      final lvlAnsi = _levelAnsi[issue.level]!;
      final lvlLabel = _levelLabel[issue.level]!;
      final priAnsi = _priorityAnsi[issue.priority]!;
      final priLabel = _priorityLabel[issue.priority]!;
      final fileName = p.basename(issue.file);
      final relDir = _relativeDir(issue.file);
      final lineInfo = issue.line != null ? ':${issue.line}' : '';

      buf.writeln(
          '  $lvlAnsi$lvlLabel${_Ansi.reset} $priAnsi$priLabel${_Ansi.reset}');
      buf.writeln(
          '       ${_Ansi.bold}${issue.title}${_Ansi.reset}');
      buf.writeln(
          '       ${_Ansi.gray}$relDir/$fileName$lineInfo${_Ansi.reset}');
      buf.writeln('       ${issue.message}');

      if (verbose && issue.detail.isNotEmpty) {
        buf.writeln();
        for (final line in issue.detail.split('\n')) {
          buf.writeln('       ${_Ansi.dim}$line${_Ansi.reset}');
        }
      }
      buf.writeln(
          '       修复: ${_Ansi.green}${issue.suggestion}${_Ansi.reset}');
      buf.writeln();
    }
    buf.writeln(
        ' ────────────────────────────────────────────────────────────────────────────────');
    buf.writeln();
  }

  static String _relativeDir(String filePath) {
    final parts = filePath.split('/');
    if (parts.length < 2) return '.';
    return parts.sublist(0, parts.length - 1).join('/');
  }

  static Map<String, Map<String, int>> _buildSummaryByDomain(
      List<StaticIssue> issues) {
    final byDomain = <String, Map<String, int>>{};
    for (final domain in IssueDomain.values) {
      final domainIssues = issues.where((i) => i.domain == domain).toList();
      if (domainIssues.isEmpty) continue;
      byDomain[domain.name] = {
        'high': domainIssues.where((i) => i.level == RiskLevel.high).length,
        'medium': domainIssues.where((i) => i.level == RiskLevel.medium).length,
        'low': domainIssues.where((i) => i.level == RiskLevel.low).length,
        'total': domainIssues.length,
      };
    }
    return byDomain;
  }

  static int _calculateScore(List<StaticIssue> issues) {
    final high = issues.where((i) => i.level == RiskLevel.high).length;
    final medium = issues.where((i) => i.level == RiskLevel.medium).length;
    final low = issues.where((i) => i.level == RiskLevel.low).length;
    final score = 100 - high * 10 - medium * 4 - low * 1;
    return score.clamp(0, 100);
  }

  static bool shouldFail(List<StaticIssue> issues, String failOn) {
    final high = issues.where((i) => i.level == RiskLevel.high).length;
    final medium = issues.where((i) => i.level == RiskLevel.medium).length;
    final low = issues.where((i) => i.level == RiskLevel.low).length;

    switch (failOn) {
      case 'high':
        return high > 0;
      case 'medium':
        return high > 0 || medium > 0;
      case 'low':
        return high > 0 || medium > 0 || low > 0;
      default:
        return false;
    }
  }

  static String _scoreAnsi(int score) {
    if (score >= 80) return _Ansi.green;
    if (score >= 50) return _Ansi.orange;
    return _Ansi.red;
  }
}
