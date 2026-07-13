import 'dart:io';

import 'source_workspace.dart';
import 'static_issue.dart';

class SuppressionFilter {
  final Map<String, Map<int, Set<String>>> _rulesByFileAndLine = {};

  SuppressionFilter(
    Iterable<String> files, {
    SourceWorkspace? workspace,
  }) {
    for (final file in files) {
      _rulesByFileAndLine[file] = _parseFile(file, workspace: workspace);
    }
  }

  bool isSuppressed(StaticIssue issue) {
    final line = issue.line;
    if (line == null) return false;
    final byLine = _rulesByFileAndLine[issue.file];
    if (byLine == null) return false;
    final rules = byLine[line];
    if (rules == null) return false;
    return rules.contains('all') || rules.contains(issue.id);
  }

  static Map<int, Set<String>> _parseFile(
    String path, {
    SourceWorkspace? workspace,
  }) {
    final List<String> lines;
    if (workspace == null) {
      final file = File(path);
      if (!file.existsSync()) return const {};
      lines = file.readAsLinesSync();
    } else {
      final source = workspace.source(path);
      if (source == null) return const {};
      lines = source.lines;
    }

    final result = <int, Set<String>>{};
    for (var index = 0; index < lines.length; index++) {
      final parsed = _parseLine(lines[index]);
      if (parsed == null) continue;
      final lineNumber = index + 1;
      result.putIfAbsent(lineNumber, () => <String>{}).addAll(parsed);
      result.putIfAbsent(lineNumber + 1, () => <String>{}).addAll(parsed);
    }
    return result;
  }

  static Set<String>? _parseLine(String line) {
    final match = RegExp(r'flutterguard:\s*ignore\s+([A-Za-z0-9_,\s-]+)')
        .firstMatch(line);
    if (match == null) return null;
    final raw = match.group(1) ?? '';
    final ids = raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return null;
    return ids;
  }
}
