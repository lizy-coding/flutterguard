import 'dart:io';

import 'package:args/args.dart';

import 'package:flutterguard_cli/src/report_generator.dart';
import 'package:flutterguard_cli/src/scanner.dart';

const _version = '0.1.0';

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
    ..addOption('min-score', help: 'Minimum score threshold (0-100)')
    ..addFlag('help', abbr: 'h', help: 'Show scan usage', negatable: false);

  final parser = ArgParser()
    ..addCommand('scan', scanParser)
    ..addFlag('help', abbr: 'h', help: 'Show usage', negatable: false)
    ..addFlag('version', abbr: 'V', help: 'Show version', negatable: false);

  try {
    final results = parser.parse(args);

    if (results['version'] == true) {
      stdout.writeln('flutterguard $_version');
      exit(0);
    }

    if (results['help'] == true || args.isEmpty || args.first == 'help') {
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
  final format = args['format'] as String;
  final verbose = args['verbose'] as bool;
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
    );
  } on ScanException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(2);
  }

  if (result.files.isEmpty) {
    stderr.writeln('No Dart files found. Check your include/exclude patterns.');
    exit(0);
  }

  final stdoutOutput = ReportGenerator.generateStdout(
    projectPath: result.projectPath,
    issues: result.issues,
    scannedFileCount: result.files.length,
    verbose: verbose,
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
  stdout.writeln('  scan    Scan a Flutter project for architecture issues');
  stdout.writeln();
  stdout.writeln('Scan Options:');
  stdout.writeln('  -p, --path <path>       Project path to scan (default: .)');
  stdout.writeln(
      '  -c, --config <file>     Config file path (default: flutterguard.yaml)');
  stdout.writeln(
      '  -f, --format <fmt>      Output format: table | json (default: table)');
  stdout.writeln(
      '  -o, --output <dir>      Output directory (default: .flutterguard)');
  stdout.writeln(
      '  -v, --verbose           Show detailed output with code context');
  stdout.writeln('  -V, --version           Show version');
  stdout.writeln(
      '      --fail-on <level>   CI gate: none | high | medium | low (default: none)');
  stdout.writeln('      --min-score <num>   Minimum score threshold 0-100');
  stdout.writeln('  -h, --help              Show this help message');
  stdout.writeln();
  stdout.writeln('Examples:');
  stdout.writeln('  flutterguard scan -p ./my_flutter_app');
  stdout.writeln('  flutterguard scan -p . --format json --fail-on high');
}

void _printScanUsage(ArgParser scanParser) {
  stdout.writeln('FlutterGuard — scan command');
  stdout.writeln();
  stdout.writeln('Usage: flutterguard scan [options]');
  stdout.writeln();
  stdout.writeln(scanParser.usage);
}
