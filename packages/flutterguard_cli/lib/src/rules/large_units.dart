import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../config_loader.dart';
import '../domain.dart';
import '../priority.dart';
import '../static_issue.dart';

class LargeUnitsRule {
  final LargeFileRuleConfig largeFileConfig;
  final LargeClassRuleConfig largeClassConfig;
  final LargeBuildMethodRuleConfig largeBuildMethodConfig;

  const LargeUnitsRule({
    required this.largeFileConfig,
    required this.largeClassConfig,
    required this.largeBuildMethodConfig,
  });

  List<StaticIssue> analyze(List<String> files) {
    final issues = <StaticIssue>[];

    for (final file in files) {
      if (largeFileConfig.enabled) {
        issues.addAll(_checkLargeFile(file));
      }

      if (largeClassConfig.enabled || largeBuildMethodConfig.enabled) {
        try {
          final content = File(file).readAsStringSync();
          final result = parseString(content: content, path: file);
          if (largeClassConfig.enabled) {
            issues.addAll(_checkLargeClass(file, content, result.unit));
          }
          if (largeBuildMethodConfig.enabled) {
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
      if (lines.length > largeFileConfig.maxLines) {
        return [
          StaticIssue(
            id: 'large_file',
            title: '文件过大',
            file: file,
            line: null,
            level: RiskLevel.low,
            domain: IssueDomain.standards,
            priority: Priority.p2,
            message:
                '文件 ${lines.length} 行（阈值: ${largeFileConfig.maxLines} 行）',
            detail: '',
            suggestion:
                '建议将 ${p.basename(file)} 拆分为更小的模块文件',
            metadata: {
              'actual': lines.length,
              'threshold': largeFileConfig.maxLines,
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

      if (lineCount > largeClassConfig.maxLines) {
        issues.add(StaticIssue(
          id: 'large_class',
          title: '类过大',
          file: file,
          line: startLine,
          level: RiskLevel.low,
          domain: IssueDomain.standards,
          priority: Priority.p2,
          message:
              '类 "${cls.name.lexeme}" $lineCount 行（阈值: ${largeClassConfig.maxLines} 行）',
          detail: '',
          suggestion:
              '建议将 "${cls.name.lexeme}" 的职责提取到更小的类中',
          metadata: {
            'actual': lineCount,
            'threshold': largeClassConfig.maxLines,
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

          if (lineCount > largeBuildMethodConfig.maxLines) {
            issues.add(StaticIssue(
              id: 'large_build_method',
              title: '构建方法过长',
              file: file,
              line: startLine,
              level: RiskLevel.medium,
              domain: IssueDomain.performance,
              priority: Priority.p1,
              message:
                  '${cls.name.lexeme}.build() $lineCount 行（阈值: ${largeBuildMethodConfig.maxLines} 行）',
              detail: '',
              suggestion:
                  '将 build 方法中的部分提取为更小的子组件或方法',
              metadata: {
                'actual': lineCount,
                'threshold': largeBuildMethodConfig.maxLines,
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
