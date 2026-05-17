import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../priority.dart';
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
        issues.addAll(_checkFile(file, result.unit));
      } catch (_) {}
    }

    return issues;
  }

  List<StaticIssue> _checkFile(String file, CompilationUnit unit) {
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

      final line = cls.name.offset;
      issues.add(StaticIssue(
        id: 'missing_const_constructor',
        title: 'Widget 缺少 const 构造函数',
        file: file,
        line: line,
        level: RiskLevel.low,
        domain: IssueDomain.standards,
        priority: Priority.p2,
        message:
            '"${cls.name.lexeme}" 是 $superClassName 子类但缺少 const 构造函数',
        detail:
            '类: ${cls.name.lexeme}\n超类: $superClassName',
        suggestion:
            '添加 const 构造函数: "const ${cls.name.lexeme}({super.key});"',
        metadata: {
          'className': cls.name.lexeme,
          'superClass': superClassName,
        },
      ));
    }

    return issues;
  }
}
