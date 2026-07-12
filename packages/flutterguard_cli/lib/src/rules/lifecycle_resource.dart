import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../priority.dart';
import '../rule_meta.dart';
import '../source_utils.dart';
import '../source_workspace.dart';
import '../static_issue.dart';

const _resourceTypes = <String, String>{
  'StreamSubscription': 'cancel',
  'Timer': 'cancel',
  'AnimationController': 'dispose',
  'TextEditingController': 'dispose',
  'ScrollController': 'dispose',
  'FocusNode': 'dispose',
  'MqttClient': 'disconnect',
  'BluetoothDevice': 'disconnect',
  'StreamController': 'close',
};

class LifecycleResourceRule {
  final LifecycleResourceRuleConfig config;

  const LifecycleResourceRule(this.config);

  List<StaticIssue> analyze(
    List<String> files, {
    SourceWorkspace? workspace,
  }) {
    if (!config.enabled) return [];

    final issues = <StaticIssue>[];
    final sources = workspace ?? SourceWorkspace();

    for (final file in files) {
      final source = sources.source(file);
      if (source == null) continue;
      issues.addAll(_checkFile(file, source.unit, source.lineInfo));
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
          if (typeStr == resourceType || typeStr.endsWith('<$resourceType>')) {
            final fieldName = field.fields.variables.first.name.lexeme;
            final expectedCall = _resourceTypes[resourceType]!;

            bool isDisposed = false;
            if (disposeMethod != null) {
              final disposeBody = disposeMethod.toString();
              isDisposed = disposeBody.contains('$fieldName.$expectedCall');
            }

            if (!isDisposed) {
              final line = lineNumberForOffset(
                lineInfo,
                field.fields.variables.first.name.offset,
              );

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
                suggestion: '在 dispose() 方法中添加 "$fieldName.$expectedCall()" 调用',
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

  static RuleMeta describe() => const RuleMeta(
        id: 'lifecycle_resource_not_disposed',
        name: '资源未释放',
        domain: 'performance',
        riskLevel: 'medium',
        priority: 'p1',
        purpose:
            '检测 StreamSubscription/Timer/AnimationController 等资源在 dispose 中未释放',
        riskReason: '未释放的资源导致内存泄漏和性能下降',
        badExample: '在 State 中创建 StreamSubscription 但 dispose() 中未调用 cancel()',
        fixSuggestion: '在 dispose() 中对每个资源调用对应的 cancel()/dispose()/close()',
        cicdSafe: true,
      );
}
