import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import 'package:flutterguard_cli/src/config_loader.dart';
import 'package:flutterguard_cli/src/config_tools.dart';
import 'package:flutterguard_cli/src/project_resolver.dart';
import 'package:flutterguard_cli/src/report_generator.dart';
import 'package:flutterguard_cli/src/rules/registry.dart';
import 'package:flutterguard_cli/src/scanner.dart';

const _version = '0.3.0';

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
    ..addFlag('help', abbr: 'h', help: 'Show scan usage', negatable: false);

  final initParser = ArgParser()
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path for flutterguard.yaml')
    ..addOption('config',
        abbr: 'c',
        defaultsTo: 'flutterguard.yaml',
        help: 'Config file path to create')
    ..addFlag('with-architecture',
        help: 'Include architecture layer/module template', negatable: false)
    ..addFlag('force',
        help: 'Overwrite an existing config file', negatable: false)
    ..addFlag('help', abbr: 'h', help: 'Show init usage', negatable: false);

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
    ..addCommand('init', initParser)
    ..addCommand('config', configParser)
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
    } else if (command.name == 'init') {
      if (command['help'] == true) {
        _printInitUsage(initParser);
        exit(0);
      }
      _handleInit(command);
    } else if (command.name == 'config') {
      _handleConfig(
          command, configParser, configPrintParser, configDoctorParser);
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
    final outputPath = ConfigTools.writeInitConfig(
      projectPath: args['path'] as String,
      configPath: args['config'] as String,
      withArchitecture: args['with-architecture'] as bool,
      force: args['force'] as bool,
    );
    stdout.writeln('Created FlutterGuard config: $outputPath');
    stdout.writeln('Next: flutterguard config doctor -p ${args['path']}');
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
    final configPath = ConfigTools.resolveConfigPathForProject(
      projectPath: projectPath,
      configPath: args['config'] as String,
    );
    final config = ScanConfig.fromFile(configPath);
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
      configPath: args['config'] as String,
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
      configPath: args['config'] as String,
      outputDir: args['output'] as String,
      writeJson: format == 'json',
      noColor: noColor,
      changedOnly: args['changed-only'] as bool,
      base: args['base'] as String,
    );
  } on ScanException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }

  if (result.files.isEmpty) {
    stderr.writeln('No Dart files found.');
    stderr.writeln(
        'Check that the project path is correct and that include/exclude patterns match Dart files.');
    stderr.writeln(
        'Typical config: include: [lib/**], exclude generated files, then add architecture rules only when boundaries are known.');
    exit(0);
  }

  final stdoutOutput = ReportGenerator.generateStdout(
    projectPath: result.projectPath,
    issues: result.issues,
    scannedFileCount: result.files.length,
    verbose: verbose,
    noColor: noColor,
  );
  stdout.writeln(stdoutOutput);

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
  stdout.writeln('  init            Create a starter flutterguard.yaml');
  stdout.writeln('  config          Print or validate effective configuration');
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
      '  3. CI config: add --format json --fail-on high --min-score 80.');
  stdout.writeln(
      '  4. Changed-only: add --changed-only --base main to scan git changes.');
  stdout.writeln(
      '  5. Architecture config: declare layers/modules explicitly before enabling boundary gates.');
  stdout.writeln();
  stdout.writeln('Docs: README.md and CONFIGURATION_STRATEGY.md');
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
  stdout.writeln('Usage: flutterguard init [options]');
  stdout.writeln();
  stdout.writeln(initParser.usage);
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln('  flutterguard init');
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
