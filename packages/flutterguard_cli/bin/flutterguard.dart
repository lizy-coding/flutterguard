import 'dart:io';

import 'package:args/args.dart';

import 'package:flutterguard_cli/src/cli/scan_command.dart';
import 'package:flutterguard_cli/src/cli/baseline_commands.dart';
import 'package:flutterguard_cli/src/cli/cli_parsers.dart';
import 'package:flutterguard_cli/src/cli/config_commands.dart';
import 'package:flutterguard_cli/src/cli/issue_commands.dart';
import 'package:flutterguard_cli/src/cli/rule_commands.dart';

const _version = '0.4.1';

void main(List<String> args) {
  final normalizedArgs = _extractPositionalPath(args);

  final parsers = CliParsers();
  final scanParser = parsers.scan;
  final baselineCreateParser = parsers.baselineCreate;
  final baselineStatsParser = parsers.baselineStats;
  final baselinePruneParser = parsers.baselinePrune;
  final baselineCheckParser = parsers.baselineCheck;
  final baselineParser = parsers.baseline;
  final initParser = parsers.init;
  final installDoctorParser = parsers.installDoctor;
  final doctorParser = parsers.doctor;
  final issueExportParser = parsers.issueExport;
  final issueParser = parsers.issue;
  final configPrintParser = parsers.configPrint;
  final configDoctorParser = parsers.configDoctor;
  final configParser = parsers.config;
  final rulesParser = parsers.rules;
  final explainParser = parsers.explain;
  final parser = parsers.root;

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
  ConfigCommands.init(args);
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
  ConfigCommands.printEffective(
    args,
    configPath: _explicitConfigPath(args),
  );
}

void _handleConfigDoctor(ArgResults args) {
  ConfigCommands.doctor(args, configPath: _explicitConfigPath(args));
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
  ScanCommand.run(args, configPath: _explicitConfigPath(args));
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
  BaselineCommands.create(args, configPath: _explicitConfigPath(args));
}

void _handleBaselineStats(ArgResults args) {
  BaselineCommands.stats(args);
}

void _handleBaselinePrune(ArgResults args) {
  BaselineCommands.prune(args, configPath: _explicitConfigPath(args));
}

void _handleBaselineCheck(ArgResults args) {
  BaselineCommands.check(args, configPath: _explicitConfigPath(args));
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
    ConfigCommands.installDoctor(version: _version);
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
  IssueCommands.export(
    subcommand,
    configPath: _explicitConfigPath(subcommand),
  );
}

String? _explicitConfigPath(ArgResults args) {
  return args.wasParsed('config') ? args['config'] as String : null;
}

void _handleRules(ArgResults args) {
  RuleCommands.list(args);
}

void _handleExplain(ArgResults args) {
  RuleCommands.explain(args);
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
