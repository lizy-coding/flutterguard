import '../boundary_engine.dart';
import '../config_loader.dart';
import '../domain.dart';
import '../import_graph.dart';
import '../priority.dart';
import '../rule_meta.dart';
import '../source_workspace.dart';
import '../static_issue.dart';

class LayerViolationRule {
  final List<LayerConfig> layers;
  final String? projectPath;

  const LayerViolationRule(this.layers, {this.projectPath});

  List<StaticIssue> analyze(
    List<String> files, {
    List<String>? allFiles,
    SourceWorkspace? workspace,
    ImportGraph? importGraph,
  }) {
    if (layers.isEmpty) return [];

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
      for (final layer in layers)
        BoundaryDefinition(
          name: layer.name,
          path: layer.path,
          allowedDeps: layer.allowedDeps,
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
          id: 'layer_violation',
          title: '层间依赖违规',
          file: violation.edge.source,
          line: violation.edge.line,
          level: RiskLevel.high,
          domain: IssueDomain.architecture,
          priority: Priority.p0,
          message: '${violation.source.name} 层不可依赖 ${violation.target.name} 层',
          detail: '导入: ${violation.edge.uri}\n'
              '源层: ${violation.source.name} (${violation.source.path})\n'
              '目标层: ${violation.target.name} (${violation.target.path})\n'
              '允许依赖: ${violation.source.allowedDeps.isEmpty ? '无' : violation.source.allowedDeps.join(', ')}',
          suggestion:
              '将导入的内容移至 ${violation.source.allowedDeps.isEmpty ? 'core 或更抽象层' : '${violation.source.allowedDeps.join(' 或 ')}层'}',
          metadata: {
            'sourceLayer': violation.source.name,
            'targetLayer': violation.target.name,
            'imported': violation.edge.uri,
            'allowedDeps': violation.source.allowedDeps,
          },
        ),
    ];
  }

  static RuleMeta describe() => const RuleMeta(
        id: 'layer_violation',
        name: '层间依赖违规',
        domain: 'architecture',
        riskLevel: 'high',
        priority: 'p0',
        purpose: '检测架构层之间的非法依赖',
        riskReason: '违反分层架构导致耦合增加，难以维护和替换',
        badExample: 'presentation 层直接导入 data 层的实现',
        fixSuggestion: '将跨层调用通过抽象接口进行，或调整 allowed_deps 配置',
        configKeys: ['architecture.layers'],
        cicdSafe: true,
      );
}
