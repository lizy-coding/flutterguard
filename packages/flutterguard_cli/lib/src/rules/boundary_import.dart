import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import '../config_loader.dart';
import '../static_issue.dart';

class BoundaryImportRule {
  final List<BoundaryConfig> boundaries;

  const BoundaryImportRule(this.boundaries);

  List<StaticIssue> analyze(List<String> files) {
    if (boundaries.isEmpty) return [];

    final issues = <StaticIssue>[];

    for (final file in files) {
      try {
        final content = File(file).readAsStringSync();
        final result = parseString(content: content, path: file);
        issues.addAll(_checkFile(file, result.unit));
      } catch (_) {}
    }

    return issues;
  }

  List<StaticIssue> _checkFile(String file, CompilationUnit unit) {
    final issues = <StaticIssue>[];
    final imports = unit.directives.whereType<ImportDirective>();

    for (final import in imports) {
      final importPath = import.uri.stringValue;
      if (importPath == null) continue;

      for (final boundary in boundaries) {
        if (!_matchesGlob(file, boundary.from)) continue;

        for (final forbiddenGlob in boundary.forbidden) {
          if (_importMatchesForbidden(importPath, file, forbiddenGlob)) {
            final line = unit.declarations.isNotEmpty
                ? null
                : null;

            issues.add(StaticIssue(
              id: 'boundary_import_violation',
              title: 'Boundary import violation',
              file: file,
              line: null,
              level: RiskLevel.high,
              message:
                  'Import "$importPath" from boundary "${boundary.name}" violates forbidden rule.',
              suggestion:
                  'Boundary "${boundary.name}" should not depend on "$forbiddenGlob". '
                  'Consider using dependency inversion or shared interfaces.',
              metadata: {
                'boundaryName': boundary.name,
                'imported': importPath,
              },
            ));
          }
        }
      }
    }

    return issues;
  }

  bool _matchesGlob(String filePath, String globPattern) {
    try {
      final glob = Glob(globPattern);
      return glob.matches(filePath);
    } catch (_) {
      return false;
    }
  }

  bool _importMatchesForbidden(
    String importPath,
    String sourceFile,
    String forbiddenPattern,
  ) {
    if (importPath.startsWith('package:')) {
      return _matchesGlob(importPath, forbiddenPattern);
    } else {
      final sourceDir = p.dirname(sourceFile);
      final resolved = p.normalize(p.join(sourceDir, importPath));
      final withDart = resolved.endsWith('.dart') ? resolved : '$resolved.dart';
      return _matchesGlob(resolved, forbiddenPattern) ||
          _matchesGlob(withDart, forbiddenPattern);
    }
  }
}
