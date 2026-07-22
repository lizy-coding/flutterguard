import 'dart:io';

import 'package:path/path.dart' as p;

import 'baseline.dart';
import 'config_loader.dart';
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
  final List<ScanDiagnostic> diagnostics;
  final SourceWorkspace sources;

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
    this.diagnostics = const [],
  });
}

class FlutterGuardScanner {
  static ScanResult scan({
    required String projectPath,
    String? configPath,
    String outputDir = '.flutterguard',
    bool writeJson = false,
    bool writeSarif = false,
    bool changedOnly = false,
    String base = 'main',
    String? baselinePath,
    bool applySuppression = true,
  }) {
    final resolvedProjectPath = ProjectResolver.resolveProjectPath(projectPath);
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
    if (files.isEmpty) {
      throw const ScanException(
        'No Dart files matched the configured include/exclude patterns.',
      );
    }
    var scanMode = ScanMode.full;
    var filesToScan = files;
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
          filesToScan = files.where((f) => changedDart.contains(f)).toList();
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
    );
    final rawIssues = _analyze(context);

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

    if (writeJson || writeSarif) {
      Directory(reportDir).createSync(recursive: true);
    }
    if (writeJson) {
      final json = ReportGenerator.generateJson(
        projectPath: resolvedProjectPath,
        issues: issues,
        scanMode: scanMode.name,
        suppressedCount: suppressedCount,
        suppressedByBaselineCount: suppressedByBaselineCount,
        diagnostics: sources.diagnostics,
      );
      File(p.join(reportDir, 'report.json')).writeAsStringSync(json);
    }
    if (writeSarif) {
      final sarif = SarifReport.generate(
        projectPath: resolvedProjectPath,
        issues: issues,
      );
      File(p.join(reportDir, 'report.sarif')).writeAsStringSync(sarif);
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
      sources: sources,
      diagnostics: sources.diagnostics,
    );
  }

  static List<StaticIssue> _analyze(ScanContext context) {
    final allIssues = RuleRegistry.analyze(context);

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
