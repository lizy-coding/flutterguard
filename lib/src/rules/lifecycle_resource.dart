import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../config_loader.dart';
import 'rule.dart';
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
  'OverlayEntry': 'remove',
};

class LifecycleResourceRule {
  final RuleConfig config;

  const LifecycleResourceRule(this.config);

  List<StaticIssue> analyze(List<String> files, {SourceWorkspace? workspace}) {
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

      final methods = {
        for (final method in cls.members.whereType<MethodDeclaration>())
          method.name.lexeme: method,
      };
      final cleanup = _CleanupCalls(methods);
      cleanup.visitMethod('dispose');

      for (final field in fieldDeclarations) {
        final type = field.fields.type;
        if (type is! NamedType) continue;
        final resourceType = type.name2.lexeme;
        final expectedCall = _resourceTypes[resourceType];
        if (expectedCall == null) continue;

        for (final variable in field.fields.variables) {
          final fieldName = variable.name.lexeme;
          if (cleanup.calls.contains('$fieldName.$expectedCall')) continue;
          final line = lineNumberForOffset(lineInfo, variable.name.offset);
          issues.add(
            StaticIssue(
              id: 'lifecycle_resource_not_disposed',
              title: '资源未释放',
              file: file,
              line: line,
              level: config.severity,
              domain: IssueDomain.performance,
              message:
                  '$resourceType 类型字段 "$fieldName" 在 "${cls.name.lexeme}" 中未在 dispose() 中释放',
              detail:
                  '字段: $fieldName ($resourceType)\n'
                  '类: ${cls.name.lexeme}\n'
                  '预期释放调用: $fieldName.$expectedCall()',
              suggestion: '在 dispose() 或由其调用的本类清理方法中释放 "$fieldName"，并确认资源所有权',
              metadata: {
                'className': cls.name.lexeme,
                'resourceType': resourceType,
                'fieldName': fieldName,
                'expectedDisposeCall': expectedCall,
              },
            ),
          );
        }
      }
    }

    return issues;
  }

  static RuleDefinition describe() => const RuleDefinition(
    id: 'lifecycle_resource_not_disposed',
    name: '资源未释放',
    domain: IssueDomain.performance,
    defaultSeverity: RiskLevel.medium,
    purpose: '检测显式声明的资源字段（含 nullable/泛型）在 dispose 及本类清理方法中缺少释放调用',
    riskReason: '未释放的资源导致内存泄漏和性能下降',
    badExample: '在 State 中创建 StreamSubscription 但 dispose() 中未调用 cancel()',
    fixSuggestion: '在 dispose() 中对每个资源调用对应的 cancel()/dispose()/close()',
  );
}

// Follow only direct calls in dispose and same-class helpers. This is a syntax
// check, not an ownership or control-flow proof; stored callbacks do not count.
class _CleanupCalls extends RecursiveAstVisitor<void> {
  final Map<String, MethodDeclaration> methods;
  final Set<String> visited = {};
  final Set<String> calls = {};

  _CleanupCalls(this.methods);

  void visitMethod(String name) {
    if (!visited.add(name)) return;
    methods[name]?.body.accept(this);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Declaring a closure does not execute its cleanup.
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    Expression? target = node.target;
    if (node.isCascaded && node.parent is CascadeExpression) {
      target = (node.parent as CascadeExpression).target;
    }
    final fieldName = switch (target) {
      SimpleIdentifier(:final name) => name,
      PropertyAccess(target: ThisExpression(), propertyName: final name) =>
        name.name,
      _ => null,
    };
    if (fieldName != null) {
      calls.add('$fieldName.${node.methodName.name}');
    }
    if (target == null || target is ThisExpression) {
      visitMethod(node.methodName.name);
    }
    super.visitMethodInvocation(node);
  }
}
