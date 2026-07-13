import 'package:args/args.dart';

import '../config_tools.dart';

class CliParsers {
  late final ArgParser scan;
  late final ArgParser baselineCreate;
  late final ArgParser baselineStats;
  late final ArgParser baselinePrune;
  late final ArgParser baselineCheck;
  late final ArgParser baseline;
  late final ArgParser init;
  late final ArgParser installDoctor;
  late final ArgParser doctor;
  late final ArgParser issueExport;
  late final ArgParser issue;
  late final ArgParser configPrint;
  late final ArgParser configDoctor;
  late final ArgParser config;
  late final ArgParser rules;
  late final ArgParser explain;
  late final ArgParser root;

  CliParsers() {
    scan = ArgParser(allowTrailingOptions: false)
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

    baselineCreate = ArgParser(allowTrailingOptions: false)
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
    baselineStats = ArgParser()
      ..addOption('baseline',
          abbr: 'b',
          defaultsTo: '.flutterguard/baseline.json',
          help: 'Baseline file to inspect')
      ..addFlag('help',
          abbr: 'h', help: 'Show baseline stats usage', negatable: false);
    baselinePrune = ArgParser(allowTrailingOptions: false)
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
    baselineCheck = ArgParser(allowTrailingOptions: false)
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
    baseline = ArgParser()
      ..addCommand('create', baselineCreate)
      ..addCommand('stats', baselineStats)
      ..addCommand('prune', baselinePrune)
      ..addCommand('check', baselineCheck)
      ..addFlag('help',
          abbr: 'h', help: 'Show baseline usage', negatable: false);

    init = ArgParser()
      ..addOption('path',
          abbr: 'p',
          defaultsTo: '.',
          help: 'Project path for flutterguard.yaml')
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

    installDoctor = ArgParser()
      ..addFlag('help',
          abbr: 'h', help: 'Show install doctor usage', negatable: false);
    doctor = ArgParser()
      ..addCommand('install', installDoctor)
      ..addFlag('help', abbr: 'h', help: 'Show doctor usage', negatable: false);

    issueExport = ArgParser(allowTrailingOptions: false)
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
    issue = ArgParser()
      ..addCommand('export', issueExport)
      ..addFlag('help', abbr: 'h', help: 'Show issue usage', negatable: false);

    configPrint = _configLeafParser();
    configDoctor = _configLeafParser();
    config = ArgParser()
      ..addCommand('print', configPrint)
      ..addCommand('doctor', configDoctor)
      ..addFlag('help', abbr: 'h', help: 'Show config usage', negatable: false);
    rules = ArgParser()
      ..addOption('format',
          abbr: 'f',
          defaultsTo: 'table',
          allowed: ['table', 'json'],
          help: 'Output format')
      ..addFlag('help', abbr: 'h', help: 'Show rules usage', negatable: false);
    explain = ArgParser()
      ..addFlag('help',
          abbr: 'h', help: 'Show explain usage', negatable: false);

    root = ArgParser()
      ..addCommand('scan', scan)
      ..addCommand('baseline', baseline)
      ..addCommand('doctor', doctor)
      ..addCommand('init', init)
      ..addCommand('config', config)
      ..addCommand('issue', issue)
      ..addCommand('rules', rules)
      ..addCommand('explain', explain)
      ..addFlag('help', abbr: 'h', help: 'Show usage', negatable: false)
      ..addFlag('version', abbr: 'V', help: 'Show version', negatable: false);
  }

  ArgParser _configLeafParser() => ArgParser()
    ..addOption('path',
        abbr: 'p', defaultsTo: '.', help: 'Project path for config resolution')
    ..addOption('config',
        abbr: 'c', defaultsTo: 'flutterguard.yaml', help: 'Config file path')
    ..addFlag('help',
        abbr: 'h', help: 'Show config command usage', negatable: false);
}
