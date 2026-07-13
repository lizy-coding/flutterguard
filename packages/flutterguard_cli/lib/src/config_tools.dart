import 'dart:io';

import 'package:path/path.dart' as p;

import 'config_loader.dart';
import 'file_collector.dart';
import 'path_utils.dart';
import 'project_resolver.dart';

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
  static const profiles = {
    'recommended',
    'strict',
    'migration',
    'iot-security',
    'architecture-only',
    'performance-only',
  };

  static const minimalConfig = '''
include:
  - lib/**

exclude:
  - lib/generated/**
  - lib/**.g.dart
  - lib/**.freezed.dart
  - lib/**.mocks.dart

rules:
  large_file:
    enabled: true
    maxLines: 500
  large_class:
    enabled: true
    maxLines: 300
  large_build_method:
    enabled: true
    maxLines: 80
  lifecycle_resource:
    enabled: true
  missing_const_constructor:
    enabled: true
  device_lifecycle:
    enabled: true
  mqtt_connection:
    enabled: true
  ble_scanning:
    enabled: true
    maxScanDurationMs: 10000
  iot_security:
    enabled: true
    requireTls: true
  pubspec_security:
    enabled: true
''';

  static const architectureBlock = '''

architecture:
  layers:
    - name: presentation
      path: lib/presentation/**
      allowed_deps: [domain, core]
    - name: domain
      path: lib/domain/**
      allowed_deps: [core]
    - name: data
      path: lib/data/**
      allowed_deps: [domain, core]
    - name: core
      path: lib/core/**
      allowed_deps: []

  modules:
    - name: mqtt_feature
      path: lib/features/mqtt/**
      allowed_deps: [shared]
    - name: ble_feature
      path: lib/features/ble/**
      allowed_deps: [shared]
    - name: shared
      path: lib/shared/**
      allowed_deps: []

  detect_cycles: true
  layer_violation:
    enabled: true
  module_violation:
    enabled: true
''';

  static String initTemplate({
    required bool withArchitecture,
    String profile = 'recommended',
  }) {
    if (!profiles.contains(profile)) {
      throw FormatException(
        'Unknown profile "$profile". Allowed: ${profiles.join(", ")}.',
      );
    }

    final config = switch (profile) {
      'strict' => _strictConfig,
      'migration' => _migrationConfig,
      'iot-security' => _iotSecurityConfig,
      'architecture-only' => _architectureOnlyConfig,
      'performance-only' => _performanceOnlyConfig,
      _ => minimalConfig,
    };
    return withArchitecture ? '$config$architectureBlock' : config;
  }

  static String writeInitConfig({
    required String projectPath,
    required String configPath,
    required bool withArchitecture,
    required bool force,
    String profile = 'recommended',
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
    file.writeAsStringSync(initTemplate(
      withArchitecture: withArchitecture,
      profile: profile,
    ));
    return outputPath;
  }

  static const _strictConfig = '''
include:
  - lib/**

exclude:
  - lib/generated/**
  - lib/**.g.dart
  - lib/**.freezed.dart
  - lib/**.mocks.dart

rules:
  large_file:
    enabled: true
    maxLines: 400
  large_class:
    enabled: true
    maxLines: 240
  large_build_method:
    enabled: true
    maxLines: 60
  lifecycle_resource:
    enabled: true
  missing_const_constructor:
    enabled: true
  device_lifecycle:
    enabled: true
  mqtt_connection:
    enabled: true
  ble_scanning:
    enabled: true
    maxScanDurationMs: 10000
  iot_security:
    enabled: true
    requireTls: true
  pubspec_security:
    enabled: true
''';

  static const _migrationConfig = '''
include:
  - lib/**

exclude:
  - lib/generated/**
  - lib/**.g.dart
  - lib/**.freezed.dart
  - lib/**.mocks.dart
  - test/**
  - example/**

rules:
  large_file:
    enabled: true
    maxLines: 800
  large_class:
    enabled: true
    maxLines: 500
  large_build_method:
    enabled: true
    maxLines: 120
  lifecycle_resource:
    enabled: true
  missing_const_constructor:
    enabled: false
  device_lifecycle:
    enabled: true
  mqtt_connection:
    enabled: true
  ble_scanning:
    enabled: true
    maxScanDurationMs: 15000
  iot_security:
    enabled: true
    requireTls: true
  pubspec_security:
    enabled: true
''';

  static const _iotSecurityConfig = '''
include:
  - lib/**

exclude:
  - lib/generated/**
  - lib/**.g.dart
  - lib/**.freezed.dart
  - lib/**.mocks.dart
  - test/**
  - example/**

rules:
  large_file:
    enabled: false
    maxLines: 500
  large_class:
    enabled: false
    maxLines: 300
  large_build_method:
    enabled: false
    maxLines: 80
  lifecycle_resource:
    enabled: true
  missing_const_constructor:
    enabled: false
  device_lifecycle:
    enabled: true
  mqtt_connection:
    enabled: true
  ble_scanning:
    enabled: true
    maxScanDurationMs: 10000
  iot_security:
    enabled: true
    requireTls: true
  pubspec_security:
    enabled: true
''';

  static const _architectureOnlyConfig = '''
include:
  - lib/**

exclude:
  - lib/generated/**
  - lib/**.g.dart
  - lib/**.freezed.dart
  - lib/**.mocks.dart

rules:
  large_file:
    enabled: false
    maxLines: 500
  large_class:
    enabled: false
    maxLines: 300
  large_build_method:
    enabled: false
    maxLines: 80
  lifecycle_resource:
    enabled: false
  missing_const_constructor:
    enabled: false
  device_lifecycle:
    enabled: false
  mqtt_connection:
    enabled: false
  ble_scanning:
    enabled: false
    maxScanDurationMs: 10000
  iot_security:
    enabled: false
    requireTls: true
  pubspec_security:
    enabled: false
''';

  static const _performanceOnlyConfig = '''
include:
  - lib/**

exclude:
  - lib/generated/**
  - lib/**.g.dart
  - lib/**.freezed.dart
  - lib/**.mocks.dart

rules:
  large_file:
    enabled: true
    maxLines: 500
  large_class:
    enabled: true
    maxLines: 300
  large_build_method:
    enabled: true
    maxLines: 80
  lifecycle_resource:
    enabled: true
  missing_const_constructor:
    enabled: false
  device_lifecycle:
    enabled: false
  mqtt_connection:
    enabled: false
  ble_scanning:
    enabled: false
    maxScanDurationMs: 10000
  iot_security:
    enabled: false
    requireTls: true
  pubspec_security:
    enabled: false
''';

  static String resolveConfigPathForProject({
    required String projectPath,
    String? configPath,
  }) {
    return ProjectResolver.resolveConfigPath(
      projectPath: projectPath,
      explicitConfig: configPath,
    );
  }

  static String effectiveYaml(ScanConfig config) {
    final buffer = StringBuffer()
      ..writeln('include:')
      ..write(_stringList(config.include, indent: 2))
      ..writeln()
      ..writeln('exclude:')
      ..write(_stringList(config.exclude, indent: 2))
      ..writeln()
      ..writeln('rules:')
      ..write(_ruleWithMaxLines('large_file', config.rules.largeFile))
      ..write(_ruleWithMaxLines('large_class', config.rules.largeClass))
      ..write(_ruleWithMaxLines(
        'large_build_method',
        config.rules.largeBuildMethod,
      ))
      ..write(_enabledRule(
        'lifecycle_resource',
        config.rules.lifecycleResource.enabled,
      ))
      ..write(_enabledRule(
        'missing_const_constructor',
        config.rules.missingConstConstructor.enabled,
      ))
      ..write(_enabledRule(
        'device_lifecycle',
        config.rules.deviceLifecycle.enabled,
      ))
      ..write(_enabledRule(
        'mqtt_connection',
        config.rules.mqttConnection.enabled,
      ))
      ..writeln('  ble_scanning:')
      ..writeln('    enabled: ${config.rules.bleScanning.enabled}')
      ..writeln(
        '    maxScanDurationMs: ${config.rules.bleScanning.maxScanDurationMs}',
      )
      ..writeln('  iot_security:')
      ..writeln('    enabled: ${config.rules.iotSecurity.enabled}')
      ..writeln('    requireTls: ${config.rules.iotSecurity.requireTls}')
      ..write(_enabledRule(
        'pubspec_security',
        config.rules.pubspecSecurity.enabled,
      ))
      ..writeln()
      ..writeln('architecture:')
      ..write(_boundaryList('layers', config.architecture.layers))
      ..write(_boundaryList('modules', config.architecture.modules))
      ..writeln('  detect_cycles: ${config.architecture.detectCycles}')
      ..writeln('  layer_violation:')
      ..writeln('    enabled: ${config.architecture.layerViolationEnabled}')
      ..writeln('  module_violation:')
      ..writeln('    enabled: ${config.architecture.moduleViolationEnabled}');

    return buffer.toString();
  }

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
    final configExists = File(resolvedConfigPath).existsSync();
    final config = ScanConfig.fromFile(
      resolvedConfigPath,
      requireFile: configPath != null,
    );
    final files = FileCollector.collect(resolvedProjectPath, config);

    final messages = <DoctorMessage>[];
    if (!configExists) {
      messages.add(DoctorMessage(
        DoctorSeverity.info,
        'No config file found. Built-in defaults are being used.',
      ));
    }
    if (files.isEmpty) {
      messages.add(DoctorMessage(
        DoctorSeverity.error,
        'No Dart files matched include/exclude patterns.',
      ));
    }

    _checkBackslashes(config, messages);
    _checkBoundaries(
      kind: 'layer',
      boundaries: config.architecture.layers,
      enabled: config.architecture.layerViolationEnabled,
      files: files,
      projectPath: resolvedProjectPath,
      messages: messages,
    );
    _checkBoundaries(
      kind: 'module',
      boundaries: config.architecture.modules,
      enabled: config.architecture.moduleViolationEnabled,
      files: files,
      projectPath: resolvedProjectPath,
      messages: messages,
    );

    if (config.architecture.detectCycles && files.isEmpty) {
      messages.add(DoctorMessage(
        DoctorSeverity.warning,
        'Circular dependency detection is enabled, but no files matched.',
      ));
    }

    return DoctorResult(
      projectPath: resolvedProjectPath,
      configPath: resolvedConfigPath,
      configExists: configExists,
      fileCount: files.length,
      messages: messages,
    );
  }

  static String formatDoctorResult(DoctorResult result) {
    final buffer = StringBuffer()
      ..writeln('FlutterGuard config doctor')
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
        '${_severityLabel(message.severity)}: ${message.message}',
      );
    }
    return buffer.toString();
  }

  static String _stringList(List<String> values, {required int indent}) {
    final spaces = ' ' * indent;
    return values.map((value) => '$spaces- $value\n').join();
  }

  static String _ruleWithMaxLines(
    String name,
    ({bool enabled, int maxLines}) config,
  ) {
    return '''
  $name:
    enabled: ${config.enabled}
    maxLines: ${config.maxLines}
''';
  }

  static String _enabledRule(String name, bool enabled) {
    return '''
  $name:
    enabled: $enabled
''';
  }

  static String _boundaryList(
    String key,
    List<({String name, String path, List<String> allowedDeps})> boundaries,
  ) {
    if (boundaries.isEmpty) return '  $key: []\n';
    final buffer = StringBuffer();
    buffer.writeln('  $key:');
    for (final boundary in boundaries) {
      buffer
        ..writeln('    - name: ${boundary.name}')
        ..writeln('      path: ${boundary.path}')
        ..writeln('      allowed_deps: [${boundary.allowedDeps.join(', ')}]');
    }
    return buffer.toString();
  }

  static void _checkBackslashes(
    ScanConfig config,
    List<DoctorMessage> messages,
  ) {
    for (final pattern in [...config.include, ...config.exclude]) {
      if (pattern.contains(r'\')) {
        messages.add(DoctorMessage(
          DoctorSeverity.warning,
          'Pattern "$pattern" contains backslashes. Use forward slashes in YAML.',
        ));
      }
    }
    for (final boundary in [
      ...config.architecture.layers,
      ...config.architecture.modules,
    ]) {
      if (boundary.path.contains(r'\')) {
        messages.add(DoctorMessage(
          DoctorSeverity.warning,
          'Architecture path "${boundary.path}" contains backslashes. Use forward slashes in YAML.',
        ));
      }
    }
  }

  static void _checkBoundaries({
    required String kind,
    required List<({String name, String path, List<String> allowedDeps})>
        boundaries,
    required bool enabled,
    required List<String> files,
    required String projectPath,
    required List<DoctorMessage> messages,
  }) {
    if (enabled && boundaries.isEmpty) {
      messages.add(DoctorMessage(
        DoctorSeverity.info,
        'No architecture ${kind}s declared. ${kind}_violation will not report boundary issues.',
      ));
      return;
    }

    final names = boundaries.map((boundary) => boundary.name).toSet();
    if (names.length != boundaries.length) {
      messages.add(DoctorMessage(
        DoctorSeverity.error,
        'Duplicate architecture $kind names found.',
      ));
    }

    for (final boundary in boundaries) {
      for (final dep in boundary.allowedDeps) {
        if (!names.contains(dep)) {
          messages.add(DoctorMessage(
            DoctorSeverity.error,
            'Architecture $kind "${boundary.name}" allows unknown dependency "$dep".',
          ));
        }
      }
    }

    final matchesByName = <String, Set<String>>{};
    for (final boundary in boundaries) {
      final matches = files
          .where((file) => _matchesBoundary(file, boundary.path, projectPath))
          .toSet();
      matchesByName[boundary.name] = matches;
      if (matches.isEmpty) {
        messages.add(DoctorMessage(
          DoctorSeverity.warning,
          'Architecture $kind "${boundary.name}" path "${boundary.path}" matched no files.',
        ));
      }
    }

    for (var i = 0; i < boundaries.length; i++) {
      for (var j = i + 1; j < boundaries.length; j++) {
        final left = boundaries[i];
        final right = boundaries[j];
        final overlap = matchesByName[left.name]!.intersection(
          matchesByName[right.name]!,
        );
        if (overlap.isNotEmpty) {
          messages.add(DoctorMessage(
            DoctorSeverity.warning,
            'Architecture $kind paths "${left.name}" and "${right.name}" overlap on ${overlap.length} file(s).',
          ));
        }
      }
    }
  }

  static bool _matchesBoundary(
    String file,
    String pattern,
    String projectPath,
  ) {
    return matchesProjectGlob(file, pattern, projectPath);
  }

  static String _severityLabel(DoctorSeverity severity) {
    switch (severity) {
      case DoctorSeverity.info:
        return 'INFO';
      case DoctorSeverity.warning:
        return 'WARN';
      case DoctorSeverity.error:
        return 'ERROR';
    }
  }
}
