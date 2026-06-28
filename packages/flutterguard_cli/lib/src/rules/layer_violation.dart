import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:glob/glob.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../import_utils.dart';
import '../path_utils.dart';
import '../priority.dart';
import '../rule_meta.dart';
import '../source_utils.dart';
import '../static_issue.dart';

class LayerViolationRule {
  final List<LayerConfig> layers;
  final String? projectPath;

  const LayerViolationRule(this.layers, {this.projectPath});

  List<StaticIssue> analyze(List<String> files) {
    if (layers.isEmpty) return [];

    final fileToLayer = <String, LayerConfig>{};
    final fileSet = {
      for (final file in files) normalizePath(file),
    };

    for (final file in fileSet) {
      for (final layer in layers) {
        try {
          final matches = projectPath == null
              ? Glob(layer.path.replaceAll('\\', '/')).matches(file)
              : matchesProjectGlob(file, layer.path, projectPath!);
          if (matches) {
            fileToLayer[file] = layer;
            break;
          }
        } catch (_) {}
      }
    }

    final issues = <StaticIssue>[];
    for (final file in fileSet) {
      final sourceLayer = fileToLayer[file];
      if (sourceLayer == null) continue;

      try {
        final content = File(file).readAsStringSync();
        final result = parseString(content: content, path: file);
        issues.addAll(_checkImports(
          file,
          sourceLayer,
          result.unit,
          result.lineInfo,
          fileToLayer,
          fileSet,
        ));
      } catch (_) {}
    }

    return issues;
  }

  List<StaticIssue> _checkImports(
    String sourceFile,
    LayerConfig sourceLayer,
    CompilationUnit unit,
    LineInfo lineInfo,
    Map<String, LayerConfig> fileToLayer,
    Set<String> fileSet,
  ) {
    final issues = <StaticIssue>[];
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
      if (resolved == null) continue;

      final targetLayer = fileToLayer[resolved];
      if (targetLayer == null) continue;
      if (targetLayer.name == sourceLayer.name) continue;

      if (!sourceLayer.allowedDeps.contains(targetLayer.name)) {
        final line = lineNumberForOffset(lineInfo, import.uri.offset);
        final allowedStr = sourceLayer.allowedDeps.isEmpty
            ? '无'
            : sourceLayer.allowedDeps.join(', ');

        issues.add(StaticIssue(
          id: 'layer_violation',
          title: '层间依赖违规',
          file: sourceFile,
          line: line,
          level: RiskLevel.high,
          domain: IssueDomain.architecture,
          priority: Priority.p0,
          message: '${sourceLayer.name} 层不可依赖 ${targetLayer.name} 层',
          detail: '导入: $importStr\n'
              '源层: ${sourceLayer.name} (${sourceLayer.path})\n'
              '目标层: ${targetLayer.name} (${targetLayer.path})\n'
              '允许依赖: $allowedStr',
          suggestion:
              '将导入的内容移至 ${sourceLayer.allowedDeps.isEmpty ? 'core 或更抽象层' : '${sourceLayer.allowedDeps.join(' 或 ')}层'}',
          metadata: {
            'sourceLayer': sourceLayer.name,
            'targetLayer': targetLayer.name,
            'imported': importStr,
            'allowedDeps': sourceLayer.allowedDeps,
          },
        ));
      }
    }

    return issues;
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
