import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../rule_meta.dart';
import '../source_workspace.dart';
import '../static_issue.dart';
import 'state_management_utils.dart';

class BlocEquatablePropsIncompleteRule {
  final StateRuleConfig config;
  final StateManagementConfig stateManagement;
  final String projectPath;

  const BlocEquatablePropsIncompleteRule(
    this.config,
    this.stateManagement, {
    required this.projectPath,
  });

  List<StaticIssue> analyze(List<String> files, {SourceWorkspace? workspace}) {
    if (!stateRuleEnabled(config, stateManagement)) return [];
    final sources = workspace ?? SourceWorkspace();
    final issues = <StaticIssue>[];
    for (final file in files) {
      if (shouldIgnoreStateFile(file, projectPath, config)) continue;
      final source = sources.source(file);
      if (source == null) continue;
      if (stateManagement.frameworkAutoDetect &&
          !hasEquatableImport(source.unit)) {
        continue;
      }
      if (!frameworkAllowed(
        source.unit,
        StateManagementFramework.bloc,
        stateManagement,
      )) {
        continue;
      }
      for (final cls
          in source.unit.declarations.whereType<ClassDeclaration>()) {
        if (!_inheritsEquatable(cls)) continue;
        final fields = <String>{};
        for (final field in cls.members.whereType<FieldDeclaration>()) {
          if (field.isStatic || !field.fields.isFinal) continue;
          for (final variable in field.fields.variables) {
            final name = variable.name.lexeme;
            if (config.allowlist.contains('${cls.name.lexeme}.$name')) continue;
            fields.add(name);
          }
        }
        if (fields.isEmpty) continue;
        final props = cls.members.whereType<MethodDeclaration>().where(
              (method) => method.isGetter && method.name.lexeme == 'props',
            );
        final referenced = <String>{};
        for (final getter in props) {
          final visitor = _IdentifierCollector();
          getter.body.accept(visitor);
          referenced.addAll(visitor.names);
        }
        final missing = fields.difference(referenced).toList()..sort();
        if (missing.isEmpty) continue;
        issues.add(StaticIssue(
          id: 'bloc_equatable_props_incomplete',
          title: 'Equatable props 不完整',
          file: file,
          line: sourceLine(source, cls),
          level: config.severity,
          domain: IssueDomain.standards,
          priority: priorityForSeverity(config.severity),
          message: '${cls.name.lexeme}.props 缺少字段: ${missing.join(', ')}',
          suggestion: '将所有参与值相等判断的 final instance 字段加入 props',
          framework: StateManagementFramework.bloc,
          evidence: missing.map((field) => 'missing: $field').take(5).toList(),
          metadata: {'className': cls.name.lexeme, 'missingFields': missing},
        ));
      }
    }
    return issues;
  }

  static bool _inheritsEquatable(ClassDeclaration cls) {
    final superclass = cls.extendsClause?.superclass.toSource() ?? '';
    final mixins =
        cls.withClause?.mixinTypes.map((type) => type.toSource()).toList() ??
            const [];
    return superclass == 'Equatable' || mixins.contains('EquatableMixin');
  }

  static RuleMeta describe() => const RuleMeta(
        id: 'bloc_equatable_props_incomplete',
        name: 'Equatable props 不完整',
        domain: 'standards',
        riskLevel: 'medium',
        priority: 'p1',
        purpose: '比较 Equatable 类的 final instance 字段与 props 字段引用',
        riskReason: '遗漏字段会让不同状态被误判为相等，阻止 Bloc UI 更新',
        badExample: 'final a; final b; List<Object?> get props => [a];',
        fixSuggestion: '把遗漏的值字段加入 props',
        configKeys: ['enabled', 'severity', 'allowlist', 'ignore_paths'],
        framework: 'bloc',
      );
}

class _IdentifierCollector extends RecursiveAstVisitor<void> {
  final names = <String>{};

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    names.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}
