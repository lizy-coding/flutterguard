import 'dart:io';

import 'package:path/path.dart' as p;

import 'config_loader.dart';
import 'file_collector.dart';
import 'path_utils.dart';
import 'project_resolver.dart';
import 'rules/registry.dart';

enum DoctorSeverity { info, warning, error }

class DoctorMessage {
  final DoctorSeverity severity;
  final String message;

  const DoctorMessage(this.severity, this.message);
}

class DoctorResult {
  final String projectPath;
  final String configPath;
  final bool configExists;
  final int fileCount;
  final List<DoctorMessage> messages;

  const DoctorResult({
    required this.projectPath,
    required this.configPath,
    required this.configExists,
    required this.fileCount,
    required this.messages,
  });

  bool get hasErrors =>
      messages.any((message) => message.severity == DoctorSeverity.error);
}

class ConfigTools {
  static String initTemplate({required bool withArchitecture}) {
    final buffer = StringBuffer()
      ..writeln('include:')
      ..writeln('  - lib/**')
      ..writeln()
      ..writeln('exclude:')
      ..writeln('  - lib/generated/**')
      ..writeln('  - lib/**.g.dart')
      ..writeln('  - lib/**.freezed.dart')
      ..writeln('  - lib/**.mocks.dart')
      ..writeln()
      ..writeln('rules:');
    for (final rule in RuleRegistry.all()) {
      buffer
        ..writeln('  ${rule.id}:')
        ..writeln('    enabled: true')
        ..writeln('    severity: ${rule.defaultSeverity.name}');
      for (final option in rule.defaultOptions.entries) {
        buffer.writeln('    ${option.key}: ${option.value}');
      }
    }

    buffer
      ..writeln()
      ..writeln('architecture:')
      ..writeln('  detect_cycles: false');
    if (!withArchitecture) {
      buffer
        ..writeln('  layers: []')
        ..writeln('  modules: []');
      return buffer.toString();
    }

    buffer
      ..writeln('  layers:')
      ..writeln('    - name: presentation')
      ..writeln('      path: lib/presentation/**')
      ..writeln('      allowed_deps: [domain, core]')
      ..writeln('    - name: domain')
      ..writeln('      path: lib/domain/**')
      ..writeln('      allowed_deps: [core]')
      ..writeln('    - name: core')
      ..writeln('      path: lib/core/**')
      ..writeln('      allowed_deps: []')
      ..writeln('  modules: []');
    return buffer.toString();
  }

  static String writeInitConfig({
    required String projectPath,
    required String configPath,
    required bool withArchitecture,
    required bool force,
  }) {
    final resolvedProjectPath = ProjectResolver.resolveProjectPath(projectPath);
    final outputPath = p.isAbsolute(configPath)
        ? configPath
        : p.join(resolvedProjectPath, configPath);
    final file = File(outputPath);
    if (file.existsSync() && !force) {
      throw StateError(
        'Config file already exists at "$outputPath". Use --force to overwrite.',
      );
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(initTemplate(withArchitecture: withArchitecture));
    return outputPath;
  }

  static String resolveConfigPathForProject({
    required String projectPath,
    String? configPath,
  }) => ProjectResolver.resolveConfigPath(
    projectPath: projectPath,
    explicitConfig: configPath,
  );

  static DoctorResult doctor({
    required String projectPath,
    String? configPath,
  }) {
    final resolvedProjectPath = ProjectResolver.resolveProjectPath(projectPath);
    if (!Directory(resolvedProjectPath).existsSync()) {
      throw StateError('Project path "$resolvedProjectPath" does not exist.');
    }
    final resolvedConfigPath = resolveConfigPathForProject(
      projectPath: resolvedProjectPath,
      configPath: configPath,
    );
    final exists = File(resolvedConfigPath).existsSync();
    final config = ScanConfig.fromFile(
      resolvedConfigPath,
      requireFile: configPath != null,
    );
    final files = FileCollector.collect(resolvedProjectPath, config);
    final messages = <DoctorMessage>[];

    if (!exists) {
      messages.add(
        const DoctorMessage(
          DoctorSeverity.info,
          'No config file found. Built-in defaults are being used.',
        ),
      );
    }
    if (files.isEmpty) {
      messages.add(
        const DoctorMessage(
          DoctorSeverity.error,
          'No Dart files matched include/exclude patterns.',
        ),
      );
    }

    final definitions = {for (final rule in RuleRegistry.all()) rule.id: rule};
    final knownRules = definitions.keys.toSet();
    for (final id in config.configuredRuleIds.difference(knownRules)) {
      messages.add(DoctorMessage(DoctorSeverity.error, 'Unknown rule "$id".'));
    }
    for (final id in config.configuredRuleIds.intersection(knownRules)) {
      final knownOptions = definitions[id]!.defaultOptions.keys.toSet();
      for (final option
          in config
              .configuredOptions(id)
              .keys
              .toSet()
              .difference(knownOptions)) {
        messages.add(
          DoctorMessage(
            DoctorSeverity.error,
            'Unknown option "rules.$id.$option".',
          ),
        );
      }
    }
    _checkBoundaries(
      kind: 'layer',
      boundaries: config.architecture.layers,
      files: files,
      projectPath: resolvedProjectPath,
      messages: messages,
    );
    _checkBoundaries(
      kind: 'module',
      boundaries: config.architecture.modules,
      files: files,
      projectPath: resolvedProjectPath,
      messages: messages,
    );

    return DoctorResult(
      projectPath: resolvedProjectPath,
      configPath: resolvedConfigPath,
      configExists: exists,
      fileCount: files.length,
      messages: messages,
    );
  }

  static String formatDoctorResult(DoctorResult result) {
    final buffer = StringBuffer()
      ..writeln('FlutterGuard config check')
      ..writeln('Project: ${result.projectPath}')
      ..writeln('Config: ${result.configPath}')
      ..writeln('Config exists: ${result.configExists}')
      ..writeln('Matched Dart files: ${result.fileCount}');
    if (result.messages.isEmpty) {
      buffer.writeln('Status: OK');
      return buffer.toString();
    }
    buffer.writeln();
    for (final message in result.messages) {
      buffer.writeln(
        '${message.severity.name.toUpperCase()}: ${message.message}',
      );
    }
    return buffer.toString();
  }

  static void _checkBoundaries({
    required String kind,
    required List<BoundaryConfig> boundaries,
    required List<String> files,
    required String projectPath,
    required List<DoctorMessage> messages,
  }) {
    final names = boundaries.map((boundary) => boundary.name).toSet();
    if (names.length != boundaries.length) {
      messages.add(
        DoctorMessage(
          DoctorSeverity.error,
          'Duplicate architecture $kind names found.',
        ),
      );
    }
    for (final boundary in boundaries) {
      final unknown = boundary.allowedDeps.where((dep) => !names.contains(dep));
      for (final dependency in unknown) {
        messages.add(
          DoctorMessage(
            DoctorSeverity.error,
            'Architecture $kind "${boundary.name}" allows unknown dependency "$dependency".',
          ),
        );
      }
      final matches = files.any(
        (file) => matchesProjectGlob(file, boundary.path, projectPath),
      );
      if (!matches) {
        messages.add(
          DoctorMessage(
            DoctorSeverity.warning,
            'Architecture $kind "${boundary.name}" path "${boundary.path}" matched no files.',
          ),
        );
      }
    }
  }
}
