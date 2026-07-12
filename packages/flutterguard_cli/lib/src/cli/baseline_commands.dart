import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../baseline.dart';
import '../scanner.dart';

class BaselineCommands {
  static void create(ArgResults args, {String? configPath}) {
    final projectPath =
        args.rest.isNotEmpty ? args.rest.first : args['path'] as String;
    final output = args['output'] as String;

    try {
      final result = FlutterGuardScanner.scan(
        projectPath: projectPath,
        configPath: configPath,
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
    } on ScanException catch (error) {
      _fail(error.message);
    } on FormatException catch (error) {
      _fail(error.message);
    }
  }

  static void stats(ArgResults args) {
    try {
      final stats = Baseline.stats(args['baseline'] as String);
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(stats));
    } on FormatException catch (error) {
      _fail(error.message);
    }
  }

  static void prune(ArgResults args, {String? configPath}) {
    final projectPath =
        args.rest.isNotEmpty ? args.rest.first : args['path'] as String;
    final baselinePath = args['baseline'] as String;
    try {
      final result = FlutterGuardScanner.scan(
        projectPath: projectPath,
        configPath: configPath,
        applySuppression: false,
      );
      final resolvedBaselinePath = _resolve(result.projectPath, baselinePath);
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
    } on ScanException catch (error) {
      _fail(error.message);
    } on FormatException catch (error) {
      _fail(error.message);
    }
  }

  static void check(ArgResults args, {String? configPath}) {
    final projectPath =
        args.rest.isNotEmpty ? args.rest.first : args['path'] as String;
    try {
      final result = FlutterGuardScanner.scan(
        projectPath: projectPath,
        configPath: configPath,
        applySuppression: false,
      );
      final baseline = Baseline.load(_resolve(
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
      for (final fingerprint in newFingerprints.take(20)) {
        stdout.writeln('  $fingerprint');
      }
      if (args['no-growth'] == true && newFingerprints.isNotEmpty) {
        exit(1);
      }
    } on ScanException catch (error) {
      _fail(error.message);
    } on FormatException catch (error) {
      _fail(error.message);
    }
  }

  static String _resolve(String projectPath, String filePath) =>
      p.isAbsolute(filePath) ? filePath : p.join(projectPath, filePath);

  static Never _fail(String message) {
    stderr.writeln('Error: $message');
    exit(2);
  }
}
