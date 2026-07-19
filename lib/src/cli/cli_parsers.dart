import 'package:args/args.dart';

class CliParsers {
  late final ArgParser scan;
  late final ArgParser baselineCreate;
  late final ArgParser baseline;
  late final ArgParser configInit;
  late final ArgParser configCheck;
  late final ArgParser config;
  late final ArgParser rules;
  late final ArgParser root;

  CliParsers() {
    scan = ArgParser()
      ..addOption('config', abbr: 'c', help: 'Explicit config file')
      ..addOption(
        'format',
        abbr: 'f',
        defaultsTo: 'table',
        allowed: ['table', 'json', 'sarif'],
      )
      ..addOption('output', abbr: 'o', defaultsTo: '.flutterguard')
      ..addFlag('verbose', abbr: 'v', negatable: false)
      ..addFlag('no-color', negatable: false)
      ..addFlag('changed-only', negatable: false)
      ..addOption('base', defaultsTo: 'main')
      ..addOption(
        'fail-on',
        defaultsTo: 'none',
        allowed: ['none', 'high', 'medium', 'low'],
      )
      ..addOption('baseline')
      ..addFlag('help', abbr: 'h', negatable: false);

    baselineCreate = ArgParser()
      ..addOption('config', abbr: 'c')
      ..addOption(
        'output',
        abbr: 'o',
        defaultsTo: '.flutterguard/baseline.json',
      )
      ..addFlag('help', abbr: 'h', negatable: false);
    baseline = ArgParser()
      ..addCommand('create', baselineCreate)
      ..addFlag('help', abbr: 'h', negatable: false);

    configInit = ArgParser()
      ..addOption('config', abbr: 'c', defaultsTo: 'flutterguard.yaml')
      ..addFlag('with-architecture', negatable: false)
      ..addFlag('force', negatable: false)
      ..addFlag('help', abbr: 'h', negatable: false);
    configCheck = ArgParser()
      ..addOption('config', abbr: 'c')
      ..addFlag('help', abbr: 'h', negatable: false);
    config = ArgParser()
      ..addCommand('init', configInit)
      ..addCommand('check', configCheck)
      ..addFlag('help', abbr: 'h', negatable: false);

    rules = ArgParser()
      ..addOption(
        'format',
        abbr: 'f',
        defaultsTo: 'table',
        allowed: ['table', 'json'],
      )
      ..addFlag('help', abbr: 'h', negatable: false);

    root = ArgParser()
      ..addCommand('scan', scan)
      ..addCommand('baseline', baseline)
      ..addCommand('config', config)
      ..addCommand('rules', rules)
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addFlag('version', abbr: 'V', negatable: false);
  }
}
