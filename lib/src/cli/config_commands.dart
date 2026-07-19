import 'dart:io';

import 'package:args/args.dart';

import '../config_tools.dart';

class ConfigCommands {
  static void init(ArgResults args) {
    try {
      final projectPath = args.rest.isNotEmpty ? args.rest.first : '.';
      final outputPath = ConfigTools.writeInitConfig(
        projectPath: projectPath,
        configPath: args['config'] as String,
        withArchitecture: args['with-architecture'] as bool,
        force: args['force'] as bool,
      );
      stdout.writeln('Created FlutterGuard config: $outputPath');
      stdout.writeln('Next: flutterguard config check $projectPath');
    } on StateError catch (error) {
      _fail(error.message);
    }
  }

  static void check(ArgResults args, {String? configPath}) {
    try {
      final projectPath = args.rest.isNotEmpty ? args.rest.first : '.';
      final result = ConfigTools.doctor(
        projectPath: projectPath,
        configPath: configPath,
      );
      stdout.write(ConfigTools.formatDoctorResult(result));
      if (result.hasErrors) exit(1);
    } on StateError catch (error) {
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
