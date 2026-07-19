import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config_loader.dart';
import 'rule.dart';
import '../source_workspace.dart';
import '../static_issue.dart';
import 'state_management_utils.dart';

class ProviderValueLifecycleMisuseRule {
  final RuleConfig config;

  const ProviderValueLifecycleMisuseRule(this.config);

  List<StaticIssue> analyze(List<String> files, {SourceWorkspace? workspace}) {
    if (!stateRuleEnabled(config)) return [];
    final sources = workspace ?? SourceWorkspace();
    final issues = <StaticIssue>[];
    for (final file in files) {
      final source = sources.source(file);
      if (source == null ||
          !frameworkAllowed(source.unit, StateManagementFramework.provider)) {
        continue;
      }
      final visitor = _ProviderOwnershipVisitor();
      source.unit.accept(visitor);
      for (final finding in visitor.findings) {
        issues.add(
          StaticIssue(
            id: 'provider_value_lifecycle_misuse',
            title: 'Provider 所有权模式误用',
            file: file,
            line: sourceLine(source, finding.node),
            level: config.severity,
            domain: IssueDomain.performance,
            message: finding.message,
            suggestion: finding.kind == 'value_creates'
                ? '新对象使用 create 构造；.value 只传入已有实例'
                : '已有实例使用 .value，避免 Provider 错误释放或忽略所有权',
            framework: StateManagementFramework.provider,
            evidence: [compactEvidence(finding.node)],
            metadata: {'ownershipError': finding.kind},
          ),
        );
      }
    }
    return issues;
  }

  static RuleDefinition describe() => const RuleDefinition(
    id: 'provider_value_lifecycle_misuse',
    name: 'Provider 所有权误用',
    domain: IssueDomain.performance,
    defaultSeverity: RiskLevel.medium,
    purpose: '检测 .value 创建新对象和 create 返回已有对象的反向所有权用法',
    riskReason: '错误的 Provider 构造方式会导致对象未释放、提前释放或状态复用错误',
    badExample: 'ChangeNotifierProvider.value(value: DeviceController())',
    fixSuggestion: '新对象用 create，已有对象用 .value',
    framework: 'provider',
  );
}

class _ProviderOwnershipFinding {
  final AstNode node;
  final String kind;
  final String message;

  const _ProviderOwnershipFinding(this.node, this.kind, this.message);
}

class _ProviderOwnershipVisitor extends RecursiveAstVisitor<void> {
  final findings = <_ProviderOwnershipFinding>[];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _inspectCall(
      node: node,
      providerType: simpleTypeName(node.constructorName.type.toSource()),
      constructor: node.constructorName.name?.name,
      arguments: node.argumentList,
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toSource();
    final targetType = target == null ? null : simpleTypeName(target);
    final targetIsProvider = targetType?.endsWith('Provider') ?? false;
    final providerType = targetIsProvider
        ? targetType!
        : simpleTypeName(node.methodName.name);
    final constructor = targetIsProvider ? node.methodName.name : null;
    _inspectCall(
      node: node,
      providerType: providerType,
      constructor: constructor,
      arguments: node.argumentList,
    );
    super.visitMethodInvocation(node);
  }

  void _inspectCall({
    required AstNode node,
    required String providerType,
    required String? constructor,
    required ArgumentList arguments,
  }) {
    if (!providerType.endsWith('Provider')) return;
    if (constructor == 'value') {
      final value = _argument(arguments, 'value');
      final createdType = _createdType(value);
      final isConst = value is InstanceCreationExpression && value.isConst;
      if (createdType != null && !isConst && !_isImmutableType(createdType)) {
        findings.add(
          _ProviderOwnershipFinding(
            node,
            'value_creates',
            '$providerType.value 创建了新对象，Provider 不会按 create 所有权管理它',
          ),
        );
      }
    }

    final create =
        _argument(arguments, 'create') ??
        (constructor == 'create' ? _firstPositional(arguments) : null);
    if (create is FunctionExpression) {
      final returned = _returnedExpression(create.body);
      if (returned != null && _isExistingReference(returned)) {
        findings.add(
          _ProviderOwnershipFinding(
            node,
            'create_reuses',
            '$providerType.create 返回已有实例，可能错误取得其释放所有权',
          ),
        );
      }
    }
  }

  static String? _createdType(Expression? expression) {
    if (expression is InstanceCreationExpression) {
      return simpleTypeName(expression.constructorName.type.toSource());
    }
    if (expression is MethodInvocation &&
        expression.target == null &&
        expression.methodName.name.startsWith(RegExp('[A-Z]'))) {
      return simpleTypeName(expression.methodName.name);
    }
    return null;
  }

  bool _isImmutableType(String type) {
    return type.endsWith('Value') ||
        type.endsWith('Data') ||
        type.endsWith('Dto') ||
        type == 'String' ||
        type == 'int' ||
        type == 'double' ||
        type == 'bool';
  }

  static Expression? _argument(ArgumentList list, String name) {
    for (final argument in list.arguments) {
      if (argument is NamedExpression && argument.name.label.name == name) {
        return argument.expression;
      }
    }
    return null;
  }

  static Expression? _firstPositional(ArgumentList list) {
    for (final argument in list.arguments) {
      if (argument is! NamedExpression) return argument;
    }
    return null;
  }

  static Expression? _returnedExpression(FunctionBody body) {
    if (body is ExpressionFunctionBody) return body.expression;
    if (body is BlockFunctionBody) {
      for (final statement in body.block.statements) {
        if (statement is ReturnStatement) return statement.expression;
      }
    }
    return null;
  }

  static bool _isExistingReference(Expression expression) =>
      expression is SimpleIdentifier ||
      expression is PrefixedIdentifier ||
      expression is PropertyAccess;
}

class NotifyListenersInLoopRule {
  final RuleConfig config;

  const NotifyListenersInLoopRule(this.config);

  List<StaticIssue> analyze(List<String> files, {SourceWorkspace? workspace}) {
    if (!stateRuleEnabled(config)) return [];
    final sources = workspace ?? SourceWorkspace();
    final issues = <StaticIssue>[];
    for (final file in files) {
      final source = sources.source(file);
      if (source == null ||
          !frameworkAllowed(source.unit, StateManagementFramework.provider)) {
        continue;
      }
      final visitor = _NotifyLoopVisitor();
      source.unit.accept(visitor);
      for (final finding in visitor.findings) {
        issues.add(
          StaticIssue(
            id: 'notify_listeners_in_loop',
            title: '循环中调用 notifyListeners',
            file: file,
            line: sourceLine(source, finding.root),
            level: config.severity,
            domain: IssueDomain.performance,
            message: '循环每次迭代都可能触发监听者重建',
            suggestion: '在循环内完成批量修改后，只调用一次 notifyListeners()',
            framework: StateManagementFramework.provider,
            evidence: limitedEvidence(
              finding.notifications.map(compactEvidence),
            ),
          ),
        );
      }
    }
    return issues;
  }

  static RuleDefinition describe() => const RuleDefinition(
    id: 'notify_listeners_in_loop',
    name: '循环中通知监听者',
    domain: IssueDomain.performance,
    defaultSeverity: RiskLevel.medium,
    purpose: '检测 for/while/do-while/forEach 中的 notifyListeners',
    riskReason: '循环内通知会触发重复重建并暴露中间状态',
    badExample:
        'for (final item in items) { update(item); notifyListeners(); }',
    fixSuggestion: '循环结束后统一通知一次',
    framework: 'provider',
  );
}

class _NotifyLoopFinding {
  final AstNode root;
  final List<MethodInvocation> notifications;

  const _NotifyLoopFinding(this.root, this.notifications);
}

class _NotifyLoopVisitor extends RecursiveAstVisitor<void> {
  final findings = <_NotifyLoopFinding>[];

  @override
  void visitForStatement(ForStatement node) {
    final parts = node.forLoopParts;
    final provablyShort = _provablyShortFor(parts);
    if (!provablyShort) _inspect(node, node.body);
    super.visitForStatement(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _inspect(node, node.body);
    super.visitWhileStatement(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    _inspect(node, node.body);
    super.visitDoStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'forEach') {
      final callback = node.argumentList.arguments
          .whereType<FunctionExpression>()
          .firstOrNull;
      final target = node.target;
      final provablyShort =
          target is ListLiteral && target.elements.length <= 1 ||
          target is SetOrMapLiteral && target.elements.length <= 1;
      if (callback != null && !provablyShort) _inspect(node, callback.body);
    }
    super.visitMethodInvocation(node);
  }

  void _inspect(AstNode root, AstNode body) {
    final visitor = _NotifyInvocationVisitor();
    body.accept(visitor);
    if (visitor.nodes.isNotEmpty) {
      findings.add(_NotifyLoopFinding(root, visitor.nodes));
    }
  }

  bool _provablyShortFor(ForLoopParts parts) {
    if (parts is ForEachParts) {
      final iterable = parts.iterable;
      return iterable is ListLiteral && iterable.elements.length <= 1 ||
          iterable is SetOrMapLiteral && iterable.elements.length <= 1;
    }
    final source = parts.toSource().replaceAll(RegExp(r'\s+'), ' ');
    return RegExp(r'= 0; [A-Za-z_$][\w$]* < 1;').hasMatch(source) ||
        RegExp(r'= 0; [A-Za-z_$][\w$]* <= 0;').hasMatch(source);
  }
}

class _NotifyInvocationVisitor extends RecursiveAstVisitor<void> {
  final nodes = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'notifyListeners') nodes.add(node);
    super.visitMethodInvocation(node);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
