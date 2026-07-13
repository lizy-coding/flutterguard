import 'dart:io';

import 'package:args/args.dart';

import '../report_generator.dart';
import '../scanner.dart';

class ScanCommand {
  static void run(ArgResults args, {String? configPath}) {
    final format = args['format'] as String;
    final verbose = args['verbose'] as bool;
    final noColor = args['no-color'] as bool;
    final failOn = args['fail-on'] as String;
    final minScore = _parseMinScore(args['min-score'] as String?);

    late final ScanResult result;
    try {
      result = FlutterGuardScanner.scan(
        projectPath: args['path'] as String,
        configPath: configPath,
        outputDir: args['output'] as String,
        writeJson: format == 'json',
        writeSarif: format == 'sarif',
        changedOnly: args['changed-only'] as bool,
        base: args['base'] as String,
        baselinePath: args['baseline'] as String?,
      );
    } on ScanException catch (error) {
      stderr.writeln('Error: ${error.message}');
      exit(2);
    } on FormatException catch (error) {
      stderr.writeln('Error: ${error.message}');
      exit(2);
    }

    if (verbose && result.diagnostics.isNotEmpty) {
      stderr.writeln('Scan diagnostics (${result.diagnostics.length}):');
      for (final diagnostic in result.diagnostics) {
        final location = diagnostic.file == null ? '' : ' ${diagnostic.file}';
        stderr.writeln(
          '  ${diagnostic.severity.name} [${diagnostic.stage}]$location: '
          '${diagnostic.message}',
        );
      }
    }

    if (result.files.isEmpty && result.issues.isEmpty) {
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
      final output = ReportGenerator.generateStdout(
        projectPath: result.projectPath,
        issues: result.issues,
        scannedFileCount: result.files.length,
        verbose: verbose,
        noColor: noColor,
      );
      stdout.writeln(output);
    }

    if (failOn != 'none' && ReportGenerator.shouldFail(result.issues, failOn)) {
      stderr.writeln(
        'CI gate failed: Issues found at or above "$failOn" level.',
      );
      exit(1);
    }

    if (minScore != null && result.score < minScore) {
      stderr.writeln(
        'CI gate failed: Score ${result.score} is below minimum $minScore.',
      );
      exit(1);
    }
  }

  static int? _parseMinScore(String? value) {
    if (value == null) return null;
    final score = int.tryParse(value);
    if (score == null || score < 0 || score > 100) {
      throw const FormatException(
        'Expected --min-score to be an integer 0-100.',
      );
    }
    return score;
  }
}
