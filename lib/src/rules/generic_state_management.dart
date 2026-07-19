import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config_loader.dart';
import 'rule.dart';
import '../source_workspace.dart';
import '../static_issue.dart';
import 'state_management_utils.dart';

class SideEffectInBuildRule {
  final RuleConfig config;

  const SideEffectInBuildRule(this.config);

  List<StaticIssue> analyze(List<String> files, {SourceWorkspace? workspace}) {
    if (!stateRuleEnabled(config)) return [];
    final sources = workspace ?? SourceWorkspace();
    final issues = <StaticIssue>[];
    for (final file in files) {
      final source = sources.source(file);
      if (source == null) continue;
      for (final root in buildRoots(source.unit)) {
        final visitor = _SideEffectVisitor();
        root.body.accept(visitor);
        final evidence = limitedEvidence(visitor.evidence);
        if (evidence.isEmpty) continue;
        issues.add(
          StaticIssue(
            id: 'side_effect_in_build',
            title: 'build 中执行副作用',
            file: file,
            line: sourceLine(source, root.anchor),
            level: config.severity,
            domain: IssueDomain.performance,
            message: '${root.label} 在渲染阶段执行了状态或资源副作用',
            detail: 'build 必须保持幂等；框架可能在一次界面更新中重复调用它。',
            suggestion: '将副作用移至生命周期、listener 或用户事件回调中',
            evidence: evidence,
            metadata: {'buildRoot': root.label},
          ),
        );
      }
    }
    return issues;
  }

  static RuleDefinition describe() => const RuleDefinition(
    id: 'side_effect_in_build',
    name: 'build 中的副作用',
    domain: IssueDomain.performance,
    defaultSeverity: RiskLevel.high,
    purpose: '检测 Widget build 与 Consumer builder 中直接执行的状态和资源副作用',
    riskReason: 'build 可被重复调用，副作用会造成重复连接、通知或状态更新',
    badExample: 'Widget build(...) { ref.read(x.notifier).refresh(); }',
    fixSuggestion: '把副作用移到生命周期、listener 或事件回调',
  );
}

class _SideEffectVisitor extends RecursiveAstVisitor<void> {
  final evidence = <String>[];

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // A nested closure is an event/listener/timer boundary. Consumer builder
    // closures are scanned separately as build roots.
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = simpleTypeName(node.constructorName.type.toSource());
    if (type == 'Timer') {
      evidence.add(compactEvidence(node));
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final target = node.target?.toSource() ?? '';
    const directEffects = {
      'notifyListeners',
      'emit',
      'setState',
      'connect',
      'disconnect',
      'startScan',
    };
    final managerAdd =
        name == 'add' &&
        (target.toLowerCase().contains('bloc') ||
            target.toLowerCase().contains('cubit') ||
            target.toLowerCase().contains('notifier') ||
            target.contains('context.read') ||
            target.contains('ref.read'));
    final notifierCommand =
        target.contains('ref.read') &&
        target.contains('.notifier') &&
        name != 'read';
    final timerPeriodic = target == 'Timer' && name == 'periodic';
    final timerCreation = target.isEmpty && name == 'Timer';
    if (directEffects.contains(name) ||
        managerAdd ||
        notifierCommand ||
        timerPeriodic ||
        timerCreation) {
      evidence.add(compactEvidence(node));
    }
    super.visitMethodInvocation(node);
  }
}

class StateManagerCreatedInBuildRule {
  final RuleConfig config;

  const StateManagerCreatedInBuildRule(this.config);

  List<StaticIssue> analyze(List<String> files, {SourceWorkspace? workspace}) {
    if (!stateRuleEnabled(config)) return [];
    final sources = workspace ?? SourceWorkspace();
    final issues = <StaticIssue>[];
    for (final file in files) {
      final source = sources.source(file);
      if (source == null) continue;
      for (final root in buildRoots(source.unit)) {
        final visitor = _StateManagerCreationVisitor();
        root.body.accept(visitor);
        for (final creation in visitor.creations) {
          final type = creation.type;
          issues.add(
            StaticIssue(
              id: 'state_manager_created_in_build',
              title: 'build 中创建状态管理对象',
              file: file,
              line: sourceLine(source, creation.node),
              level: config.severity,
              domain: IssueDomain.performance,
              message: '$type 在 ${root.label} 中被重复创建',
              suggestion: '把对象交给 State 生命周期或 Provider/BlocProvider 的 create 管理',
              evidence: [compactEvidence(creation.node)],
              metadata: {'type': type, 'buildRoot': root.label},
            ),
          );
        }
      }
    }
    return issues;
  }

  static RuleDefinition describe() => const RuleDefinition(
    id: 'state_manager_created_in_build',
    name: 'build 中创建状态管理对象',
    domain: IssueDomain.performance,
    defaultSeverity: RiskLevel.high,
    purpose: '检测 build 中创建 Controller、Bloc、Cubit、Notifier 等持有型对象',
    riskReason: '重复构建会重建对象并丢失状态或泄漏资源',
    badExample: 'Widget build(...) { final c = DeviceController(); }',
    fixSuggestion: '提升到生命周期字段或框架所有权 create 回调',
  );
}

class _StateManagerCreationVisitor extends RecursiveAstVisitor<void> {
  final creations = <({AstNode node, String type})>[];

  static const flutterControllers = {
    'AnimationController',
    'TextEditingController',
    'ScrollController',
    'PageController',
    'TabController',
    'FocusNode',
  };

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = simpleTypeName(node.constructorName.type.toSource());
    _record(node, type);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null &&
        node.methodName.name.startsWith(RegExp('[A-Z]'))) {
      _record(node, simpleTypeName(node.methodName.name));
    }
    super.visitMethodInvocation(node);
  }

  void _record(AstNode node, String type) {
    final owned =
        stateOwnerSuffixes.any(type.endsWith) ||
        flutterControllers.contains(type);
    if (owned) {
      creations.add((node: node, type: type));
    }
  }
}

class MutableStateExposedRule {
  final RuleConfig config;

  const MutableStateExposedRule(this.config);

  List<StaticIssue> analyze(List<String> files, {SourceWorkspace? workspace}) {
    if (!stateRuleEnabled(config)) return [];
    final sources = workspace ?? SourceWorkspace();
    final issues = <StaticIssue>[];
    for (final file in files) {
      final source = sources.source(file);
      if (source == null) continue;
      for (final cls
          in source.unit.declarations.whereType<ClassDeclaration>()) {
        if (!isStateOwnerClass(cls)) continue;
        issues.addAll(_inspectClass(file, source, cls));
      }
    }
    return issues;
  }

  List<StaticIssue> _inspectClass(
    String file,
    SourceUnit source,
    ClassDeclaration cls,
  ) {
    final findings = <({AstNode node, String key, String evidence})>[];
    final privateCollections = <String>{};
    for (final field in cls.members.whereType<FieldDeclaration>()) {
      if (field.isStatic) continue;
      final type = typeName(field.fields.type);
      for (final variable in field.fields.variables) {
        final name = variable.name.lexeme;
        if (!isPublicName(name) && isCollectionType(type)) {
          privateCollections.add(name);
        }
        if (!isPublicName(name)) continue;
        if (!field.fields.isFinal) {
          findings.add((
            node: variable,
            key: 'field:$name:non_final',
            evidence: '$type $name is public and non-final',
          ));
        } else if (isCollectionType(type) &&
            !isUnmodifiableExpression(variable.initializer)) {
          findings.add((
            node: variable,
            key: 'field:$name:collection',
            evidence: '$type $name exposes a mutable collection reference',
          ));
        }
      }
    }

    for (final method in cls.members.whereType<MethodDeclaration>()) {
      final name = method.name.lexeme;
      if (!method.isGetter || !isPublicName(name)) continue;
      final returned = _returnedIdentifier(method.body);
      if (returned != null && privateCollections.contains(returned)) {
        findings.add((
          node: method,
          key: 'getter:$name:$returned',
          evidence: 'getter $name returns mutable $returned directly',
        ));
      }
    }

    final mutationVisitor = _StateCollectionMutationVisitor();
    cls.accept(mutationVisitor);
    for (final mutation in mutationVisitor.mutations) {
      findings.add((
        node: mutation,
        key: 'state_mutation:${mutation.offset}',
        evidence: compactEvidence(mutation),
      ));
    }

    final seen = <String>{};
    return [
      for (final finding in findings)
        if (seen.add(finding.key))
          StaticIssue(
            id: 'mutable_state_exposed',
            title: '可变状态被公开',
            file: file,
            line: sourceLine(source, finding.node),
            level: config.severity,
            domain: IssueDomain.architecture,
            message: '${cls.name.lexeme} 暴露或原地修改了可变状态',
            suggestion: '公开不可变视图/副本，并用 copyWith 或新集合更新状态',
            evidence: [finding.evidence],
            metadata: {'className': cls.name.lexeme, 'rootCause': finding.key},
          ),
    ];
  }

  String? _returnedIdentifier(FunctionBody body) {
    if (body is ExpressionFunctionBody) {
      final expression = body.expression;
      if (expression is SimpleIdentifier) return expression.name;
    }
    if (body is BlockFunctionBody) {
      for (final statement
          in body.block.statements.whereType<ReturnStatement>()) {
        final expression = statement.expression;
        if (expression is SimpleIdentifier) return expression.name;
      }
    }
    return null;
  }

  static RuleDefinition describe() => const RuleDefinition(
    id: 'mutable_state_exposed',
    name: '公开可变状态',
    domain: IssueDomain.architecture,
    defaultSeverity: RiskLevel.medium,
    purpose: '检测状态 owner 的公开可变字段、集合 getter 与原地 state 集合修改',
    riskReason: '外部调用方可绕过状态通知并破坏单向数据流',
    badExample: 'final List<Item> items = [];',
    fixSuggestion: '返回不可变视图或副本，并替换整个状态值',
  );
}

class _StateCollectionMutationVisitor extends RecursiveAstVisitor<void> {
  final mutations = <AstNode>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toSource() ?? '';
    const mutators = {
      'add',
      'addAll',
      'remove',
      'removeWhere',
      'clear',
      'sort',
    };
    if ((target == 'state' || target.startsWith('state.')) &&
        mutators.contains(node.methodName.name)) {
      mutations.add(node);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final left = node.leftHandSide.toSource();
    if (left.startsWith('state[') || left.startsWith('state.')) {
      mutations.add(node);
    }
    super.visitAssignmentExpression(node);
  }
}

class StateLayerUiDependencyRule {
  final RuleConfig config;

  const StateLayerUiDependencyRule(this.config);

  List<StaticIssue> analyze(List<String> files, {SourceWorkspace? workspace}) {
    if (!stateRuleEnabled(config)) return [];
    final sources = workspace ?? SourceWorkspace();
    final issues = <StaticIssue>[];
    for (final file in files) {
      final source = sources.source(file);
      if (source == null) continue;
      for (final cls
          in source.unit.declarations.whereType<ClassDeclaration>()) {
        if (!isStateOwnerClass(cls)) continue;
        final visitor = _UiDependencyVisitor();
        cls.accept(visitor);
        final evidence = limitedEvidence(visitor.evidence);
        if (evidence.isEmpty) continue;
        issues.add(
          StaticIssue(
            id: 'state_layer_ui_dependency',
            title: '状态层依赖 UI API',
            file: file,
            line: sourceLine(source, cls),
            level: config.severity,
            domain: IssueDomain.architecture,
            message: '${cls.name.lexeme} 直接依赖 Flutter UI 上下文或导航 API',
            suggestion: '从状态层输出事件/数据，由 Widget 层执行导航、弹窗和主题访问',
            evidence: evidence,
            metadata: {'className': cls.name.lexeme},
          ),
        );
      }
    }
    return issues;
  }

  static RuleDefinition describe() => const RuleDefinition(
    id: 'state_layer_ui_dependency',
    name: '状态层依赖 UI',
    domain: IssueDomain.architecture,
    defaultSeverity: RiskLevel.high,
    purpose: '检测状态 owner 对 BuildContext、Widget、Navigator、Theme 等 UI API 的依赖',
    riskReason: '状态逻辑与 UI 生命周期耦合，难以测试和复用',
    badExample:
        'class DeviceController { void open(BuildContext context) { ... } }',
    fixSuggestion: '输出状态或事件，并在 Widget 层处理 UI 行为',
  );
}

class _UiDependencyVisitor extends RecursiveAstVisitor<void> {
  final evidence = <String>[];

  static const uiTypes = {'BuildContext', 'Widget'};
  static const uiCalls = {
    'showDialog',
    'showModalBottomSheet',
    'maybePop',
    'push',
    'pushNamed',
    'of',
  };

  @override
  void visitNamedType(NamedType node) {
    final type = node.toSource().replaceAll('?', '');
    final simple = simpleTypeName(type);
    final nestedTypeOnly = node.parent is TypeArgumentList;
    if (!nestedTypeOnly && uiTypes.contains(simple)) {
      evidence.add('type dependency: $type');
    }
    super.visitNamedType(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toSource() ?? '';
    final name = node.methodName.name;
    final uiTarget = const {
      'Navigator',
      'ScaffoldMessenger',
      'MediaQuery',
      'Theme',
    }.any((value) => target.contains(value));
    if ((uiTarget && uiCalls.contains(name)) ||
        name == 'showDialog' ||
        name == 'showModalBottomSheet') {
      evidence.add(compactEvidence(node));
    }
    super.visitMethodInvocation(node);
  }
}
