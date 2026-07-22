import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../baseline.dart';
import '../scanner.dart';

class BaselineCommands {
  static void create(ArgResults args, {String? configPath}) {
    final projectPath = args.rest.isNotEmpty ? args.rest.first : '.';
    final output = args['output'] as String;
    try {
      final result = FlutterGuardScanner.scan(
        projectPath: projectPath,
        configPath: configPath,
        applySuppression: false,
      );
      final outputPath = p.isAbsolute(output)
          ? output
          : p.join(result.projectPath, output);
      Directory(p.dirname(outputPath)).createSync(recursive: true);
      File(outputPath).writeAsStringSync(
        Baseline.encode(
          projectPath: result.projectPath,
          issues: result.rawIssues,
        ),
      );
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

  static Never _fail(String message) {
    stderr.writeln('Error: $message');
    exit(2);
  }
}
