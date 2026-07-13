import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../config_loader.dart';
import '../domain.dart';
import '../priority.dart';
import '../rule_meta.dart';
import '../source_workspace.dart';
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

  List<StaticIssue> analyze(
    List<String> files, {
    SourceWorkspace? workspace,
  }) {
    final issues = <StaticIssue>[];
    final sources = workspace ?? SourceWorkspace();

    for (final file in files) {
      final source = sources.source(file);
      if (source == null) continue;
      if (largeFileConfig.enabled) {
        issues.addAll(_checkLargeFile(file, source.lines.length));
      }

      if (largeClassConfig.enabled || largeBuildMethodConfig.enabled) {
        if (largeClassConfig.enabled) {
          issues.addAll(_checkLargeClass(file, source.content, source.unit));
        }
        if (largeBuildMethodConfig.enabled) {
          issues.addAll(_checkLargeBuild(file, source.content, source.unit));
        }
      }
    }

    return issues;
  }

  List<StaticIssue> _checkLargeFile(String file, int lineCount) {
    if (lineCount > largeFileConfig.maxLines) {
      return [
        StaticIssue(
          id: 'large_file',
          title: '文件过大',
          file: file,
          line: null,
          level: RiskLevel.low,
          domain: IssueDomain.standards,
          priority: Priority.p2,
          message: '文件 $lineCount 行（阈值: ${largeFileConfig.maxLines} 行）',
          detail: '',
          suggestion: '建议将 ${p.basename(file)} 拆分为更小的模块文件',
          metadata: {
            'actual': lineCount,
            'threshold': largeFileConfig.maxLines,
          },
        ),
      ];
    }
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
          suggestion: '建议将 "${cls.name.lexeme}" 的职责提取到更小的类中',
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
              suggestion: '将 build 方法中的部分提取为更小的子组件或方法',
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

  static RuleMeta describeLargeFile() => const RuleMeta(
        id: 'large_file',
        name: '文件过大',
        domain: 'standards',
        riskLevel: 'low',
        priority: 'p2',
        purpose: '检测单文件行数超过阈值',
        riskReason: '文件过大增加认知负载，难以维护和审查',
        badExample: '500+ 行的单文件包含多个不相关类',
        fixSuggestion: '将逻辑独立的类或函数提取到单独文件',
        configKeys: ['rules.large_file.maxLines'],
        cicdSafe: true,
      );

  static RuleMeta describeLargeClass() => const RuleMeta(
        id: 'large_class',
        name: '类过大',
        domain: 'standards',
        riskLevel: 'low',
        priority: 'p2',
        purpose: '检测类声明行数超过阈值',
        riskReason: '大类违反单一职责原则，降低可测试性',
        badExample: '300+ 行的类处理多种不相关逻辑',
        fixSuggestion: '将类按职责拆分为多个更小的类',
        configKeys: ['rules.large_class.maxLines'],
        cicdSafe: true,
      );

  static RuleMeta describeLargeBuildMethod() => const RuleMeta(
        id: 'large_build_method',
        name: '构建方法过长',
        domain: 'performance',
        riskLevel: 'medium',
        priority: 'p1',
        purpose: '检测 Widget build 方法行数超过阈值',
        riskReason: '过长的 build 方法难以维护，且可能包含重复渲染逻辑',
        badExample: '80+ 行的 build 方法包含内联样式和嵌套 widget',
        fixSuggestion: '将 build 中的子 UI 提取为独立 widget 或方法',
        configKeys: ['rules.large_build_method.maxLines'],
        cicdSafe: true,
      );
}
