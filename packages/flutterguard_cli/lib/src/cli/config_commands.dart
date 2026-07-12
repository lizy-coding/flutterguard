import 'dart:io';

import 'package:args/args.dart';

import '../config_loader.dart';
import '../config_tools.dart';
import '../install_doctor.dart';
import '../project_resolver.dart';

class ConfigCommands {
  static void init(ArgResults args) {
    try {
      final projectPath =
          args.rest.isNotEmpty ? args.rest.first : args['path'] as String;
      final outputPath = ConfigTools.writeInitConfig(
        projectPath: projectPath,
        configPath: args['config'] as String,
        withArchitecture: args['with-architecture'] as bool,
        force: args['force'] as bool,
        profile: args['profile'] as String,
      );
      stdout.writeln('Created FlutterGuard config: $outputPath');
      stdout.writeln('Next: flutterguard config doctor -p $projectPath');
    } on StateError catch (error) {
      _fail(error.message);
    }
  }

  static void printEffective(ArgResults args, {String? configPath}) {
    try {
      final projectPath = ProjectResolver.resolveProjectPath(
        args['path'] as String,
      );
      final resolvedConfigPath = ConfigTools.resolveConfigPathForProject(
        projectPath: projectPath,
        configPath: configPath,
      );
      final config = ScanConfig.fromFile(
        resolvedConfigPath,
        requireFile: configPath != null,
      );
      stdout.write(ConfigTools.effectiveYaml(config));
    } on FormatException catch (error) {
      _fail(error.message);
    }
  }

  static void doctor(ArgResults args, {String? configPath}) {
    try {
      final result = ConfigTools.doctor(
        projectPath: args['path'] as String,
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

  static void installDoctor({required String version}) {
    stdout.write(InstallDoctor.generate(version: version));
  }

  static Never _fail(String message) {
    stderr.writeln('Error: $message');
    exit(2);
  }
}
