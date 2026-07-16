import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../import_utils.dart';
import '../path_utils.dart';
import '../rule_meta.dart';
import '../source_workspace.dart';
import '../static_issue.dart';
import 'state_management_utils.dart';

class StateDependencyCycleRule {
  final StateRuleConfig config;
  final StateManagementConfig stateManagement;
  final String projectPath;

  const StateDependencyCycleRule(
    this.config,
    this.stateManagement, {
    required this.projectPath,
  });

  List<StaticIssue> analyze(
    List<String> allFiles, {
    List<String>? targetFiles,
    bool changedOnly = false,
    SourceWorkspace? workspace,
  }) {
    if (!stateRuleEnabled(config, stateManagement)) return [];
    final sources = workspace ?? SourceWorkspace();
    final normalizedFiles = allFiles.map(normalizePath).toSet();
    final units = <({String file, SourceUnit source})>[];
    final nodes = <String, _StateGraphNode>{};
    final names = <String, List<String>>{};

    void register(_StateGraphNode node) {
      nodes[node.id] = node;
      names.putIfAbsent(node.name, () => <String>[]).add(node.id);
    }

    for (final file in normalizedFiles) {
      if (shouldIgnoreStateFile(file, projectPath, config)) continue;
      final source = sources.source(file);
      if (source == null) continue;
      units.add((file: source.path, source: source));
      for (final cls
          in source.unit.declarations.whereType<ClassDeclaration>()) {
        register(_StateGraphNode(
          id: _nodeId(source.path, 'class', cls.name.lexeme),
          name: cls.name.lexeme,
          file: source.path,
          anchor: cls,
          isState: isStateOwnerClass(cls),
        ));
      }
      for (final declaration in source.unit.declarations
          .whereType<TopLevelVariableDeclaration>()) {
        for (final variable in declaration.variables.variables) {
          final initializer = variable.initializer;
          if (initializer != null && _isProviderDeclaration(initializer)) {
            register(_StateGraphNode(
              id: _nodeId(source.path, 'provider', variable.name.lexeme),
              name: variable.name.lexeme,
              file: source.path,
              anchor: variable,
              isState: true,
            ));
          }
        }
      }
    }

    for (final candidates in names.values) {
      candidates.sort();
    }
    final graph = <String, Set<String>>{
      for (final id in nodes.keys) id: <String>{},
    };
    final knownNames = names.keys.toSet();

    for (final item in units) {
      final importedFiles = _resolvedImports(
        item.source.unit,
        item.file,
        normalizedFiles,
      );
      for (final cls
          in item.source.unit.declarations.whereType<ClassDeclaration>()) {
        final ownerId = _nodeId(item.file, 'class', cls.name.lexeme);
        if (!nodes.containsKey(ownerId)) continue;
        final collector = _DependencyCollector(knownNames);
        cls.accept(collector);
        _addResolvedEdges(
          graph: graph,
          ownerId: ownerId,
          dependencyNames: collector.dependencies,
          sourceFile: item.file,
          importedFiles: importedFiles,
          nodes: nodes,
          names: names,
        );
      }
      for (final declaration in item.source.unit.declarations
          .whereType<TopLevelVariableDeclaration>()) {
        for (final variable in declaration.variables.variables) {
          final initializer = variable.initializer;
          final ownerId = _nodeId(
            item.file,
            'provider',
            variable.name.lexeme,
          );
          if (initializer == null || !nodes.containsKey(ownerId)) continue;
          final collector = _DependencyCollector(knownNames);
          initializer.accept(collector);
          _addResolvedEdges(
            graph: graph,
            ownerId: ownerId,
            dependencyNames: collector.dependencies,
            sourceFile: item.file,
            importedFiles: importedFiles,
            nodes: nodes,
            names: names,
          );
        }
      }
    }

    _applyEdgeAllowlist(graph, nodes, names);

    final targetSet = (targetFiles ?? allFiles).map(normalizePath).toSet();
    final issues = <StaticIssue>[];
    for (final component in _stronglyConnectedComponents(graph)) {
      if (component.length < 2 || !component.any((id) => nodes[id]!.isState)) {
        continue;
      }
      final changedNodes = component
          .where((id) => targetSet.contains(nodes[id]!.file))
          .toList()
        ..sort();
      if (changedOnly && changedNodes.isEmpty) continue;
      final cycleIds = _shortestCycle(component, graph);
      if (cycleIds.isEmpty) continue;
      final anchorId = changedOnly ? changedNodes.first : cycleIds.first;
      final anchor = nodes[anchorId]!;
      final cycle = [
        for (final id in cycleIds) _displayName(nodes[id]!, names),
      ];
      final componentNames = [
        for (final id in component) _displayName(nodes[id]!, names),
      ]..sort();
      final source = sources.source(anchor.file);
      if (source == null) continue;
      issues.add(StaticIssue(
        id: 'state_dependency_cycle',
        title: '状态依赖环',
        file: anchor.file,
        line: sourceLine(source, anchor.anchor),
        level: config.severity,
        domain: IssueDomain.architecture,
        priority: priorityForSeverity(config.severity),
        message: '状态依赖形成环: ${cycle.join(' -> ')}',
        suggestion: '提取单向协调器或接口，移除环中的一条状态依赖边',
        evidence: [cycle.join(' -> ')],
        metadata: {'cycle': cycle, 'nodes': componentNames},
      ));
    }
    return issues;
  }

  static String _nodeId(String file, String kind, String name) =>
      '${normalizePath(file)}::$kind::$name';

  Set<String> _resolvedImports(
    CompilationUnit unit,
    String file,
    Set<String> allFiles,
  ) {
    final result = <String>{};
    for (final directive in unit.directives.whereType<ImportDirective>()) {
      final uri = directive.uri.stringValue;
      if (uri == null) continue;
      final resolved = resolveImport(
        file,
        uri,
        allFiles,
        projectPath: projectPath,
      );
      if (resolved != null) result.add(normalizePath(resolved));
    }
    return result;
  }

  static void _addResolvedEdges({
    required Map<String, Set<String>> graph,
    required String ownerId,
    required Set<String> dependencyNames,
    required String sourceFile,
    required Set<String> importedFiles,
    required Map<String, _StateGraphNode> nodes,
    required Map<String, List<String>> names,
  }) {
    for (final name in dependencyNames) {
      final dependencyId = _resolveNode(
        name: name,
        sourceFile: sourceFile,
        importedFiles: importedFiles,
        nodes: nodes,
        names: names,
      );
      if (dependencyId != null && dependencyId != ownerId) {
        graph[ownerId]!.add(dependencyId);
      }
    }
  }

  static String? _resolveNode({
    required String name,
    required String sourceFile,
    required Set<String> importedFiles,
    required Map<String, _StateGraphNode> nodes,
    required Map<String, List<String>> names,
  }) {
    final candidates = names[name] ?? const <String>[];
    if (candidates.isEmpty) return null;
    final normalizedSource = normalizePath(sourceFile);
    final local =
        candidates.where((id) => nodes[id]!.file == normalizedSource).toList();
    if (local.length == 1) return local.single;
    final imported = candidates
        .where((id) => importedFiles.contains(nodes[id]!.file))
        .toList();
    if (imported.length == 1) return imported.single;
    return candidates.length == 1 ? candidates.single : null;
  }

  void _applyEdgeAllowlist(
    Map<String, Set<String>> graph,
    Map<String, _StateGraphNode> nodes,
    Map<String, List<String>> names,
  ) {
    final allowed = <({String source, String target})>[];
    for (final entry in config.allowlist) {
      final parts = entry.split('->');
      if (parts.length == 2) {
        allowed.add((source: parts[0], target: parts[1]));
      }
    }
    for (final edge in graph.entries) {
      final source = nodes[edge.key]!;
      edge.value.removeWhere((targetId) {
        final target = nodes[targetId]!;
        return allowed.any(
          (entry) =>
              _matchesAllowlistName(entry.source, source, names) &&
              _matchesAllowlistName(entry.target, target, names),
        );
      });
    }
  }

  bool _matchesAllowlistName(
    String configured,
    _StateGraphNode node,
    Map<String, List<String>> names,
  ) =>
      configured == node.name || configured == _displayName(node, names);

  String _displayName(
    _StateGraphNode node,
    Map<String, List<String>> names,
  ) {
    if ((names[node.name]?.length ?? 0) <= 1) return node.name;
    final path =
        projectRelativePath(node.file, projectPath).replaceAll('\\', '/');
    return '$path::${node.name}';
  }

  static bool _isProviderDeclaration(Expression initializer) {
    final source = initializer.toSource();
    return RegExp(r'(^|\.)[A-Za-z]*Provider(?:<[^>]+>)?\s*\(').hasMatch(source);
  }

  static List<Set<String>> _stronglyConnectedComponents(
    Map<String, Set<String>> graph,
  ) {
    var index = 0;
    final indices = <String, int>{};
    final lowlink = <String, int>{};
    final stack = <String>[];
    final onStack = <String>{};
    final result = <Set<String>>[];

    void connect(String node) {
      indices[node] = index;
      lowlink[node] = index;
      index++;
      stack.add(node);
      onStack.add(node);
      final neighbors = (graph[node] ?? const <String>{}).toList()..sort();
      for (final next in neighbors) {
        if (!indices.containsKey(next)) {
          connect(next);
          lowlink[node] =
              lowlink[node]! < lowlink[next]! ? lowlink[node]! : lowlink[next]!;
        } else if (onStack.contains(next)) {
          lowlink[node] =
              lowlink[node]! < indices[next]! ? lowlink[node]! : indices[next]!;
        }
      }
      if (lowlink[node] != indices[node]) return;
      final component = <String>{};
      while (stack.isNotEmpty) {
        final current = stack.removeLast();
        onStack.remove(current);
        component.add(current);
        if (current == node) break;
      }
      result.add(component);
    }

    final ids = graph.keys.toList()..sort();
    for (final id in ids) {
      if (!indices.containsKey(id)) connect(id);
    }
    return result;
  }

  static List<String> _shortestCycle(
    Set<String> component,
    Map<String, Set<String>> graph,
  ) {
    List<String>? best;
    final starts = component.toList()..sort();
    for (final start in starts) {
      final queue = Queue<List<String>>()..add([start]);
      final shortestDepth = <String, int>{start: 0};
      while (queue.isNotEmpty) {
        final path = queue.removeFirst();
        final current = path.last;
        final neighbors = (graph[current] ?? const <String>{})
            .where(component.contains)
            .toList()
          ..sort();
        for (final next in neighbors) {
          if (next == start && path.length > 1) {
            final candidate = [...path, start];
            if (best == null ||
                candidate.length < best.length ||
                candidate.length == best.length &&
                    candidate.join('\u0000').compareTo(best.join('\u0000')) <
                        0) {
              best = candidate;
            }
            continue;
          }
          if (path.contains(next)) continue;
          final depth = path.length;
          if ((shortestDepth[next] ?? 1 << 30) < depth) continue;
          shortestDepth[next] = depth;
          queue.add([...path, next]);
        }
      }
    }
    return best ?? const [];
  }

  static RuleMeta describe() => const RuleMeta(
        id: 'state_dependency_cycle',
        name: '状态依赖环',
        domain: 'architecture',
        riskLevel: 'high',
        priority: 'p0',
        purpose: '检测 Provider、状态 owner 与其项目内依赖形成的强连通环',
        riskReason: '依赖环导致初始化顺序不确定、递归更新和难以隔离的测试',
        badExample: 'AuthController -> SessionProvider -> AuthController',
        fixSuggestion: '提取协调器或接口，使依赖保持单向',
        configKeys: ['enabled', 'severity', 'allowlist', 'ignore_paths'],
      );
}

class _StateGraphNode {
  final String id;
  final String name;
  final String file;
  final AstNode anchor;
  final bool isState;

  const _StateGraphNode({
    required this.id,
    required this.name,
    required this.file,
    required this.anchor,
    required this.isState,
  });
}

class _DependencyCollector extends RecursiveAstVisitor<void> {
  final Set<String> knownNames;
  final dependencies = <String>{};

  _DependencyCollector(this.knownNames);

  @override
  void visitNamedType(NamedType node) {
    final type = simpleTypeName(node.toSource());
    if (knownNames.contains(type)) dependencies.add(type);
    super.visitNamedType(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = simpleTypeName(node.constructorName.type.toSource());
    if (knownNames.contains(type)) dependencies.add(type);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'watch' || name == 'read') {
      if (node.argumentList.arguments.isNotEmpty) {
        final dependency = node.argumentList.arguments.first.toSource();
        final simple = dependency.split('.').first;
        if (knownNames.contains(simple)) dependencies.add(simple);
      }
    }
    final typeArguments = node.typeArguments?.arguments ?? const [];
    for (final argument in typeArguments) {
      final type = simpleTypeName(argument.toSource());
      if (knownNames.contains(type)) dependencies.add(type);
    }
    super.visitMethodInvocation(node);
  }
}
