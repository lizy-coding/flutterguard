import 'dart:io';

import 'static_issue.dart';

class SuppressionFilter {
  final Map<String, Map<int, Set<String>>> _rulesByFileAndLine = {};

  SuppressionFilter(Iterable<String> files) {
    for (final file in files) {
      _rulesByFileAndLine[file] = _parseFile(file);
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

  static Map<int, Set<String>> _parseFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return const {};

    final result = <int, Set<String>>{};
    final lines = file.readAsLinesSync();
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
