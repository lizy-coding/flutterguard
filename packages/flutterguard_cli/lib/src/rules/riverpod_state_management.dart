import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../rule_meta.dart';
import '../source_workspace.dart';
import '../static_issue.dart';
import 'state_management_utils.dart';

class RiverpodReadUsedForRenderRule {
  final StateRuleConfig config;
  final StateManagementConfig stateManagement;
  final String projectPath;

  const RiverpodReadUsedForRenderRule(
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
      if (source == null ||
          !frameworkAllowed(
            source.unit,
            StateManagementFramework.riverpod,
            stateManagement,
          )) {
        continue;
      }
      for (final root in buildRoots(source.unit)) {
        final reads = _RiverpodReadCollector(root.body)..collect();
        for (final finding in reads.findings) {
          if (config.allowlist.contains(finding.provider)) continue;
          issues.add(StaticIssue(
            id: 'riverpod_read_used_for_render',
            title: '使用 ref.read 驱动渲染',
            file: file,
            line: sourceLine(source, finding.read),
            level: config.severity,
            domain: IssueDomain.performance,
            priority: priorityForSeverity(config.severity),
            message: 'ref.read 的结果进入了渲染路径，后续状态变化不会触发重建',
            suggestion: '在渲染路径使用 ref.watch；命令调用继续使用 ref.read',
            framework: StateManagementFramework.riverpod,
            evidence: limitedEvidence(finding.sinks),
            metadata: {'provider': finding.provider},
          ));
        }
      }
    }
    return issues;
  }

  static RuleMeta describe() => const RuleMeta(
        id: 'riverpod_read_used_for_render',
        name: 'ref.read 驱动渲染',
        domain: 'performance',
        riskLevel: 'medium',
        priority: 'p1',
        purpose: '检测 build 中使用 ref.read 的值构造 Widget 或控制条件渲染',
        riskReason: 'read 不订阅 Provider，状态变化后界面可能保持陈旧',
        badExample: 'Text(ref.read(deviceProvider).name)',
        fixSuggestion: '渲染数据改用 ref.watch',
        configKeys: ['enabled', 'severity', 'allowlist', 'ignore_paths'],
        framework: 'riverpod',
      );
}

class _ReadFinding {
  final MethodInvocation read;
  final String provider;
  final List<String> sinks;

  const _ReadFinding(this.read, this.provider, this.sinks);
}

class _RiverpodReadCollector {
  final AstNode root;
  final findings = <_ReadFinding>[];

  _RiverpodReadCollector(this.root);

  void collect() {
    final visitor = _ReadInvocationVisitor(root);
    root.accept(visitor);
    for (final read in visitor.reads) {
      final provider = read.argumentList.arguments.isEmpty
          ? ''
          : read.argumentList.arguments.first.toSource();
      final sinks = <String>[];
      if (_isRenderSink(read, root)) {
        sinks.add(
            'render sink: ${compactEvidence(_nearestRenderNode(read, root))}');
      }
      final variable = _assignedVariable(read);
      if (variable != null) {
        final usages = _IdentifierUsageVisitor(variable, root)..scan();
        for (final usage in usages.renderUsages) {
          sinks.add('render use of $variable: ${compactEvidence(
            _nearestRenderNode(usage, root),
          )}');
        }
      }
      if (sinks.isNotEmpty) findings.add(_ReadFinding(read, provider, sinks));
    }
  }

  static String? _assignedVariable(MethodInvocation read) {
    AstNode? current = read.parent;
    while (current != null) {
      if (current is VariableDeclaration && current.initializer != null) {
        return current.name.lexeme;
      }
      if (current is Statement || current is FunctionBody) break;
      current = current.parent;
    }
    return null;
  }

  static bool _isRenderSink(AstNode node, AstNode root) {
    AstNode? current = node;
    while (current != null && current != root) {
      if (current is FunctionExpression) return false;
      if (current is ReturnStatement ||
          current is IfStatement ||
          current is ConditionalExpression ||
          current is IfElement ||
          current is ForElement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  static AstNode _nearestRenderNode(AstNode node, AstNode root) {
    AstNode current = node;
    while (current.parent != null && current.parent != root) {
      final parent = current.parent!;
      if (parent is ReturnStatement ||
          parent is IfStatement ||
          parent is ConditionalExpression ||
          parent is IfElement ||
          parent is ForElement) {
        return parent;
      }
      current = parent;
    }
    return current;
  }
}

class _ReadInvocationVisitor extends RecursiveAstVisitor<void> {
  final AstNode root;
  final reads = <MethodInvocation>[];

  _ReadInvocationVisitor(this.root);

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node == root) super.visitFunctionExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'read' && node.target?.toSource() == 'ref') {
      reads.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

class _IdentifierUsageVisitor extends RecursiveAstVisitor<void> {
  final String name;
  final AstNode root;
  final renderUsages = <SimpleIdentifier>[];

  _IdentifierUsageVisitor(this.name, this.root);

  void scan() => root.accept(this);

  @override
  void visitFunctionExpression(FunctionExpression node) {}

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name &&
        node.parent is! VariableDeclaration &&
        _RiverpodReadCollector._isRenderSink(node, root)) {
      renderUsages.add(node);
    }
    super.visitSimpleIdentifier(node);
  }
}

class RiverpodWatchInCallbackRule {
  final StateRuleConfig config;
  final StateManagementConfig stateManagement;
  final String projectPath;

  const RiverpodWatchInCallbackRule(
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
      if (source == null ||
          !frameworkAllowed(
            source.unit,
            StateManagementFramework.riverpod,
            stateManagement,
          )) {
        continue;
      }
      final visitor = _WatchCallbackVisitor();
      source.unit.accept(visitor);
      for (final callback in visitor.callbacks) {
        final watches = callback.watches.where((watch) {
          final provider = watch.argumentList.arguments.isEmpty
              ? ''
              : watch.argumentList.arguments.first.toSource();
          return !config.allowlist.contains(provider);
        }).toList();
        if (watches.isEmpty) continue;
        issues.add(StaticIssue(
          id: 'riverpod_watch_in_callback',
          title: '回调中调用 ref.watch',
          file: file,
          line: sourceLine(source, callback.function),
          level: config.severity,
          domain: IssueDomain.performance,
          priority: priorityForSeverity(config.severity),
          message: '事件或异步回调中调用 ref.watch，订阅不会形成有效渲染依赖',
          suggestion: '回调中使用 ref.read；只在 build/provider 声明中使用 ref.watch',
          framework: StateManagementFramework.riverpod,
          evidence: limitedEvidence(watches.map(compactEvidence)),
        ));
      }
    }
    return issues;
  }

  static RuleMeta describe() => const RuleMeta(
        id: 'riverpod_watch_in_callback',
        name: '回调中使用 ref.watch',
        domain: 'performance',
        riskLevel: 'medium',
        priority: 'p1',
        purpose: '检测事件、listener、timer 和异步回调中的 ref.watch',
        riskReason: '回调不是响应式构建范围，watch 的订阅语义无效或误导',
        badExample: 'onPressed: () => ref.watch(deviceProvider)',
        fixSuggestion: '回调改用 ref.read',
        configKeys: ['enabled', 'severity', 'allowlist', 'ignore_paths'],
        framework: 'riverpod',
      );
}

class _WatchCallbackFinding {
  final FunctionExpression function;
  final List<MethodInvocation> watches;

  const _WatchCallbackFinding(this.function, this.watches);
}

class _WatchCallbackVisitor extends RecursiveAstVisitor<void> {
  final callbacks = <_WatchCallbackFinding>[];

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (isCallbackFunction(node)) {
      final watches = _WatchInvocationVisitor();
      node.body.accept(watches);
      if (watches.nodes.isNotEmpty) {
        callbacks.add(_WatchCallbackFinding(node, watches.nodes));
      }
      return;
    }
    super.visitFunctionExpression(node);
  }
}

class _WatchInvocationVisitor extends RecursiveAstVisitor<void> {
  final nodes = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'watch' && node.target?.toSource() == 'ref') {
      nodes.add(node);
    }
    super.visitMethodInvocation(node);
  }
}
