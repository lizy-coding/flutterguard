import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'baseline.dart';
import 'rules/registry.dart';
import 'static_issue.dart';

class IssueExporter {
  static String export({
    required String projectPath,
    required List<StaticIssue> issues,
    String? ruleId,
    String? filePath,
    int? line,
    int contextLines = 2,
  }) {
    final issue = _findIssue(
      projectPath: projectPath,
      issues: issues,
      ruleId: ruleId,
      filePath: filePath,
      line: line,
    );
    if (issue == null) {
      throw const FormatException('No matching issue found to export.');
    }

    final relativePath = _relativePath(issue.file, projectPath);
    final meta = RuleRegistry.find(issue.id);
    final payload = {
      'version': '1.0.0',
      'generatedAt': DateTime.now().toIso8601String(),
      'projectPath': projectPath,
      'fingerprint': Baseline.fingerprint(issue, projectPath),
      'issue': issue.toJson()..['file'] = relativePath,
      'rule': meta?.toJson(),
      'context': _context(issue, contextLines),
      'feedbackTemplate': {
        'whyFalsePositiveOrFalseNegative': '',
        'expectedBehavior': '',
        'sanitizedSnippetConfirmed': false,
      },
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static StaticIssue? _findIssue({
    required String projectPath,
    required List<StaticIssue> issues,
    String? ruleId,
    String? filePath,
    int? line,
  }) {
    final normalizedFile = filePath == null
        ? null
        : p.normalize(
            p.isAbsolute(filePath) ? filePath : p.join(projectPath, filePath));

    for (final issue in issues) {
      if (ruleId != null && issue.id != ruleId) continue;
      if (line != null && issue.line != line) continue;
      if (normalizedFile != null && p.normalize(issue.file) != normalizedFile) {
        continue;
      }
      return issue;
    }
    return null;
  }

  static Map<String, Object?> _context(StaticIssue issue, int contextLines) {
    final line = issue.line;
    final file = File(issue.file);
    if (line == null || !file.existsSync()) {
      return {
        'available': false,
        'lines': const [],
      };
    }

    final lines = file.readAsLinesSync();
    final start = (line - contextLines).clamp(1, lines.length);
    final end = (line + contextLines).clamp(1, lines.length);
    return {
      'available': true,
      'startLine': start,
      'endLine': end,
      'lines': [
        for (var i = start; i <= end; i++)
          {
            'line': i,
            'text': lines[i - 1],
          }
      ],
    };
  }

  static String _relativePath(String filePath, String projectPath) {
    if (p.isWithin(projectPath, filePath) || p.equals(projectPath, filePath)) {
      return p.relative(filePath, from: projectPath).replaceAll('\\', '/');
    }
    return filePath.replaceAll('\\', '/');
  }
}
