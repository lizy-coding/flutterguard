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
    String scanMode = 'full',
    int suppressedCount = 0,
    int suppressedByBaselineCount = 0,
  }) {
    final byDomain = _buildSummaryByDomain(issues);
    final score = calculateScore(issues);

    final payload = {
      'version': '1.0.0',
      'generatedAt': DateTime.now().toIso8601String(),
      'projectPath': projectPath,
      'scanMode': scanMode,
      'score': score,
      'summary': {
        'total': issues.length,
        'high': issues.where((i) => i.level == RiskLevel.high).length,
        'medium': issues.where((i) => i.level == RiskLevel.medium).length,
        'low': issues.where((i) => i.level == RiskLevel.low).length,
        'suppressed': suppressedCount,
        'suppressedByBaseline': suppressedByBaselineCount,
        'byDomain': byDomain,
      },
      'issues': issues.map((i) => i.toJson()).toList(),
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
    final buf = StringBuffer();
    final score = calculateScore(issues);
    final projectName = p.basename(projectPath);

    _writeHeader(
      buf,
      projectName,
      score,
      issues,
      scannedFileCount ?? issues.map((i) => i.file).toSet().length,
      noColor: noColor,
    );

    if (issues.isEmpty) {
      final msg = noColor
          ? '未发现问题，代码质量良好。'
          : '${_Ansi.green}未发现问题，代码质量良好。${_Ansi.reset}';
      buf.writeln('  $msg');
      return buf.toString();
    }

    _writeDomainSummaryBar(buf, issues, noColor: noColor);

    for (final domain in IssueDomain.values) {
      final domainIssues = issues.where((i) => i.domain == domain).toList();
      if (domainIssues.isEmpty) continue;
      _writeDomainSection(
        buf,
        projectPath,
        domain,
        domainIssues,
        verbose,
        noColor: noColor,
      );
    }

    return buf.toString();
  }

  static void _writeHeader(
    StringBuffer buf,
    String projectName,
    int score,
    List<StaticIssue> issues,
    int scannedFileCount, {
    bool noColor = false,
  }) {
    final scoreAnsi = noColor ? '' : _scoreAnsi(score);
    final reset = noColor ? '' : _Ansi.reset;
    final gray = noColor ? '' : _Ansi.gray;
    final bold = noColor ? '' : _Ansi.bold;
    final scoreLabel = score >= 80
        ? '优秀'
        : score >= 50
            ? '需关注'
            : '需整改';
    buf.writeln(
        ' ${bold}FlutterGuard Report$reset  $gray─$reset  $projectName');
    buf.writeln(
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.write(' 总评分:  $scoreAnsi$score/100$reset  $scoreAnsi$scoreLabel$reset');
    buf.writeln(
        '      $bold扫描文件: $scannedFileCount$reset  问题总数: $bold${issues.length}$reset');
    buf.writeln(
        '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buf.writeln();
  }

  static void _writeDomainSummaryBar(
    StringBuffer buf,
    List<StaticIssue> issues, {
    bool noColor = false,
  }) {
    final reset = noColor ? '' : _Ansi.reset;
    final gray = noColor ? '' : _Ansi.gray;
    for (final domain in IssueDomain.values) {
      final domainIssues = issues.where((i) => i.domain == domain).toList();
      if (domainIssues.isEmpty) continue;

      final count = domainIssues.length;
      final maxLevel = domainIssues
          .map((i) => i.level)
          .reduce((a, b) => a.index > b.index ? a : b);
      final levelLabel = _levelLabel[maxLevel]!;
      final domainAnsi = noColor ? '' : _domainAnsi[domain]!;
      final levelAnsi = noColor ? '' : _levelAnsi[maxLevel]!;

      buf.write('  $domainAnsi${_domainLabels[domain]}$reset');
      buf.write('  $count items  ');
      buf.write('$gray▰$reset  ');
      buf.writeln('$levelAnsi$levelLabel$reset');
    }
    buf.writeln(
        '────────────────────────────────────────────────────────────────────────────────────');
    buf.writeln();
  }

  static void _writeDomainSection(
    StringBuffer buf,
    String projectPath,
    IssueDomain domain,
    List<StaticIssue> issues,
    bool verbose, {
    bool noColor = false,
  }) {
    final sorted = [...issues]..sort((a, b) {
        final order = {
          RiskLevel.high: 0,
          RiskLevel.medium: 1,
          RiskLevel.low: 2,
        };
        return order[a.level]!.compareTo(order[b.level]!);
      });

    final reset = noColor ? '' : _Ansi.reset;
    final gray = noColor ? '' : _Ansi.gray;
    final bold = noColor ? '' : _Ansi.bold;
    final dim = noColor ? '' : _Ansi.dim;
    final green = noColor ? '' : _Ansi.green;

    for (final issue in sorted) {
      final lvlAnsi = noColor ? '' : _levelAnsi[issue.level]!;
      final lvlLabel = _levelLabel[issue.level]!;
      final priAnsi = noColor ? '' : _priorityAnsi[issue.priority]!;
      final priLabel = _priorityLabel[issue.priority]!;
      final displayPath = _displayPath(issue.file, projectPath);
      final lineInfo = issue.line != null ? ':${issue.line}' : '';

      buf.writeln('  $lvlAnsi$lvlLabel$reset $priAnsi$priLabel$reset');
      buf.writeln('       $bold${issue.title}$reset');
      buf.writeln('       $gray$displayPath$lineInfo$reset');
      buf.writeln('       ${issue.message}');

      if (verbose && issue.detail.isNotEmpty) {
        buf.writeln();
        for (final line in issue.detail.split('\n')) {
          buf.writeln('       $dim$line$reset');
        }
      }
      buf.writeln('       修复: $green${issue.suggestion}$reset');
      buf.writeln();
    }
    buf.writeln(
        ' ────────────────────────────────────────────────────────────────────────────────');
    buf.writeln();
  }

  static String _displayPath(String filePath, String projectPath) {
    if (p.isWithin(projectPath, filePath) || p.equals(projectPath, filePath)) {
      return p.relative(filePath, from: projectPath);
    }
    return filePath;
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

  static int calculateScore(List<StaticIssue> issues) {
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
