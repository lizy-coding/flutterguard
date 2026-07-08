import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'static_issue.dart';

class Baseline {
  final Set<String> fingerprints;

  const Baseline(this.fingerprints);

  static String fingerprint(StaticIssue issue, String projectPath) {
    final relativePath =
        p.isWithin(projectPath, issue.file) || p.equals(projectPath, issue.file)
            ? p.relative(issue.file, from: projectPath)
            : issue.file;
    final normalizedPath = relativePath.replaceAll('\\', '/');
    final source = [
      issue.id,
      normalizedPath,
      issue.line ?? 1,
      issue.message,
    ].join('|');
    return _stableHash(source);
  }

  bool contains(StaticIssue issue, String projectPath) {
    return fingerprints.contains(fingerprint(issue, projectPath));
  }

  static Baseline load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FormatException('Baseline file "$path" does not exist.');
    }

    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Baseline file must be a JSON object.');
    }
    final fingerprints = decoded['fingerprints'];
    if (fingerprints is! List) {
      throw const FormatException(
        'Baseline file must contain a fingerprints list.',
      );
    }

    return Baseline(fingerprints.map((v) => v.toString()).toSet());
  }

  static String encode({
    required String projectPath,
    required List<StaticIssue> issues,
  }) {
    final fingerprints = issues
        .map((issue) => fingerprint(issue, projectPath))
        .toSet()
        .toList()
      ..sort();

    final payload = {
      'version': '1.0.0',
      'generatedAt': DateTime.now().toIso8601String(),
      'projectPath': projectPath,
      'issueCount': issues.length,
      'fingerprints': fingerprints,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }
}

String _stableHash(String source) {
  var hash = 2166136261;
  for (final codeUnit in utf8.encode(source)) {
    hash ^= codeUnit;
    hash = (hash * 16777619) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
