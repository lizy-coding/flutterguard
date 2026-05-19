import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

import '../domain.dart';
import '../import_utils.dart';
import '../path_utils.dart';
import '../priority.dart';
import '../static_issue.dart';

enum _Color { white, gray, black }

class CircularDependencyRule {
  final bool enabled;
  final String? projectPath;

  const CircularDependencyRule({this.enabled = true, this.projectPath});

  List<StaticIssue> analyze(List<String> files) {
    if (!enabled || files.length < 2) return [];

    final fileSet = {
      for (final file in files) normalizePath(file),
    };
    final graph = <String, Set<String>>{};

    for (final file in fileSet) {
      try {
        final content = File(file).readAsStringSync();
        final result = parseString(content: content, path: file);
        final deps = _extractDeps(file, result.unit, fileSet);
        graph[file] = deps;
      } catch (_) {
        graph[file] = {};
      }
    }

    return _findCycles(graph, fileSet);
  }

  Set<String> _extractDeps(
    String sourceFile,
    CompilationUnit unit,
    Set<String> fileSet,
  ) {
    final deps = <String>{};
    final imports = unit.directives.whereType<ImportDirective>();

    for (final import in imports) {
      final importStr = import.uri.stringValue;
      if (importStr == null) continue;

      final resolved = resolveImport(
        sourceFile,
        importStr,
        fileSet,
        projectPath: projectPath,
      );
      if (resolved != null && resolved != sourceFile) {
        deps.add(resolved);
      }
    }

    return deps;
  }

  List<StaticIssue> _findCycles(
    Map<String, Set<String>> graph,
    Set<String> fileSet,
  ) {
    final issues = <StaticIssue>[];
    final color = <String, _Color>{};
    final parent = <String, String?>{};

    _Color getColor(String node) => color[node] ?? _Color.white;

    void dfs(String node) {
      color[node] = _Color.gray;

      for (final neighbor in graph[node] ?? <String>{}) {
        if (!graph.containsKey(neighbor)) continue;

        if (getColor(neighbor) == _Color.gray) {
          final cycle = _reconstructCycle(node, neighbor, parent, graph);
          if (cycle.length >= 2) {
            issues.add(_buildCycleIssue(cycle));
          }
        } else if (getColor(neighbor) == _Color.white) {
          parent[neighbor] = node;
          dfs(neighbor);
        }
      }

      color[node] = _Color.black;
    }

    for (final node in graph.keys) {
      if (getColor(node) == _Color.white) {
        parent[node] = null;
        dfs(node);
      }
    }

    return issues;
  }

  List<String> _reconstructCycle(
    String start,
    String end,
    Map<String, String?> parent,
    Map<String, Set<String>> graph,
  ) {
    final cycle = <String>[start];
    var current = start;

    while (current != end) {
      final prev = parent[current];
      if (prev == null || prev == current) break;
      cycle.add(prev);
      current = prev;
    }
    cycle.add(end);

    return cycle.reversed.toList();
  }

  StaticIssue _buildCycleIssue(List<String> cycle) {
    final cycleStr = cycle.map((f) => p.basename(f)).join(' → ');

    return StaticIssue(
      id: 'circular_dependency',
      title: '循环依赖',
      file: cycle.first,
      line: null,
      level: RiskLevel.medium,
      domain: IssueDomain.architecture,
      priority: Priority.p1,
      message: '检测到循环依赖: $cycleStr',
      detail: '依赖链:\n${cycle.map((f) => '  $f').join('\n')}',
      suggestion: '将循环中公共的依赖提取到 core/ 层，或使用依赖反转（接口抽象）打破循环',
      metadata: {
        'cycle': cycle,
      },
    );
  }
}
