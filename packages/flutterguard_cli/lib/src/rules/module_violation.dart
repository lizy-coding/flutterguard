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

class ModuleViolationRule {
  final List<ModuleConfig> modules;
  final String? projectPath;

  const ModuleViolationRule(this.modules, {this.projectPath});

  List<StaticIssue> analyze(List<String> files) {
    if (modules.isEmpty) return [];

    final fileToModule = <String, ModuleConfig>{};
    final fileSet = {
      for (final file in files) normalizePath(file),
    };

    for (final file in fileSet) {
      for (final module in modules) {
        try {
          final matches = projectPath == null
              ? Glob(module.path.replaceAll('\\', '/')).matches(file)
              : matchesProjectGlob(file, module.path, projectPath!);
          if (matches) {
            fileToModule[file] = module;
            break;
          }
        } catch (_) {}
      }
    }

    final issues = <StaticIssue>[];
    for (final file in fileSet) {
      final sourceModule = fileToModule[file];
      if (sourceModule == null) continue;

      try {
        final content = File(file).readAsStringSync();
        final result = parseString(content: content, path: file);
        issues.addAll(_checkImports(
          file,
          sourceModule,
          result.unit,
          result.lineInfo,
          fileToModule,
          fileSet,
        ));
      } catch (_) {}
    }

    return issues;
  }

  List<StaticIssue> _checkImports(
    String sourceFile,
    ModuleConfig sourceModule,
    CompilationUnit unit,
    LineInfo lineInfo,
    Map<String, ModuleConfig> fileToModule,
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

      final targetModule = fileToModule[resolved];
      if (targetModule == null) continue;
      if (targetModule.name == sourceModule.name) continue;

      if (!sourceModule.allowedDeps.contains(targetModule.name)) {
        final line = lineNumberForOffset(lineInfo, import.uri.offset);
        final allowedStr = sourceModule.allowedDeps.isEmpty
            ? '无'
            : sourceModule.allowedDeps.join(', ');

        issues.add(StaticIssue(
          id: 'module_violation',
          title: '模块间非法依赖',
          file: sourceFile,
          line: line,
          level: RiskLevel.high,
          domain: IssueDomain.architecture,
          priority: Priority.p0,
          message: '模块 ${sourceModule.name} 不可依赖模块 ${targetModule.name}',
          detail: '导入: $importStr\n'
              '源模块: ${sourceModule.name} (${sourceModule.path})\n'
              '目标模块: ${targetModule.name} (${targetModule.path})\n'
              '允许依赖: $allowedStr',
          suggestion:
              '通过 ${sourceModule.allowedDeps.isEmpty ? 'core 层共享接口解耦' : '${sourceModule.allowedDeps.join(' 或 ')}解耦'}',
          metadata: {
            'sourceModule': sourceModule.name,
            'targetModule': targetModule.name,
            'imported': importStr,
            'allowedDeps': sourceModule.allowedDeps,
          },
        ));
      }
    }

    return issues;
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
