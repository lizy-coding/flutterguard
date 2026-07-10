import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'package:flutterguard_cli/src/baseline.dart';
import 'package:flutterguard_cli/src/config_loader.dart';
import 'package:flutterguard_cli/src/config_tools.dart';
import 'package:flutterguard_cli/src/install_doctor.dart';
import 'package:flutterguard_cli/src/issue_export.dart';
import 'package:flutterguard_cli/src/project_resolver.dart';
import 'package:flutterguard_cli/src/report_generator.dart';
import 'package:flutterguard_cli/src/rules/registry.dart';
import 'package:flutterguard_cli/src/scanner.dart';
import 'package:path/path.dart' as p;

const _version = '0.4.1';

void main(List<String> args) {
  final normalizedArgs = _extractPositionalPath(args);

  final scanParser = ArgParser(allowTrailingOptions: false)
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path to scan')
    ..addOption('config',
        abbr: 'c',
        defaultsTo: 'flutterguard.yaml',
        help: 'Path to flutterguard.yaml config file')
    ..addOption('format',
        abbr: 'f',
        defaultsTo: 'table',
        allowed: ['table', 'json', 'sarif'],
        help: 'Output format')
    ..addOption('output',
        abbr: 'o',
        defaultsTo: '.flutterguard',
        help: 'Output directory for reports')
    ..addFlag('verbose',
        abbr: 'v',
        help: 'Show detailed output with code context',
        negatable: false)
    ..addFlag('no-color',
        help: 'Disable ANSI terminal colors', negatable: false)
    ..addFlag('changed-only',
        help: 'Only scan files changed since --base', negatable: false)
    ..addOption('base',
        defaultsTo: 'main', help: 'Git base branch/ref for changed-only mode')
    ..addOption('fail-on',
        defaultsTo: 'none',
        allowed: ['none', 'high', 'medium', 'low'],
        help: 'Fail threshold for CI gate')
    ..addOption('min-score', help: 'Minimum score threshold (0-100)')
    ..addOption('baseline',
        help: 'Baseline JSON file used to hide existing issues')
    ..addFlag('help', abbr: 'h', help: 'Show scan usage', negatable: false);

  final baselineCreateParser = ArgParser(allowTrailingOptions: false)
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path to scan')
    ..addOption('config',
        abbr: 'c',
        defaultsTo: 'flutterguard.yaml',
        help: 'Path to flutterguard.yaml config file')
    ..addOption('output',
        abbr: 'o',
        defaultsTo: '.flutterguard/baseline.json',
        help: 'Baseline file to create')
    ..addFlag('help',
        abbr: 'h', help: 'Show baseline create usage', negatable: false);

  final baselineStatsParser = ArgParser()
    ..addOption('baseline',
        abbr: 'b',
        defaultsTo: '.flutterguard/baseline.json',
        help: 'Baseline file to inspect')
    ..addFlag('help',
        abbr: 'h', help: 'Show baseline stats usage', negatable: false);

  final baselinePruneParser = ArgParser(allowTrailingOptions: false)
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path to scan')
    ..addOption('config',
        abbr: 'c',
        defaultsTo: 'flutterguard.yaml',
        help: 'Path to flutterguard.yaml config file')
    ..addOption('baseline',
        abbr: 'b',
        defaultsTo: '.flutterguard/baseline.json',
        help: 'Baseline file to prune')
    ..addFlag('dry-run',
        help: 'Print prune result without updating the baseline file',
        negatable: false)
    ..addFlag('help',
        abbr: 'h', help: 'Show baseline prune usage', negatable: false);

  final baselineCheckParser = ArgParser(allowTrailingOptions: false)
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path to scan')
    ..addOption('config',
        abbr: 'c',
        defaultsTo: 'flutterguard.yaml',
        help: 'Path to flutterguard.yaml config file')
    ..addOption('baseline',
        abbr: 'b',
        defaultsTo: '.flutterguard/baseline.json',
        help: 'Baseline file to compare against')
    ..addFlag('no-growth',
        help: 'Fail if current scan has issues missing from baseline',
        negatable: false)
    ..addFlag('help',
        abbr: 'h', help: 'Show baseline check usage', negatable: false);

  final baselineParser = ArgParser()
    ..addCommand('create', baselineCreateParser)
    ..addCommand('stats', baselineStatsParser)
    ..addCommand('prune', baselinePruneParser)
    ..addCommand('check', baselineCheckParser)
    ..addFlag('help', abbr: 'h', help: 'Show baseline usage', negatable: false);

  final initParser = ArgParser()
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path for flutterguard.yaml')
    ..addOption('config',
        abbr: 'c',
        defaultsTo: 'flutterguard.yaml',
        help: 'Config file path to create')
    ..addFlag('with-architecture',
        help: 'Include architecture layer/module template', negatable: false)
    ..addOption('profile',
        defaultsTo: 'recommended',
        allowed: ConfigTools.profiles.toList()..sort(),
        help: 'Starter config profile')
    ..addFlag('force',
        help: 'Overwrite an existing config file', negatable: false)
    ..addFlag('help', abbr: 'h', help: 'Show init usage', negatable: false);

  final installDoctorParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', help: 'Show install doctor usage', negatable: false);

  final doctorParser = ArgParser()
    ..addCommand('install', installDoctorParser)
    ..addFlag('help', abbr: 'h', help: 'Show doctor usage', negatable: false);

  final issueExportParser = ArgParser(allowTrailingOptions: false)
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path to scan')
    ..addOption('config',
        abbr: 'c',
        defaultsTo: 'flutterguard.yaml',
        help: 'Path to flutterguard.yaml config file')
    ..addOption('rule', help: 'Rule ID to export')
    ..addOption('file', help: 'Project-relative or absolute file path')
    ..addOption('line', help: 'Issue line number')
    ..addOption('context',
        defaultsTo: '2', help: 'Number of context lines around issue')
    ..addOption('output', abbr: 'o', help: 'Output file. Defaults to stdout')
    ..addFlag('help',
        abbr: 'h', help: 'Show issue export usage', negatable: false);

  final issueParser = ArgParser()
    ..addCommand('export', issueExportParser)
    ..addFlag('help', abbr: 'h', help: 'Show issue usage', negatable: false);

  final configPrintParser = ArgParser()
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path for config resolution')
    ..addOption('config',
        abbr: 'c', defaultsTo: 'flutterguard.yaml', help: 'Config file path')
    ..addFlag('help',
        abbr: 'h', help: 'Show config print usage', negatable: false);

  final configDoctorParser = ArgParser()
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path for config resolution')
    ..addOption('config',
        abbr: 'c', defaultsTo: 'flutterguard.yaml', help: 'Config file path')
    ..addFlag('help',
        abbr: 'h', help: 'Show config doctor usage', negatable: false);

  final configParser = ArgParser()
    ..addCommand('print', configPrintParser)
    ..addCommand('doctor', configDoctorParser)
    ..addFlag('help', abbr: 'h', help: 'Show config usage', negatable: false);

  final rulesParser = ArgParser()
    ..addOption('format',
        abbr: 'f',
        defaultsTo: 'table',
        allowed: ['table', 'json'],
        help: 'Output format')
    ..addFlag('help', abbr: 'h', help: 'Show rules usage', negatable: false);

  final explainParser = ArgParser()
    ..addFlag('help', abbr: 'h', help: 'Show explain usage', negatable: false);

  final parser = ArgParser()
    ..addCommand('scan', scanParser)
    ..addCommand('baseline', baselineParser)
    ..addCommand('doctor', doctorParser)
    ..addCommand('init', initParser)
    ..addCommand('config', configParser)
    ..addCommand('issue', issueParser)
    ..addCommand('rules', rulesParser)
    ..addCommand('explain', explainParser)
    ..addFlag('help', abbr: 'h', help: 'Show usage', negatable: false)
    ..addFlag('version', abbr: 'V', help: 'Show version', negatable: false);

  try {
    final results = parser.parse(normalizedArgs);

    if (results['version'] == true) {
      stdout.writeln('flutterguard $_version');
      exit(0);
    }

    if (results['help'] == true || normalizedArgs.isEmpty) {
      _printUsage(parser);
      exit(0);
    }

    final command = results.command;
    if (command == null) {
      _printUsage(parser);
      exit(0);
    }

    if (command.name == 'scan') {
      if (command['help'] == true) {
        _printScanUsage(scanParser);
        exit(0);
      }
      _handleScan(command);
    } else if (command.name == 'baseline') {
      _handleBaseline(
        command,
        baselineParser,
        baselineCreateParser,
        baselineStatsParser,
        baselinePruneParser,
        baselineCheckParser,
      );
    } else if (command.name == 'doctor') {
      _handleDoctor(command, doctorParser, installDoctorParser);
    } else if (command.name == 'init') {
      if (command['help'] == true) {
        _printInitUsage(initParser);
        exit(0);
      }
      _handleInit(command);
    } else if (command.name == 'config') {
      _handleConfig(
          command, configParser, configPrintParser, configDoctorParser);
    } else if (command.name == 'issue') {
      _handleIssue(command, issueParser, issueExportParser);
    } else if (command.name == 'rules') {
      if (command['help'] == true) {
        _printRulesUsage(rulesParser);
        exit(0);
      }
      _handleRules(command);
    } else if (command.name == 'explain') {
      if (command['help'] == true) {
        _printExplainUsage(explainParser);
        exit(0);
      }
      _handleExplain(command);
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

void _handleInit(ArgResults args) {
  try {
    final restPath = args.rest.isNotEmpty ? args.rest.first : null;
    final outputPath = ConfigTools.writeInitConfig(
      projectPath: restPath ?? args['path'] as String,
      configPath: args['config'] as String,
      withArchitecture: args['with-architecture'] as bool,
      force: args['force'] as bool,
      profile: args['profile'] as String,
    );
    stdout.writeln('Created FlutterGuard config: $outputPath');
    stdout.writeln(
      'Next: flutterguard config doctor -p ${restPath ?? args['path']}',
    );
  } on StateError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }
}

void _handleConfig(
  ArgResults command,
  ArgParser configParser,
  ArgParser configPrintParser,
  ArgParser configDoctorParser,
) {
  if (command['help'] == true || command.command == null) {
    _printConfigUsage(configParser);
    exit(0);
  }

  final subcommand = command.command!;
  if (subcommand.name == 'print') {
    if (subcommand['help'] == true) {
      _printConfigPrintUsage(configPrintParser);
      exit(0);
    }
    _handleConfigPrint(subcommand);
    return;
  }
  if (subcommand.name == 'doctor') {
    if (subcommand['help'] == true) {
      _printConfigDoctorUsage(configDoctorParser);
      exit(0);
    }
    _handleConfigDoctor(subcommand);
    return;
  }

  _printConfigUsage(configParser);
  exit(0);
}

void _handleConfigPrint(ArgResults args) {
  try {
    final projectPath = ProjectResolver.resolveProjectPath(
      args['path'] as String,
    );
    final explicitConfig = _explicitConfigPath(args);
    final configPath = ConfigTools.resolveConfigPathForProject(
      projectPath: projectPath,
      configPath: explicitConfig,
    );
    final config = ScanConfig.fromFile(
      configPath,
      requireFile: explicitConfig != null,
    );
    stdout.write(ConfigTools.effectiveYaml(config));
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }
}

void _handleConfigDoctor(ArgResults args) {
  try {
    final result = ConfigTools.doctor(
      projectPath: args['path'] as String,
      configPath: _explicitConfigPath(args),
    );
    stdout.write(ConfigTools.formatDoctorResult(result));
    if (result.hasErrors) exit(1);
  } on StateError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }
}

List<String> _extractPositionalPath(List<String> args) {
  if (args.isEmpty) return args;

  final scanIndex = args.indexOf('scan');
  if (scanIndex == -1) return args;

  final positionalStart = scanIndex + 1;
  if (positionalStart >= args.length) return args;

  final candidate = args[positionalStart];
  if (candidate.startsWith('-')) return args;

  final positionalParts = <String>[candidate];
  var i = positionalStart + 1;
  while (i < args.length && !args[i].startsWith('-')) {
    positionalParts.add(args[i]);
    i++;
  }

  final before = args.sublist(0, positionalStart);
  final after = args.sublist(positionalStart + positionalParts.length);
  final result = [...before, '-p', ...positionalParts, ...after];
  return result;
}

void _handleScan(ArgResults args) {
  final format = args['format'] as String;
  final verbose = args['verbose'] as bool;
  final noColor = args['no-color'] as bool;
  final failOn = args['fail-on'] as String;
  final minScoreStr = args['min-score'] as String?;
  final minScore = _parseMinScore(minScoreStr);

  late final ScanResult result;
  try {
    result = FlutterGuardScanner.scan(
      projectPath: args['path'] as String,
      configPath: _explicitConfigPath(args),
      outputDir: args['output'] as String,
      writeJson: format == 'json',
      writeSarif: format == 'sarif',
      noColor: noColor,
      changedOnly: args['changed-only'] as bool,
      base: args['base'] as String,
      baselinePath: args['baseline'] as String?,
    );
  } on ScanException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }

  if (result.files.isEmpty) {
    stdout.writeln('No changed Dart files matched the scan configuration.');
    if (format == 'sarif') {
      stdout.writeln('SARIF report: ${result.reportDir}/report.sarif');
    }
    return;
  }

  if (format == 'sarif') {
    stdout.writeln(
      'FlutterGuard scanned ${result.files.length} files, found '
      '${result.issues.length} visible issues '
      '(${result.suppressedCount} suppressed, '
      '${result.suppressedByBaselineCount} baseline).',
    );
    stdout.writeln('SARIF report: ${result.reportDir}/report.sarif');
  } else {
    final stdoutOutput = ReportGenerator.generateStdout(
      projectPath: result.projectPath,
      issues: result.issues,
      scannedFileCount: result.files.length,
      verbose: verbose,
      noColor: noColor,
    );
    stdout.writeln(stdoutOutput);
  }

  if (failOn != 'none') {
    if (ReportGenerator.shouldFail(result.issues, failOn)) {
      stderr
          .writeln('CI gate failed: Issues found at or above "$failOn" level.');
      exit(1);
    }
  }

  if (minScore != null && result.score < minScore) {
    stderr.writeln(
        'CI gate failed: Score ${result.score} is below minimum $minScore.');
    exit(1);
  }
}

void _handleBaseline(
  ArgResults command,
  ArgParser baselineParser,
  ArgParser baselineCreateParser,
  ArgParser baselineStatsParser,
  ArgParser baselinePruneParser,
  ArgParser baselineCheckParser,
) {
  if (command['help'] == true || command.command == null) {
    _printBaselineUsage(baselineParser);
    exit(0);
  }

  final subcommand = command.command!;
  if (subcommand.name == 'create') {
    if (subcommand['help'] == true) {
      _printBaselineCreateUsage(baselineCreateParser);
      exit(0);
    }
    _handleBaselineCreate(subcommand);
    return;
  }
  if (subcommand.name == 'stats') {
    if (subcommand['help'] == true) {
      _printBaselineStatsUsage(baselineStatsParser);
      exit(0);
    }
    _handleBaselineStats(subcommand);
    return;
  }
  if (subcommand.name == 'prune') {
    if (subcommand['help'] == true) {
      _printBaselinePruneUsage(baselinePruneParser);
      exit(0);
    }
    _handleBaselinePrune(subcommand);
    return;
  }
  if (subcommand.name == 'check') {
    if (subcommand['help'] == true) {
      _printBaselineCheckUsage(baselineCheckParser);
      exit(0);
    }
    _handleBaselineCheck(subcommand);
    return;
  }

  _printBaselineUsage(baselineParser);
  exit(0);
}

void _handleBaselineCreate(ArgResults args) {
  final restPath = args.rest.isNotEmpty ? args.rest.first : null;
  final projectPath = restPath ?? args['path'] as String;
  final output = args['output'] as String;

  try {
    final result = FlutterGuardScanner.scan(
      projectPath: projectPath,
      configPath: _explicitConfigPath(args),
      applySuppression: false,
    );
    final outputPath =
        p.isAbsolute(output) ? output : p.join(result.projectPath, output);
    Directory(p.dirname(outputPath)).createSync(recursive: true);
    File(outputPath).writeAsStringSync(Baseline.encode(
      projectPath: result.projectPath,
      issues: result.rawIssues,
    ));
    stdout.writeln(
      'Created FlutterGuard baseline: $outputPath '
      '(${result.rawIssues.length} issues)',
    );
  } on ScanException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }
}

void _handleBaselineStats(ArgResults args) {
  try {
    final stats = Baseline.stats(args['baseline'] as String);
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(stats));
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }
}

void _handleBaselinePrune(ArgResults args) {
  final restPath = args.rest.isNotEmpty ? args.rest.first : null;
  final projectPath = restPath ?? args['path'] as String;
  final baselinePath = args['baseline'] as String;
  try {
    final result = FlutterGuardScanner.scan(
      projectPath: projectPath,
      configPath: _explicitConfigPath(args),
      applySuppression: false,
    );
    final resolvedBaselinePath = _resolveProjectFile(
      result.projectPath,
      baselinePath,
    );
    final baseline = Baseline.load(resolvedBaselinePath);
    final pruned = Baseline.prune(
      projectPath: result.projectPath,
      baseline: baseline,
      issues: result.rawIssues,
    );
    final prunedBaseline = Baseline.loadFromString(pruned);
    final removed =
        baseline.fingerprints.length - prunedBaseline.fingerprints.length;
    if (args['dry-run'] == true) {
      stdout.writeln(
        'Baseline prune dry-run: ${baseline.fingerprints.length} -> '
        '${prunedBaseline.fingerprints.length} fingerprints '
        '($removed removed)',
      );
      return;
    }
    File(resolvedBaselinePath).writeAsStringSync(pruned);
    stdout.writeln(
      'Pruned baseline: ${baseline.fingerprints.length} -> '
      '${prunedBaseline.fingerprints.length} fingerprints ($removed removed)',
    );
  } on ScanException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }
}

void _handleBaselineCheck(ArgResults args) {
  final restPath = args.rest.isNotEmpty ? args.rest.first : null;
  final projectPath = restPath ?? args['path'] as String;
  try {
    final result = FlutterGuardScanner.scan(
      projectPath: projectPath,
      configPath: _explicitConfigPath(args),
      applySuppression: false,
    );
    final baseline = Baseline.load(_resolveProjectFile(
      result.projectPath,
      args['baseline'] as String,
    ));
    final newFingerprints = Baseline.newFingerprints(
      projectPath: result.projectPath,
      baseline: baseline,
      issues: result.rawIssues,
    );
    stdout.writeln(
      'Baseline check: ${newFingerprints.length} issue(s) missing from baseline.',
    );
    if (newFingerprints.isNotEmpty) {
      for (final fingerprint in newFingerprints.take(20)) {
        stdout.writeln('  $fingerprint');
      }
    }
    if (args['no-growth'] == true && newFingerprints.isNotEmpty) {
      exit(1);
    }
  } on ScanException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }
}

void _handleDoctor(
  ArgResults command,
  ArgParser doctorParser,
  ArgParser installDoctorParser,
) {
  if (command['help'] == true || command.command == null) {
    _printDoctorUsage(doctorParser);
    exit(0);
  }
  final subcommand = command.command!;
  if (subcommand.name == 'install') {
    if (subcommand['help'] == true) {
      _printInstallDoctorUsage(installDoctorParser);
      exit(0);
    }
    stdout.write(InstallDoctor.generate(version: _version));
    return;
  }
  _printDoctorUsage(doctorParser);
  exit(0);
}

void _handleIssue(
  ArgResults command,
  ArgParser issueParser,
  ArgParser issueExportParser,
) {
  if (command['help'] == true || command.command == null) {
    _printIssueUsage(issueParser);
    exit(0);
  }
  final subcommand = command.command!;
  if (subcommand.name != 'export') {
    _printIssueUsage(issueParser);
    exit(0);
  }
  if (subcommand['help'] == true) {
    _printIssueExportUsage(issueExportParser);
    exit(0);
  }
  try {
    final contextLines = int.tryParse(subcommand['context'] as String);
    if (contextLines == null || contextLines < 0) {
      throw const FormatException(
          'Expected --context to be a non-negative integer.');
    }
    final lineRaw = subcommand['line'] as String?;
    final line = lineRaw == null ? null : int.tryParse(lineRaw);
    if (lineRaw != null && (line == null || line < 1)) {
      throw const FormatException('Expected --line to be a positive integer.');
    }

    final result = FlutterGuardScanner.scan(
      projectPath: subcommand['path'] as String,
      configPath: _explicitConfigPath(subcommand),
      applySuppression: false,
    );
    final exported = IssueExporter.export(
      projectPath: result.projectPath,
      issues: result.rawIssues,
      ruleId: subcommand['rule'] as String?,
      filePath: subcommand['file'] as String?,
      line: line,
      contextLines: contextLines,
    );
    final output = subcommand['output'] as String?;
    if (output == null) {
      stdout.writeln(exported);
      return;
    }
    final outputPath = _resolveProjectFile(result.projectPath, output);
    File(outputPath).parent.createSync(recursive: true);
    File(outputPath).writeAsStringSync(exported);
    stdout.writeln('Exported issue feedback bundle: $outputPath');
  } on ScanException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }
}

String _resolveProjectFile(String projectPath, String filePath) {
  return p.isAbsolute(filePath) ? filePath : p.join(projectPath, filePath);
}

String? _explicitConfigPath(ArgResults args) {
  return args.wasParsed('config') ? args['config'] as String : null;
}

void _handleRules(ArgResults args) {
  final format = args['format'] as String;
  final all = RuleRegistry.all();

  if (format == 'json') {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(
      all.map((m) => m.toJson()).toList(),
    ));
    return;
  }

  all.sort((a, b) => a.id.compareTo(b.id));
  stdout.writeln('可用规则 (${all.length}):');
  stdout.writeln();
  for (final rule in all) {
    stdout.writeln(
      '  ${rule.id.padRight(32)} ${rule.domain.padRight(14)} ${rule.name}',
    );
  }
  stdout.writeln();
  stdout.writeln('执行 flutterguard explain <rule-id> 查看详情');
}

void _handleExplain(ArgResults args) {
  final rest = args.rest;
  if (rest.isEmpty) {
    stderr.writeln('Error: 请指定规则 ID');
    stderr.writeln('用法: flutterguard explain <rule-id>');
    stderr.writeln('可用规则: ${RuleRegistry.all().map((m) => m.id).join(", ")}');
    exit(2);
  }

  final ruleId = rest.first;
  final meta = RuleRegistry.find(ruleId);
  if (meta == null) {
    stderr.writeln('Error: 未找到规则 "$ruleId"');
    stderr.writeln('可用规则: ${RuleRegistry.all().map((m) => m.id).join(", ")}');
    exit(2);
  }

  stdout.writeln('规则: ${meta.id}');
  stdout.writeln('名称: ${meta.name}');
  stdout.writeln('领域: ${meta.domain}');
  stdout.writeln('风险: ${meta.riskLevel}');
  stdout.writeln('优先级: ${meta.priority}');
  stdout.writeln('CI 阻断: ${meta.cicdSafe ? "是" : "否"}');
  stdout.writeln();
  stdout.writeln('检测目的:');
  stdout.writeln('  ${meta.purpose}');
  stdout.writeln();
  stdout.writeln('风险原因:');
  stdout.writeln('  ${meta.riskReason}');
  stdout.writeln();
  stdout.writeln('典型坏例子:');
  stdout.writeln('  ${meta.badExample}');
  stdout.writeln();
  stdout.writeln('推荐修复:');
  stdout.writeln('  ${meta.fixSuggestion}');
  if (meta.configKeys.isNotEmpty) {
    stdout.writeln();
    stdout.writeln('配置项:');
    for (final key in meta.configKeys) {
      stdout.writeln('  - $key');
    }
  }
}

int? _parseMinScore(String? value) {
  if (value == null) return null;
  final score = int.tryParse(value);
  if (score == null || score < 0 || score > 100) {
    throw const FormatException('Expected --min-score to be an integer 0-100.');
  }
  return score;
}

void _printUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — IoT Flutter architecture static analysis CLI');
  stdout.writeln(
      'No API key is required. This CLI scans local source code only.');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard <command> [options]');
  stdout.writeln();
  stdout.writeln('Commands:');
  stdout.writeln(
      '  scan [<path>]   Scan a Flutter project for architecture issues');
  stdout.writeln('  baseline        Create a baseline for existing issues');
  stdout.writeln('  doctor          Diagnose installation and environment');
  stdout.writeln('  init            Create a starter flutterguard.yaml');
  stdout.writeln('  config          Print or validate effective configuration');
  stdout.writeln('  issue           Export issue feedback bundles');
  stdout.writeln('  rules           List available rules');
  stdout.writeln('  explain         Explain a rule by ID');
  stdout.writeln();
  stdout.writeln('Global Options:');
  stdout.writeln('  -h, --help      Show this help message');
  stdout.writeln('  -V, --version   Show version');
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln(
      '  flutterguard scan                    # Scan current directory');
  stdout
      .writeln('  flutterguard init                    # Create basic config');
  stdout.writeln(
      '  flutterguard config doctor           # Validate config and globs');
  stdout.writeln(
      '  flutterguard scan ./my_flutter_app   # Scan specific project');
  stdout.writeln('  flutterguard scan -p /path/to/app    # Explicit path flag');
  stdout.writeln('  flutterguard scan . --format json --fail-on high');
  stdout.writeln('  flutterguard baseline create .');
  stdout
      .writeln('  flutterguard scan . --baseline .flutterguard/baseline.json');
  stdout.writeln('  flutterguard doctor install');
  stdout.writeln('  flutterguard issue export --rule mqtt_connection');
  stdout.writeln();
  stdout.writeln('Configuration strategy:');
  stdout.writeln(
      '  Start with zero config, add flutterguard.yaml only for thresholds, excludes,');
  stdout.writeln('  CI gates, or explicit architecture layers/modules.');
}

void _printScanUsage(ArgParser scanParser) {
  stdout.writeln('FlutterGuard — scan command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard scan [<path>] [options]');
  stdout.writeln();
  stdout.writeln(
      '  <path>            Project path to scan (default: current directory)');
  stdout.writeln();
  stdout.writeln(scanParser.usage);
  stdout.writeln();
  stdout.writeln('Configuration strategy:');
  stdout.writeln('  1. Zero config: run scan with built-in defaults.');
  stdout
      .writeln('  2. Basic config: tune include/exclude and rule thresholds.');
  stdout.writeln(
      '  3. Baseline: run baseline create . before gating legacy projects.');
  stdout.writeln(
      '  4. CI config: add --format json --baseline .flutterguard/baseline.json --fail-on high.');
  stdout.writeln(
      '  5. Changed-only: add --changed-only --base main to scan git changes.');
  stdout.writeln(
      '  6. Architecture config: declare layers/modules explicitly before enabling boundary gates.');
  stdout.writeln();
  stdout.writeln('Docs: README.md and CONFIGURATION_STRATEGY.md');
}

void _printBaselineUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — baseline command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard baseline <command> [options]');
  stdout.writeln();
  stdout.writeln('Commands:');
  stdout.writeln('  create [<path>]   Create a baseline for existing issues');
  stdout.writeln('  stats             Show baseline fingerprint counts');
  stdout.writeln('  prune [<path>]    Remove fixed issues from a baseline');
  stdout.writeln('  check [<path>]    Check current issues against a baseline');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

void _printBaselineCreateUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — baseline create command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard baseline create [<path>] [options]');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

void _printBaselineStatsUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — baseline stats command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard baseline stats [options]');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

void _printBaselinePruneUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — baseline prune command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard baseline prune [<path>] [options]');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

void _printBaselineCheckUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — baseline check command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard baseline check [<path>] [options]');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

void _printDoctorUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — doctor command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard doctor <command> [options]');
  stdout.writeln();
  stdout.writeln('Commands:');
  stdout.writeln('  install   Diagnose installed executable and PATH');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

void _printInstallDoctorUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — doctor install command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard doctor install [options]');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

void _printIssueUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — issue command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard issue <command> [options]');
  stdout.writeln();
  stdout.writeln('Commands:');
  stdout.writeln('  export   Export a local feedback bundle for one issue');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

void _printIssueExportUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — issue export command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard issue export [options]');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

void _printRulesUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — rules command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard rules [options]');
  stdout.writeln();
  stdout.writeln('List all available rules.');
  stdout.writeln(parser.usage);
}

void _printExplainUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — explain command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard explain <rule-id>');
  stdout.writeln();
  stdout.writeln('Show detailed explanation for a rule.');
  stdout.writeln(parser.usage);
}

void _printInitUsage(ArgParser initParser) {
  stdout.writeln('FlutterGuard — init command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard init [<path>] [options]');
  stdout.writeln();
  stdout.writeln(initParser.usage);
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln('  flutterguard init');
  stdout.writeln('  flutterguard init --profile migration');
  stdout.writeln('  flutterguard init --with-architecture');
  stdout.writeln('  flutterguard init -p ./my_flutter_app --force');
}

void _printConfigUsage(ArgParser configParser) {
  stdout.writeln('FlutterGuard — config command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard config <command> [options]');
  stdout.writeln();
  stdout.writeln('Commands:');
  stdout.writeln('  print    Show merged effective config');
  stdout.writeln(
      '  doctor   Validate config, globs, and architecture references');
  stdout.writeln();
  stdout.writeln(configParser.usage);
}

void _printConfigPrintUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — config print command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard config print [options]');
  stdout.writeln();
  stdout.writeln(parser.usage);
}

void _printConfigDoctorUsage(ArgParser parser) {
  stdout.writeln('FlutterGuard — config doctor command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard config doctor [options]');
  stdout.writeln();
  stdout.writeln(parser.usage);
}
