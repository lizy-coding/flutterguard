import '../boundary_engine.dart';
import '../config_loader.dart';
import '../domain.dart';
import '../import_graph.dart';
import '../priority.dart';
import '../rule_meta.dart';
import '../source_workspace.dart';
import '../static_issue.dart';

class ModuleViolationRule {
  final List<ModuleConfig> modules;
  final String? projectPath;

  const ModuleViolationRule(this.modules, {this.projectPath});

  List<StaticIssue> analyze(
    List<String> files, {
    List<String>? allFiles,
    SourceWorkspace? workspace,
    ImportGraph? importGraph,
  }) {
    if (modules.isEmpty) return [];
    final sources = workspace ?? SourceWorkspace();
    final availableFiles = allFiles ?? files;
    final graph = importGraph ??
        ImportGraph.build(
          files: availableFiles,
          sourceFiles: files,
          workspace: sources,
          projectPath: projectPath,
        );
    final boundaries = [
      for (final module in modules)
        BoundaryDefinition(
          name: module.name,
          path: module.path,
          allowedDeps: module.allowedDeps,
        ),
    ];
    final violations = DependencyBoundaryEngine.analyze(
      sourceFiles: files,
      allFiles: availableFiles,
      boundaries: boundaries,
      graph: graph,
      workspace: sources,
      projectPath: projectPath,
    );

    return [
      for (final violation in violations)
        StaticIssue(
          id: 'module_violation',
          title: '模块间非法依赖',
          file: violation.edge.source,
          line: violation.edge.line,
          level: RiskLevel.high,
          domain: IssueDomain.architecture,
          priority: Priority.p0,
          message:
              '模块 ${violation.source.name} 不可依赖模块 ${violation.target.name}',
          detail: '导入: ${violation.edge.uri}\n'
              '源模块: ${violation.source.name} (${violation.source.path})\n'
              '目标模块: ${violation.target.name} (${violation.target.path})\n'
              '允许依赖: ${violation.source.allowedDeps.isEmpty ? '无' : violation.source.allowedDeps.join(', ')}',
          suggestion:
              '通过 ${violation.source.allowedDeps.isEmpty ? 'core 层共享接口解耦' : '${violation.source.allowedDeps.join(' 或 ')}解耦'}',
          metadata: {
            'sourceModule': violation.source.name,
            'targetModule': violation.target.name,
            'imported': violation.edge.uri,
            'allowedDeps': violation.source.allowedDeps,
          },
        ),
    ];
  }

  static RuleMeta describe() => const RuleMeta(
        id: 'module_violation',
        name: '模块间依赖违规',
        domain: 'architecture',
        riskLevel: 'high',
        priority: 'p0',
        purpose: '检测业务模块之间的非法依赖',
        riskReason: '模块间非法依赖破坏隔离性，导致耦合和回归风险',
        badExample: 'mqtt 模块直接导入 ble 模块的类',
        fixSuggestion: '提取公共依赖到 shared 模块，或通过事件总线解耦',
        configKeys: ['architecture.modules'],
        cicdSafe: true,
      );
}
