import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../priority.dart';
import '../rule_meta.dart';
import '../source_utils.dart';
import '../static_issue.dart';

final _widgetTypes = <String>{'StatelessWidget', 'StatefulWidget'};

class MissingConstConstructorRule {
  final MissingConstConstructorRuleConfig config;

  const MissingConstConstructorRule(this.config);

  List<StaticIssue> analyze(List<String> files) {
    if (!config.enabled) return [];

    final issues = <StaticIssue>[];

    for (final file in files) {
      try {
        final content = File(file).readAsStringSync();
        final result = parseString(content: content, path: file);
        issues.addAll(_checkFile(file, result.unit, result.lineInfo));
      } catch (_) {}
    }

    return issues;
  }

  List<StaticIssue> _checkFile(
    String file,
    CompilationUnit unit,
    LineInfo lineInfo,
  ) {
    final issues = <StaticIssue>[];
    final classes = unit.declarations.whereType<ClassDeclaration>();

    for (final cls in classes) {
      final extendsClause = cls.extendsClause;
      if (extendsClause == null) continue;

      final superClassName = extendsClause.superclass.name2.lexeme;
      if (!_widgetTypes.contains(superClassName)) {
        continue;
      }

      final hasConstConstructor = cls.members.any((m) {
        if (m is ConstructorDeclaration) {
          return m.constKeyword != null;
        }
        return false;
      });

      if (hasConstConstructor) continue;

      final line = lineNumberForOffset(lineInfo, cls.name.offset);
      issues.add(StaticIssue(
        id: 'missing_const_constructor',
        title: 'Widget 缺少 const 构造函数',
        file: file,
        line: line,
        level: RiskLevel.low,
        domain: IssueDomain.standards,
        priority: Priority.p2,
        message: '"${cls.name.lexeme}" 是 $superClassName 子类但缺少 const 构造函数',
        detail: '类: ${cls.name.lexeme}\n超类: $superClassName',
        suggestion: '添加 const 构造函数: "const ${cls.name.lexeme}({super.key});"',
        metadata: {
          'className': cls.name.lexeme,
          'superClass': superClassName,
        },
      ));
    }

    return issues;
  }

  static RuleMeta describe() => const RuleMeta(
        id: 'missing_const_constructor',
        name: '缺少 const 构造函数',
        domain: 'standards',
        riskLevel: 'low',
        priority: 'p2',
        purpose: '检测 Widget 子类是否缺少 const 构造函数',
        riskReason: '缺少 const 构造函数导致 widget 无法复用实例，影响渲染性能',
        badExample:
            'class MyWidget extends StatelessWidget { ... } 无 const 构造函数',
        fixSuggestion: '为 Widget 类添加 const 构造函数',
        cicdSafe: true,
      );
}
