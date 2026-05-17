import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:flutterguard_cli/src/config_loader.dart';
import 'package:flutterguard_cli/src/file_collector.dart';
import 'package:flutterguard_cli/src/report_generator.dart';
import 'package:flutterguard_cli/src/rules/circular_dependency.dart';
import 'package:flutterguard_cli/src/rules/large_units.dart';
import 'package:flutterguard_cli/src/rules/layer_violation.dart';
import 'package:flutterguard_cli/src/rules/lifecycle_resource.dart';
import 'package:flutterguard_cli/src/rules/missing_const_constructor.dart';
import 'package:flutterguard_cli/src/rules/module_violation.dart';
import 'package:flutterguard_cli/src/static_issue.dart';

void main(List<String> args) {
  final scanParser = ArgParser()
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path to scan')
    ..addOption('config',
        abbr: 'c',
        defaultsTo: 'flutterguard.yaml',
        help: 'Path to flutterguard.yaml config file')
    ..addOption('format',
        abbr: 'f',
        defaultsTo: 'table',
        allowed: ['table', 'json'],
        help: 'Output format')
    ..addOption('output',
        abbr: 'o',
        defaultsTo: '.flutterguard',
        help: 'Output directory for reports')
    ..addFlag('verbose',
        abbr: 'v',
        help: 'Show detailed output with code context',
        negatable: false)
    ..addOption('fail-on',
        defaultsTo: 'none',
        allowed: ['none', 'high', 'medium', 'low'],
        help: 'Fail threshold for CI gate')
    ..addOption('min-score', help: 'Minimum score threshold (0-100)');

  final parser = ArgParser()
    ..addCommand('scan', scanParser)
    ..addFlag('help', abbr: 'h', help: 'Show usage', negatable: false);

  try {
    final results = parser.parse(args);

    if (results['help'] == true || args.isEmpty || args.first == 'help') {
      _printUsage(parser);
      exit(0);
    }

    final command = results.command;
    if (command?.name == 'scan') {
      _handleScan(command!);
    } else {
      _printUsage(parser);
      exit(0);
    }
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln();
    _printUsage(parser);
    exit(2);
  }
}

void _handleScan(ArgResults args) {
  final projectPath = p.normalize(p.absolute(args['path'] as String));
  final configPath = args['config'] as String;
  final outputDir = args['output'] as String;
  final format = args['format'] as String;
  final verbose = args['verbose'] as bool;
  final failOn = args['fail-on'] as String;
  final minScoreStr = args['min-score'] as String?;

  if (!Directory(projectPath).existsSync()) {
    stderr.writeln('Error: Project path "$projectPath" does not exist.');
    exit(2);
  }

  final config = ScanConfig.fromFile(p.join(projectPath, configPath));

  final files = FileCollector.collect(projectPath, config);

  if (files.isEmpty) {
    stderr.writeln('No Dart files found. Check your include/exclude patterns.');
    exit(0);
  }

  final allIssues = <StaticIssue>[];

  allIssues.addAll(LargeUnitsRule(config.rules).analyze(files));
  allIssues.addAll(
      LifecycleResourceRule(config.rules.lifecycleResource).analyze(files));
  if (config.architecture.layerViolationEnabled) {
    allIssues.addAll(
        LayerViolationRule(config.architecture.layers).analyze(files));
  }
  if (config.architecture.moduleViolationEnabled) {
    allIssues.addAll(
        ModuleViolationRule(config.architecture.modules).analyze(files));
  }
  allIssues.addAll(MissingConstConstructorRule(
    config.rules.missingConstConstructor,
  ).analyze(files));
  allIssues.addAll(CircularDependencyRule(
    enabled: config.architecture.detectCycles,
  ).analyze(files));

  allIssues.sort((a, b) {
    final levelOrder = {
      RiskLevel.high: 0,
      RiskLevel.medium: 1,
      RiskLevel.low: 2,
    };
    final cmp = levelOrder[a.level]!.compareTo(levelOrder[b.level]!);
    if (cmp != 0) return cmp;
    return a.file.compareTo(b.file);
  });

  Directory(outputDir).createSync(recursive: true);

  if (format == 'json') {
    final json = ReportGenerator.generateJson(
      projectPath: projectPath,
      issues: allIssues,
    );
    File(p.join(outputDir, 'report.json')).writeAsStringSync(json);
  }

  final stdoutOutput = ReportGenerator.generateStdout(
    projectPath: projectPath,
    issues: allIssues,
    verbose: verbose,
  );
  stdout.writeln(stdoutOutput);

  if (failOn != 'none') {
    if (ReportGenerator.shouldFail(allIssues, failOn)) {
      stderr.writeln(
          'CI gate failed: Issues found at or above "$failOn" level.');
      exit(1);
    }
  }

  if (minScoreStr != null) {
    final minScore = int.tryParse(minScoreStr);
    if (minScore != null) {
      final high = allIssues.where((i) => i.level == RiskLevel.high).length;
      final medium =
          allIssues.where((i) => i.level == RiskLevel.medium).length;
      final low = allIssues.where((i) => i.level == RiskLevel.low).length;
      final score = allIssues.isEmpty
          ? 100
          : 100 - high * 10 - medium * 4 - low * 1;
      if (score < minScore) {
        stderr.writeln(
            'CI gate failed: Score $score is below minimum $minScore.');
        exit(1);
      }
    }
  }
}

void _printUsage(ArgParser parser) {
  stdout.writeln(
      'FlutterGuard — IoT Flutter architecture static analysis CLI');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard <command> [options]');
  stdout.writeln();
  stdout.writeln('Commands:');
  stdout.writeln('  scan    Scan a Flutter project for architecture issues');
  stdout.writeln();
  stdout.writeln(parser.usage);
}
