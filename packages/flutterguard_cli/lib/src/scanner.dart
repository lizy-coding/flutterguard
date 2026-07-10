import 'dart:io';

import 'package:path/path.dart' as p;

import 'baseline.dart';
import 'config_loader.dart';
import 'file_collector.dart';
import 'path_utils.dart';
import 'project_resolver.dart';
import 'report_generator.dart';
import 'rules/ble_scanning.dart';
import 'rules/circular_dependency.dart';
import 'rules/device_lifecycle.dart';
import 'rules/iot_security.dart';
import 'rules/large_units.dart';
import 'rules/layer_violation.dart';
import 'rules/lifecycle_resource.dart';
import 'rules/missing_const_constructor.dart';
import 'rules/module_violation.dart';
import 'rules/mqtt_connection.dart';
import 'rules/pubspec_security.dart';
import 'sarif_report.dart';
import 'static_issue.dart';
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
  final int score;
  final String scanMode;

  const ScanResult({
    required this.projectPath,
    required this.reportDir,
    required this.files,
    required this.rawIssues,
    required this.issues,
    required this.suppressedCount,
    required this.suppressedByBaselineCount,
    required this.score,
    required this.scanMode,
  });
}

class FlutterGuardScanner {
  static ScanResult scan({
    required String projectPath,
    String? configPath,
    String outputDir = '.flutterguard',
    bool writeJson = false,
    bool writeSarif = false,
    bool noColor = false,
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
    var scanMode = 'full';
    var filesToScan = files;

    if (changedOnly) {
      try {
        final changed = FileCollector.getChangedFiles(
          resolvedProjectPath,
          base,
        );
        if (changed != null) {
          final changedDart = changed
              .where((f) => f.endsWith('.dart'))
              .map(normalizePath)
              .toSet();
          filesToScan = files.where((f) => changedDart.contains(f)).toList();
          scanMode = 'changed';
        }
      } on ChangedFilesException catch (e) {
        throw ScanException(e.message);
      }
    }

    final reportDir = p.isAbsolute(outputDir)
        ? outputDir
        : p.join(resolvedProjectPath, outputDir);

    final rawIssues = _analyze(
      files: filesToScan,
      config: config,
      projectPath: resolvedProjectPath,
      changedOnly: scanMode == 'changed',
    );

    var issues = rawIssues;
    var suppressedCount = 0;
    if (applySuppression) {
      final suppression = SuppressionFilter(filesToScan);
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

    final score = ReportGenerator.calculateScore(issues);

    if (writeJson || writeSarif) {
      Directory(reportDir).createSync(recursive: true);
    }
    if (writeJson) {
      final json = ReportGenerator.generateJson(
        projectPath: resolvedProjectPath,
        issues: issues,
        scanMode: scanMode,
        suppressedCount: suppressedCount,
        suppressedByBaselineCount: suppressedByBaselineCount,
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
      score: score,
      scanMode: scanMode,
    );
  }

  static List<StaticIssue> _analyze({
    required List<String> files,
    required ScanConfig config,
    required String projectPath,
    bool changedOnly = false,
  }) {
    final allIssues = <StaticIssue>[];

    allIssues.addAll(LargeUnitsRule(
      largeFileConfig: config.rules.largeFile,
      largeClassConfig: config.rules.largeClass,
      largeBuildMethodConfig: config.rules.largeBuildMethod,
    ).analyze(files));
    allIssues.addAll(
      LifecycleResourceRule(config.rules.lifecycleResource).analyze(files),
    );

    if (config.architecture.layerViolationEnabled) {
      allIssues.addAll(LayerViolationRule(
        config.architecture.layers,
        projectPath: projectPath,
      ).analyze(files));
    }
    if (config.architecture.moduleViolationEnabled) {
      allIssues.addAll(ModuleViolationRule(
        config.architecture.modules,
        projectPath: projectPath,
      ).analyze(files));
    }

    allIssues.addAll(MissingConstConstructorRule(
      config.rules.missingConstConstructor,
    ).analyze(files));
    allIssues.addAll(CircularDependencyRule(
      enabled: !changedOnly && config.architecture.detectCycles,
      projectPath: projectPath,
    ).analyze(files));
    allIssues.addAll(DeviceLifecycleRule(
      config.rules.deviceLifecycle,
    ).analyze(files));
    allIssues.addAll(MqttConnectionRule(
      config.rules.mqttConnection,
    ).analyze(files));
    allIssues.addAll(BleScanningRule(
      config.rules.bleScanning,
    ).analyze(files));
    allIssues.addAll(IotSecurityRule(
      config.rules.iotSecurity,
    ).analyze(files));
    allIssues.addAll(PubspecSecurityRule(
      config.rules.pubspecSecurity,
    ).analyze(files));

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
