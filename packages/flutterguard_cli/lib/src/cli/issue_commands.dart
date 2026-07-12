import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../issue_export.dart';
import '../scanner.dart';

class IssueCommands {
  static void export(ArgResults args, {String? configPath}) {
    try {
      final contextLines = int.tryParse(args['context'] as String);
      if (contextLines == null || contextLines < 0) {
        throw const FormatException(
          'Expected --context to be a non-negative integer.',
        );
      }
      final lineRaw = args['line'] as String?;
      final line = lineRaw == null ? null : int.tryParse(lineRaw);
      if (lineRaw != null && (line == null || line < 1)) {
        throw const FormatException(
          'Expected --line to be a positive integer.',
        );
      }

      final result = FlutterGuardScanner.scan(
        projectPath: args['path'] as String,
        configPath: configPath,
        applySuppression: false,
      );
      final exported = IssueExporter.export(
        projectPath: result.projectPath,
        issues: result.rawIssues,
        ruleId: args['rule'] as String?,
        filePath: args['file'] as String?,
        line: line,
        contextLines: contextLines,
        workspace: result.sources,
      );
      final output = args['output'] as String?;
      if (output == null) {
        stdout.writeln(exported);
        return;
      }
      final outputPath =
          p.isAbsolute(output) ? output : p.join(result.projectPath, output);
      File(outputPath).parent.createSync(recursive: true);
      File(outputPath).writeAsStringSync(exported);
      stdout.writeln('Exported issue feedback bundle: $outputPath');
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
