import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../priority.dart';
import '../static_issue.dart';

const _resourceTypes = <String, String>{
  'StreamSubscription': 'cancel',
  'Timer': 'cancel',
  'AnimationController': 'dispose',
  'TextEditingController': 'dispose',
  'ScrollController': 'dispose',
  'FocusNode': 'dispose',
};

class LifecycleResourceRule {
  final LifecycleResourceRuleConfig config;

  const LifecycleResourceRule(this.config);

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
      final fieldDeclarations = cls.members
          .whereType<FieldDeclaration>()
          .where((f) => !f.isStatic)
          .toList();

      if (fieldDeclarations.isEmpty) continue;

      final disposeMethod = cls.members
          .whereType<MethodDeclaration>()
          .where((m) => m.name.lexeme == 'dispose')
          .firstOrNull;

      for (final field in fieldDeclarations) {
        final type = field.fields.type;
        if (type == null) continue;

        final typeStr = type.toString();
        for (final resourceType in _resourceTypes.keys) {
          if (typeStr == resourceType ||
              typeStr.endsWith('<$resourceType>')) {
            final fieldName = field.fields.variables.first.name.lexeme;
            final expectedCall = _resourceTypes[resourceType]!;

            bool isDisposed = false;
            if (disposeMethod != null) {
              final disposeBody = disposeMethod.toString();
              isDisposed = disposeBody.contains('$fieldName.$expectedCall');
            }

            if (!isDisposed) {
              final line = field.fields.variables.first.name.offset;

              issues.add(StaticIssue(
                id: 'lifecycle_resource_not_disposed',
                title: '资源未释放',
                file: file,
                line: line,
                level: RiskLevel.medium,
                domain: IssueDomain.performance,
                priority: Priority.p1,
                message:
                    '$resourceType 类型字段 "$fieldName" 在 "${cls.name.lexeme}" 中未在 dispose() 中释放',
                detail: '字段: $fieldName ($resourceType)\n'
                    '类: ${cls.name.lexeme}\n'
                    '预期释放调用: $fieldName.$expectedCall()',
                suggestion:
                    '在 dispose() 方法中添加 "$fieldName.$expectedCall()" 调用',
                metadata: {
                  'className': cls.name.lexeme,
                  'resourceType': resourceType,
                  'fieldName': fieldName,
                  'expectedDisposeCall': expectedCall,
                },
              ));
            }
          }
        }
      }
    }

    return issues;
  }
}
