import 'dart:io';

import 'package:path/path.dart' as p;

import 'config_loader.dart';
import 'file_collector.dart';
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
import 'static_issue.dart';

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
  final List<StaticIssue> issues;
  final int score;

  const ScanResult({
    required this.projectPath,
    required this.reportDir,
    required this.files,
    required this.issues,
    required this.score,
  });
}

class FlutterGuardScanner {
  static ScanResult scan({
    required String projectPath,
    String configPath = 'flutterguard.yaml',
    String outputDir = '.flutterguard',
    bool writeJson = false,
    bool noColor = false,
  }) {
    final resolvedProjectPath =
        ProjectResolver.resolveProjectPath(projectPath);
    if (!Directory(resolvedProjectPath).existsSync()) {
      throw ScanException(
        'Project path "$resolvedProjectPath" does not exist.',
      );
    }

    final resolvedConfigPath =
        ProjectResolver.resolveConfigPath(
          projectPath: resolvedProjectPath,
          explicitConfig: configPath,
        );
    final config = ScanConfig.fromFile(resolvedConfigPath);
    final files = FileCollector.collect(resolvedProjectPath, config);

    final reportDir = p.isAbsolute(outputDir)
        ? outputDir
        : p.join(resolvedProjectPath, outputDir);

    final issues = _analyze(
      files: files,
      config: config,
      projectPath: resolvedProjectPath,
    );
    final score = ReportGenerator.calculateScore(issues);

    if (writeJson) {
      Directory(reportDir).createSync(recursive: true);
      final json = ReportGenerator.generateJson(
        projectPath: resolvedProjectPath,
        issues: issues,
      );
      File(p.join(reportDir, 'report.json')).writeAsStringSync(json);
    }

    return ScanResult(
      projectPath: resolvedProjectPath,
      reportDir: reportDir,
      files: files,
      issues: issues,
      score: score,
    );
  }

  static List<StaticIssue> _analyze({
    required List<String> files,
    required ScanConfig config,
    required String projectPath,
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
      enabled: config.architecture.detectCycles,
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
