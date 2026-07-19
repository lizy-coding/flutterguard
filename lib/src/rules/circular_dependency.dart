import 'package:path/path.dart' as p;

import '../import_graph.dart';
import 'rule.dart';
import '../source_workspace.dart';
import '../static_issue.dart';

enum _Color { white, gray, black }

class CircularDependencyRule {
  final bool enabled;
  final RiskLevel severity;
  final String? projectPath;

  const CircularDependencyRule({
    this.enabled = true,
    this.severity = RiskLevel.medium,
    this.projectPath,
  });

  List<StaticIssue> analyze(
    List<String> files, {
    SourceWorkspace? workspace,
    ImportGraph? importGraph,
  }) {
    if (!enabled || files.length < 2) return [];

    final sources = workspace ?? SourceWorkspace();
    final imports =
        importGraph ??
        ImportGraph.build(
          files: files,
          sourceFiles: files,
          workspace: sources,
          projectPath: projectPath,
        );
    final graph = {
      for (final file in imports.files) file: imports.dependenciesOf(file),
    };
    return _findCycles(graph);
  }

  List<StaticIssue> _findCycles(Map<String, Set<String>> graph) {
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
      level: severity,
      domain: IssueDomain.architecture,
      message: '检测到循环依赖: $cycleStr',
      detail: '依赖链:\n${cycle.map((f) => '  $f').join('\n')}',
      suggestion: '将循环中公共的依赖提取到 core/ 层，或使用依赖反转（接口抽象）打破循环',
      metadata: {'cycle': cycle},
    );
  }

  static RuleDefinition describe() => const RuleDefinition(
    id: 'circular_dependency',
    name: '循环依赖',
    domain: IssueDomain.architecture,
    defaultSeverity: RiskLevel.medium,
    purpose: '检测文件级别的循环 import',
    riskReason: '循环依赖导致编译耦合、无法单独测试和复用',
    badExample: 'a.dart → b.dart → c.dart → a.dart',
    fixSuggestion: '将公共依赖提取到 core 层，或使用接口反转打破循环',
  );
}
