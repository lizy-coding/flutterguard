import 'dart:io';
import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import 'path_utils.dart';

enum ScanDiagnosticSeverity { warning, error }

class ScanDiagnostic {
  final String stage;
  final String message;
  final String? file;
  final ScanDiagnosticSeverity severity;

  const ScanDiagnostic({
    required this.stage,
    required this.message,
    this.file,
    this.severity = ScanDiagnosticSeverity.warning,
  });

  Map<String, Object?> toJson() => {
        'stage': stage,
        'message': message,
        'file': file,
        'severity': severity.name,
      };
}

class SourceUnit {
  final String path;
  final String content;
  final List<String> lines;
  final CompilationUnit unit;
  final LineInfo lineInfo;

  const SourceUnit({
    required this.path,
    required this.content,
    required this.lines,
    required this.unit,
    required this.lineInfo,
  });
}

/// Per-scan source cache shared by every rule.
///
/// A source file is read and parsed at most once. Failures are retained as
/// diagnostics instead of being silently swallowed by each rule.
class SourceWorkspace {
  final Map<String, SourceUnit?> _sources = {};
  final List<ScanDiagnostic> _diagnostics = [];

  List<ScanDiagnostic> get diagnostics => List.unmodifiable(_diagnostics);

  SourceUnit? source(String filePath) {
    final path = normalizePath(filePath);
    if (_sources.containsKey(path)) return _sources[path];

    try {
      final content = File(path).readAsStringSync();
      final parsed = parseString(content: content, path: path);
      final source = SourceUnit(
        path: path,
        content: content,
        lines: const LineSplitter().convert(content),
        unit: parsed.unit,
        lineInfo: parsed.lineInfo,
      );
      _sources[path] = source;
      return source;
    } on FileSystemException catch (error) {
      _recordFailure(path, 'read', error.message);
    } on Object catch (error) {
      _recordFailure(path, 'parse', error.toString());
    }

    _sources[path] = null;
    return null;
  }

  void addDiagnostic(ScanDiagnostic diagnostic) {
    _diagnostics.add(diagnostic);
  }

  void _recordFailure(String path, String stage, String message) {
    _diagnostics.add(ScanDiagnostic(
      stage: stage,
      file: path,
      message: message,
      severity: ScanDiagnosticSeverity.error,
    ));
  }
}
