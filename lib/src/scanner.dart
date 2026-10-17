import 'dart:io';

import 'package:path/path.dart' as p;

import 'baseline.dart';
import 'config_loader.dart';
import 'config_tools.dart';
import 'file_collector.dart';
import 'path_utils.dart';
import 'project_resolver.dart';
import 'report_generator.dart';
import 'scan_context.dart';
import 'rules/registry.dart';
import 'sarif_report.dart';
import 'static_issue.dart';
import 'source_workspace.dart';
import 'suppression.dart';

class ScanException implements Exception {
  final String message;

  const ScanException(this.message);

  @override
  String toString() => message;
}

class ScanResult {
  final String projectPath;
  final String reportDir;
  final List<String> files;
  final List<StaticIssue> rawIssues;
  final List<StaticIssue> issues;
  final int suppressedCount;
  final int suppressedByBaselineCount;
  final String scanMode;
  final String? structuredOutput;
  final List<ScanDiagnostic> diagnostics;
  final SourceWorkspace sources;
  final Map<String, Object?> coverage;

  const ScanResult({
    required this.projectPath,
    required this.reportDir,
    required this.files,
    required this.rawIssues,
    required this.issues,
    required this.suppressedCount,
    required this.suppressedByBaselineCount,
    required this.scanMode,
    required this.sources,
    this.structuredOutput,
    this.coverage = const {},
    this.diagnostics = const [],
  });
}

class BoundaryLensScanner {
  static ScanResult scan({
    required String projectPath,
    String? configPath,
    String outputDir = '.boundarylens',
    bool writeJson = false,
    bool writeSarif = false,
    required bool writeStdout,
    bool changedOnly = false,
    String base = 'main',
    String? baselinePath,
    bool applySuppression = true,
  }) {
    if (writeStdout && !writeJson && !writeSarif) {
      throw const ScanException(
        '--stdout requires --format json or --format sarif',
      );
    }

    final scanTarget = ProjectResolver.resolveScanTarget(projectPath);
    final resolvedProjectPath = scanTarget.projectPath;
    if (!Directory(resolvedProjectPath).existsSync()) {
      throw ScanException(
        'Project path "$resolvedProjectPath" does not exist.',
      );
    }

    final resolvedConfigPath = ProjectResolver.resolveConfigPath(
      projectPath: resolvedProjectPath,
      explicitConfig: configPath,
    );
    final config = ScanConfig.fromFile(
      resolvedConfigPath,
      requireFile: configPath != null,
    );
    final files = FileCollector.collect(resolvedProjectPath, config);
    if (scanTarget.singleFile != null &&
        !files.contains(scanTarget.singleFile)) {
      files
        ..add(scanTarget.singleFile!)
        ..sort();
    }
    config.validateArchitecture(files, resolvedProjectPath);
    final configErrors = ConfigTools.validateRuleConfig(config);
    if (configErrors.isNotEmpty) {
      throw FormatException(configErrors.map((m) => m.message).join('\n'));
    }
    if (files.isEmpty) {
      throw const ScanException(
        'No Dart files matched the configured include/exclude patterns.',
      );
    }
    var scanMode = ScanMode.full;
    var filesToScan = scanTarget.singleFile == null
        ? files
        : <String>[scanTarget.singleFile!];
    var changedFiles = <String>{};

    if (changedOnly) {
      try {
        final changed = FileCollector.getChangedFiles(
          resolvedProjectPath,
          base,
        );
        if (changed != null) {
          changedFiles = changed.map(normalizePath).toSet();
          final changedDart = changedFiles
              .where((f) => f.endsWith('.dart'))
              .toSet();
          filesToScan = filesToScan
              .where((f) => changedDart.contains(f))
              .toList();
          scanMode = ScanMode.changed;
        }
      } on ChangedFilesException catch (e) {
        throw ScanException(e.message);
      }
    }

    final reportDir = p.isAbsolute(outputDir)
        ? outputDir
        : p.join(resolvedProjectPath, outputDir);

    final sources = SourceWorkspace();
    final context = ScanContext(
      projectPath: resolvedProjectPath,
      config: config,
      allFiles: files,
      targetFiles: filesToScan,
      mode: scanMode,
      sources: sources,
      changedFiles: changedFiles,
      scope: scanTarget.singleFile != null
          ? RuleScope.file
          : (scanMode == ScanMode.changed
                ? RuleScope.changed
                : RuleScope.project),
    );
    final execution = RuleRegistry.run(context);
    final rawIssues = _sortIssues(execution.issues);
    final coverage = {
      ..._coverage(context, context.scope.name),
      'rules': execution.coverage,
    };

    var issues = rawIssues;
    var suppressedCount = 0;
    if (applySuppression) {
      final suppression = SuppressionFilter(filesToScan, workspace: sources);
      final visible = <StaticIssue>[];
      for (final issue in issues) {
        if (suppression.isSuppressed(issue)) {
          suppressedCount++;
        } else {
          visible.add(issue);
        }
      }
      issues = visible;
    }

    var suppressedByBaselineCount = 0;
    if (baselinePath != null) {
      final resolvedBaselinePath = p.isAbsolute(baselinePath)
          ? baselinePath
          : p.join(resolvedProjectPath, baselinePath);
      final baseline = Baseline.load(resolvedBaselinePath);
      final visible = <StaticIssue>[];
      for (final issue in issues) {
        if (baseline.contains(issue, resolvedProjectPath)) {
          suppressedByBaselineCount++;
        } else {
          visible.add(issue);
        }
      }
      issues = visible;
    }

    if (!writeStdout && (writeJson || writeSarif)) {
      Directory(reportDir).createSync(recursive: true);
    }
    String? structuredOutput;
    if (writeJson) {
      final json = ReportGenerator.generateJson(
        projectPath: resolvedProjectPath,
        issues: issues,
        scanMode: scanMode.name,
        suppressedCount: suppressedCount,
        suppressedByBaselineCount: suppressedByBaselineCount,
        diagnostics: sources.diagnostics,
        coverage: coverage,
      );
      if (writeStdout) {
        structuredOutput = json;
      } else {
        File(p.join(reportDir, 'report.json')).writeAsStringSync(json);
      }
    }
    if (writeSarif) {
      final sarif = SarifReport.generate(
        coverage: coverage,
        diagnostics: sources.diagnostics,
        projectPath: resolvedProjectPath,
        issues: issues,
      );
      if (writeStdout) {
        structuredOutput = sarif;
      } else {
        File(p.join(reportDir, 'report.sarif')).writeAsStringSync(sarif);
      }
    }

    return ScanResult(
      projectPath: resolvedProjectPath,
      reportDir: reportDir,
      files: filesToScan,
      rawIssues: rawIssues,
      issues: issues,
      suppressedCount: suppressedCount,
      suppressedByBaselineCount: suppressedByBaselineCount,
      scanMode: scanMode.name,
      structuredOutput: structuredOutput,
      sources: sources,
      diagnostics: sources.diagnostics,
      coverage: coverage,
    );
  }

  static Map<String, Object?> _coverage(ScanContext context, String scope) {
    final modules = context.config.architecture.modules;
    final enabled = context.config
        .rule('module_violation', defaultSeverity: RiskLevel.high)
        .enabled;
    final owned = context.targetFiles
        .where(
          (file) => modules.any(
            (m) => matchesProjectGlob(file, m.path, context.projectPath),
          ),
        )
        .length;
    final reasons = <String>[];
    if (modules.any((m) => m.entryPoints == null)) {
      reasons.add('entry_points_not_declared');
    }
    if (modules.any(
      (m) => !context.allFiles.any(
        (f) => matchesProjectGlob(f, m.path, context.projectPath),
      ),
    )) {
      reasons.add('module_has_no_selected_files');
    }
    if (context.sources.diagnostics.isNotEmpty) reasons.add('scan_diagnostics');
    final status = !enabled
        ? 'disabled'
        : modules.isEmpty
        ? 'not_configured'
        : reasons.isEmpty
        ? 'complete'
        : 'partial';
    return {
      'moduleBoundary': {
        'status': status,
        'scope': scope,
        'checkedFiles': enabled ? owned : 0,
        'totalFiles': context.allFiles.length,
        'reasons': reasons,
      },
    };
  }

  static List<StaticIssue> _sortIssues(List<StaticIssue> allIssues) {
    allIssues.sort((a, b) {
      final levelOrder = {
        RiskLevel.high: 0,
        RiskLevel.medium: 1,
        RiskLevel.low: 2,
      };
      final levelCompare = levelOrder[a.level]!.compareTo(levelOrder[b.level]!);
      if (levelCompare != 0) return levelCompare;
      final fileCompare = a.file.compareTo(b.file);
      if (fileCompare != 0) return fileCompare;
      return (a.line ?? 0).compareTo(b.line ?? 0);
    });

    return allIssues;
  }
}
