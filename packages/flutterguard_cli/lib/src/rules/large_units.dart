import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../config_loader.dart';
import '../static_issue.dart';

class LargeUnitsRule {
  final RulesConfig config;

  const LargeUnitsRule(this.config);

  List<StaticIssue> analyze(List<String> files) {
    final issues = <StaticIssue>[];

    for (final file in files) {
      if (config.largeFile.enabled) {
        issues.addAll(_checkLargeFile(file));
      }

      if (config.largeClass.enabled || config.largeBuildMethod.enabled) {
        try {
          final content = File(file).readAsStringSync();
          final result = parseString(content: content, path: file);
          if (config.largeClass.enabled) {
            issues.addAll(_checkLargeClass(file, content, result.unit));
          }
          if (config.largeBuildMethod.enabled) {
            issues.addAll(_checkLargeBuild(file, content, result.unit));
          }
        } catch (_) {}
      }
    }

    return issues;
  }

  List<StaticIssue> _checkLargeFile(String file) {
    try {
      final lines = File(file).readAsLinesSync();
      if (lines.length > config.largeFile.maxLines) {
        return [
          StaticIssue(
            id: 'large_file',
            title: 'Large file detected',
            file: file,
            line: null,
            level: RiskLevel.medium,
            message:
                'File has ${lines.length} lines (threshold: ${config.largeFile.maxLines})',
            suggestion:
                'Consider splitting ${p.basename(file)} into smaller modules.',
            metadata: {
              'actual': lines.length,
              'threshold': config.largeFile.maxLines,
            },
          ),
        ];
      }
    } catch (_) {}
    return [];
  }

  List<StaticIssue> _checkLargeClass(
    String file,
    String content,
    CompilationUnit unit,
  ) {
    final issues = <StaticIssue>[];
    final classes = unit.declarations.whereType<ClassDeclaration>();

    for (final cls in classes) {
      final startLine = content.substring(0, cls.offset).split('\n').length;
      final endLine = content.substring(0, cls.end).split('\n').length;
      final lineCount = endLine - startLine + 1;

      if (lineCount > config.largeClass.maxLines) {
        issues.add(StaticIssue(
          id: 'large_class',
          title: 'Large class detected',
          file: file,
          line: startLine,
          level: RiskLevel.medium,
          message:
              'Class "${cls.name.lexeme}" has $lineCount lines (threshold: ${config.largeClass.maxLines})',
          suggestion:
              'Consider extracting responsibilities from "${cls.name.lexeme}" into smaller classes.',
          metadata: {
            'actual': lineCount,
            'threshold': config.largeClass.maxLines,
            'className': cls.name.lexeme,
          },
        ));
      }
    }
    return issues;
  }

  List<StaticIssue> _checkLargeBuild(
    String file,
    String content,
    CompilationUnit unit,
  ) {
    final issues = <StaticIssue>[];
    final classes = unit.declarations.whereType<ClassDeclaration>();

    for (final cls in classes) {
      for (final member in cls.members) {
        if (member is MethodDeclaration &&
            member.name.lexeme == 'build' &&
            member.returnType?.toString() == 'Widget') {
          final startLine =
              content.substring(0, member.offset).split('\n').length;
          final endLine = content.substring(0, member.end).split('\n').length;
          final lineCount = endLine - startLine + 1;

          if (lineCount > config.largeBuildMethod.maxLines) {
            issues.add(StaticIssue(
              id: 'large_build_method',
              title: 'Large build method detected',
              file: file,
              line: startLine,
              level: RiskLevel.medium,
              message:
                  'build() method in "${cls.name.lexeme}" has $lineCount lines (threshold: ${config.largeBuildMethod.maxLines})',
              suggestion:
                  'Extract parts of the build method into smaller helper widgets or methods.',
              metadata: {
                'actual': lineCount,
                'threshold': config.largeBuildMethod.maxLines,
                'className': cls.name.lexeme,
              },
            ));
          }
        }
      }
    }
    return issues;
  }
}
