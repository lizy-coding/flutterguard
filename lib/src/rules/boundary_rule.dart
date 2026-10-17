import '../boundary_engine.dart';
import '../config_loader.dart';
import '../import_graph.dart';
import '../source_workspace.dart';
import '../static_issue.dart';
import 'rule.dart';

enum BoundaryKind { layer, module }

class BoundaryRule {
  final BoundaryKind kind;
  final List<BoundaryConfig> boundaries;
  final RiskLevel severity;
  final String projectPath;

  const BoundaryRule({
    required this.kind,
    required this.boundaries,
    required this.severity,
    required this.projectPath,
  });

  List<StaticIssue> analyze(
    List<String> files, {
    required List<String> allFiles,
    required SourceWorkspace workspace,
    required ImportGraph importGraph,
  }) {
    final definitions = [
      for (final boundary in boundaries)
        BoundaryDefinition(
          name: boundary.name,
          path: boundary.path,
          allowedDeps: boundary.allowedDeps,
          entryPoints: boundary.entryPoints,
        ),
    ];
    final violations = DependencyBoundaryEngine.analyze(
      sourceFiles: files,
      allFiles: allFiles,
      boundaries: definitions,
      graph: importGraph,
      workspace: workspace,
      projectPath: projectPath,
      protectEntries: kind == BoundaryKind.module,
    );
    final label = kind == BoundaryKind.layer ? '层' : '模块';
    return [
      for (final violation in violations)
        StaticIssue(
          id: '${kind.name}_violation',
          title: '$label间依赖违规',
          file: violation.edge.source,
          line: violation.edge.line,
          level: severity,
          domain: IssueDomain.architecture,
          message: violation.reason == 'private_entry'
              ? '${violation.source.name} 模块绕过 ${violation.target.name} 的公开入口访问内部实现'
              : '${violation.source.name} $label不可依赖 ${violation.target.name} $label',
          detail:
              '导入: ${violation.edge.uri}\n'
              '源$label: ${violation.source.name} (${violation.source.path})\n'
              '目标$label: ${violation.target.name} (${violation.target.path})',
          suggestion: violation.reason == 'private_entry'
              ? (violation.target.entryPoints!.isEmpty
                    ? '目标模块未开放公开入口；移除跨模块引用或由模块维护者声明入口'
                    : '通过目标模块公开入口访问: ${violation.target.entryPoints!.join(', ')}')
              : '调整依赖方向，或通过允许的边界抽象解耦',
          metadata: {
            'kind': kind.name,
            'reason': violation.reason,
            'referenceKind': violation.edge.kind,
            'entryPoints': violation.target.entryPoints,
            'sourceBoundary': violation.source.name,
            'targetBoundary': violation.target.name,
            'imported': violation.edge.uri,
            'allowedDeps': violation.source.allowedDeps,
          },
        ),
    ];
  }

  static RuleDefinition definition(BoundaryKind kind) {
    final layer = kind == BoundaryKind.layer;
    return RuleDefinition(
      id: '${kind.name}_violation',
      name: layer ? '层间依赖违规' : '模块间依赖违规',
      domain: IssueDomain.architecture,
      defaultSeverity: RiskLevel.high,
      defaultEnabled: true,
      inputs: const {RuleInput.importGraph},
      activation: layer ? RuleActivation.layers : RuleActivation.modules,
      purpose: layer ? '检测架构层之间的非法依赖' : '检测模块依赖方向与绕过已声明公开入口的访问',
      riskReason: '非法边界依赖会破坏隔离并扩大变更影响范围',
      badExample: layer ? 'presentation 直接导入 data 实现' : 'mqtt 直接导入 ble 实现',
      fixSuggestion: '调整 allowed_deps，或提取稳定接口到允许依赖的边界',
    );
  }
}
