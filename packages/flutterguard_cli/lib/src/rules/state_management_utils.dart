import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config_loader.dart';
import '../path_utils.dart';
import '../priority.dart';
import '../source_workspace.dart';
import '../static_issue.dart';

const stateOwnerSuffixes = [
  'State',
  'Notifier',
  'Controller',
  'Cubit',
  'Bloc',
  'ChangeNotifier',
];

Priority priorityForSeverity(RiskLevel severity) => switch (severity) {
      RiskLevel.high => Priority.p0,
      RiskLevel.medium => Priority.p1,
      RiskLevel.low => Priority.p2,
    };

bool stateRuleEnabled(
  StateRuleConfig rule,
  StateManagementConfig stateManagement,
) {
  if (!stateManagement.enabled || !rule.enabled) return false;
  // All state-management rules currently emit certain findings. The ordering
  // keeps the threshold model forward compatible when lower-confidence rules
  // are introduced.
  return switch (stateManagement.confidenceThreshold) {
    RuleConfidence.certain => true,
    RuleConfidence.probable => true,
    RuleConfidence.informational => true,
  };
}

bool shouldIgnoreStateFile(
  String file,
  String projectPath,
  StateRuleConfig config,
) =>
    config.ignorePaths.any(
      (pattern) => matchesProjectGlob(file, pattern, projectPath),
    );

bool hasFrameworkImport(
  CompilationUnit unit,
  StateManagementFramework framework,
) {
  final imports = unit.directives
      .whereType<ImportDirective>()
      .map((directive) => directive.uri.stringValue ?? '')
      .toList();
  return switch (framework) {
    StateManagementFramework.riverpod => imports.any(
        (uri) => uri.contains('riverpod') || uri.contains('hooks_riverpod'),
      ),
    StateManagementFramework.bloc => imports.any(
        (uri) =>
            uri.contains('package:bloc/') ||
            uri.contains('package:flutter_bloc/'),
      ),
    StateManagementFramework.provider => imports.any(
        (uri) =>
            uri.contains('package:provider/') ||
            uri.contains('package:flutter_bloc/'),
      ),
    StateManagementFramework.generic => true,
  };
}

bool frameworkAllowed(
  CompilationUnit unit,
  StateManagementFramework framework,
  StateManagementConfig config,
) =>
    !config.frameworkAutoDetect || hasFrameworkImport(unit, framework);

bool isStateOwnerClass(ClassDeclaration declaration) {
  final name = declaration.name.lexeme;
  final supertype = declaration.extendsClause?.superclass.toSource() ?? '';
  final mixins = declaration.withClause?.mixinTypes
          .map((type) => type.toSource())
          .join(' ') ??
      '';
  if (supertype.startsWith('State<')) return false;
  return stateOwnerSuffixes.any(name.endsWith) ||
      stateOwnerSuffixes.any(supertype.endsWith) ||
      stateOwnerSuffixes.any(mixins.contains);
}

String typeName(TypeAnnotation? type) => type?.toSource() ?? '';

String simpleTypeName(String type) {
  final withoutGenerics = type.split('<').first;
  return withoutGenerics.split('.').last.replaceAll('?', '');
}

bool isCollectionType(String type) {
  final simple = simpleTypeName(type);
  return simple == 'List' ||
      simple == 'Set' ||
      simple == 'Map' ||
      simple.startsWith('Iterable');
}

bool isUnmodifiableExpression(Expression? expression) {
  if (expression == null) return false;
  final source = expression.toSource();
  return source.contains('unmodifiable') ||
      source.contains('Unmodifiable') ||
      source.contains('List.unmodifiable') ||
      source.contains('Set.unmodifiable') ||
      source.contains('Map.unmodifiable');
}

bool isPublicName(String name) => !name.startsWith('_');

String compactEvidence(AstNode node) {
  final value = node.toSource().replaceAll(RegExp(r'\s+'), ' ').trim();
  return value.length <= 140 ? value : '${value.substring(0, 137)}...';
}

List<String> limitedEvidence(Iterable<String> evidence) =>
    evidence.toSet().take(5).toList();

int sourceLine(SourceUnit source, AstNode node) =>
    source.lineInfo.getLocation(node.offset).lineNumber;

class BuildRoot {
  final AstNode body;
  final AstNode anchor;
  final String label;

  const BuildRoot(this.body, this.anchor, this.label);
}

List<BuildRoot> buildRoots(CompilationUnit unit) {
  final collector = _BuildRootCollector();
  unit.accept(collector);
  final roots = <BuildRoot>[];
  final seen = <int>{};
  for (final root in collector.roots) {
    if (seen.add(root.anchor.offset)) roots.add(root);
  }
  return roots;
}

class _BuildRootCollector extends RecursiveAstVisitor<void> {
  final roots = <BuildRoot>[];

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build') {
      roots.add(BuildRoot(node.body, node, 'build'));
    }
    super.visitMethodDeclaration(node);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == 'builder' &&
        node.expression is FunctionExpression &&
        _isConsumerBuilder(node)) {
      final function = node.expression as FunctionExpression;
      roots.add(BuildRoot(function.body, function, 'Consumer.builder'));
    }
    super.visitNamedExpression(node);
  }

  bool _isConsumerBuilder(NamedExpression node) {
    final arguments = node.parent;
    final call = arguments?.parent;
    if (call is InstanceCreationExpression) {
      return call.constructorName.type.toSource().contains('Consumer');
    }
    if (call is MethodInvocation) {
      return call.methodName.name.toLowerCase().contains('consumer');
    }
    return false;
  }
}

bool isCallbackFunction(FunctionExpression node) {
  final parent = node.parent;
  if (parent is NamedExpression) {
    const callbackNames = {
      'onPressed',
      'onTap',
      'onChanged',
      'onSubmitted',
      'listener',
      'listenWhen',
      'callback',
      'onData',
      'onError',
      'onDone',
      'timer',
    };
    return callbackNames.contains(parent.name.label.name);
  }
  final arguments = parent is NamedExpression ? parent.parent : parent;
  final invocation = arguments?.parent;
  if (invocation is MethodInvocation) {
    return const {
      'forEach',
      'listen',
      'then',
      'catchError',
      'whenComplete',
      'delayed',
      'microtask',
    }.contains(invocation.methodName.name);
  }
  if (invocation is InstanceCreationExpression) {
    final type = simpleTypeName(invocation.constructorName.type.toSource());
    return type == 'Timer' || type == 'Future';
  }
  return false;
}

bool isInsideNestedFunction(AstNode node, AstNode root) {
  AstNode? current = node.parent;
  while (current != null && current != root) {
    if (current is FunctionExpression) return true;
    current = current.parent;
  }
  return false;
}

bool hasEquatableImport(CompilationUnit unit) =>
    unit.directives.whereType<ImportDirective>().any((directive) =>
        (directive.uri.stringValue ?? '').contains('package:equatable/'));
