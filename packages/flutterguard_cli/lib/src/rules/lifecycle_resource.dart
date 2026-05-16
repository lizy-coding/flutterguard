import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../config_loader.dart';
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

      final resourceFields = <String, String>{};

      for (final field in fieldDeclarations) {
        if (field.fields.type == null) continue;
        final typeStr = field.fields.type.toString();
        for (final resourceType in _resourceTypes.keys) {
          if (typeStr == resourceType || typeStr.endsWith('<$resourceType>')) {
            final fieldName = field.fields.variables.first.name.lexeme;
            resourceFields[fieldName] = resourceType;
          }
        }
      }

      if (resourceFields.isEmpty) continue;

      final disposeMethod = cls.members
          .whereType<MethodDeclaration>()
          .where((m) => m.name.lexeme == 'dispose')
          .firstOrNull;

      for (final entry in resourceFields.entries) {
        final fieldName = entry.key;
        final resourceType = entry.value;
        final expectedCall = _resourceTypes[resourceType]!;
        final isDisposed = _isFieldDisposed(disposeMethod, fieldName, expectedCall);

        if (!isDisposed) {
          final field = fieldDeclarations.firstWhere(
            (f) => f.fields.variables.any((v) => v.name.lexeme == fieldName),
          );
          final line =
              (field.parent as ClassDeclaration).name.offset;

          issues.add(StaticIssue(
            id: 'lifecycle_resource_not_disposed',
            title: 'Lifecycle resource not disposed',
            file: file,
            line: line,
            level: RiskLevel.high,
            message:
                '$resourceType "$fieldName" in "${cls.name.lexeme}" may not be properly disposed.',
            suggestion:
                'Call "${fieldName}.$expectedCall()" in the dispose() method.',
            metadata: {
              'className': cls.name.lexeme,
              'resourceType': resourceType,
              'expectedDisposeCall': expectedCall,
            },
          ));
        }
      }
    }

    return issues;
  }

  bool _isFieldDisposed(
    MethodDeclaration? disposeMethod,
    String fieldName,
    String expectedCall,
  ) {
    if (disposeMethod == null) return false;

    bool found = false;
    disposeMethod.visitChildren(_FieldDisposeVisitor(
      fieldName: fieldName,
      expectedCall: expectedCall,
      onFound: () => found = true,
    ));
    return found;
  }
}

class _FieldDisposeVisitor extends RecursiveAstVisitor<void> {
  final String fieldName;
  final String expectedCall;
  final VoidCallback onFound;

  _FieldDisposeVisitor({
    required this.fieldName,
    required this.expectedCall,
    required this.onFound,
  });

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SimpleIdentifier) {
      final target = node.target as SimpleIdentifier;
      if (target.name == fieldName && node.methodName.name == expectedCall) {
        onFound();
      }
    }
    super.visitMethodInvocation(node);
  }
}
