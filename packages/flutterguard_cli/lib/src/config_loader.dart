// ignore_for_file: avoid_dynamic_calls

import 'dart:io';

import 'package:yaml/yaml.dart';

typedef LayerConfig = ({
  String name,
  String path,
  List<String> allowedDeps,
});

typedef ModuleConfig = ({
  String name,
  String path,
  List<String> allowedDeps,
});

typedef ArchitectureConfig = ({
  List<LayerConfig> layers,
  List<ModuleConfig> modules,
  bool detectCycles,
  bool layerViolationEnabled,
  bool moduleViolationEnabled,
});

typedef RulesConfig = ({
  LargeFileRuleConfig largeFile,
  LargeClassRuleConfig largeClass,
  LargeBuildMethodRuleConfig largeBuildMethod,
  LifecycleResourceRuleConfig lifecycleResource,
  MissingConstConstructorRuleConfig missingConstConstructor,
});

typedef LargeFileRuleConfig = ({bool enabled, int maxLines});
typedef LargeClassRuleConfig = ({bool enabled, int maxLines});
typedef LargeBuildMethodRuleConfig = ({bool enabled, int maxLines});
typedef LifecycleResourceRuleConfig = ({bool enabled});
typedef MissingConstConstructorRuleConfig = ({bool enabled});

class ScanConfig {
  final List<String> include;
  final List<String> exclude;
  final RulesConfig rules;
  final ArchitectureConfig architecture;

  const ScanConfig({
    required this.include,
    required this.exclude,
    required this.rules,
    required this.architecture,
  });

  factory ScanConfig.fromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return _defaultConfig();
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap;

    return ScanConfig(
      include: _parseStringList(yaml['include']) ?? ['lib/**'],
      exclude: _parseStringList(yaml['exclude']) ??
          [
            'lib/generated/**',
            'lib/**.g.dart',
            'lib/**.freezed.dart',
            'lib/**.mocks.dart',
          ],
      rules: _parseRules(yaml['rules'] as YamlMap? ?? YamlMap()),
      architecture: _parseArchitecture(yaml['architecture'] as YamlMap? ?? YamlMap()),
    );
  }

  static ScanConfig _defaultConfig() => const ScanConfig(
        include: ['lib/**'],
        exclude: [
          'lib/generated/**',
          'lib/**.g.dart',
          'lib/**.freezed.dart',
          'lib/**.mocks.dart',
        ],
        rules: (
          largeFile: (enabled: true, maxLines: 500),
          largeClass: (enabled: true, maxLines: 300),
          largeBuildMethod: (enabled: true, maxLines: 80),
          lifecycleResource: (enabled: true),
          missingConstConstructor: (enabled: true),
        ),
        architecture: (
          layers: [],
          modules: [],
          detectCycles: false,
          layerViolationEnabled: true,
          moduleViolationEnabled: true,
        ),
      );

  static RulesConfig _parseRules(YamlMap rules) => (
        largeFile: (
          enabled: rules['large_file']?['enabled'] as bool? ?? true,
          maxLines: rules['large_file']?['maxLines'] as int? ?? 500,
        ),
        largeClass: (
          enabled: rules['large_class']?['enabled'] as bool? ?? true,
          maxLines: rules['large_class']?['maxLines'] as int? ?? 300,
        ),
        largeBuildMethod: (
          enabled: rules['large_build_method']?['enabled'] as bool? ?? true,
          maxLines: rules['large_build_method']?['maxLines'] as int? ?? 80,
        ),
        lifecycleResource: (
          enabled: rules['lifecycle_resource']?['enabled'] as bool? ?? true,
        ),
        missingConstConstructor: (
          enabled: rules['missing_const_constructor']?['enabled'] as bool? ?? true,
        ),
      );

  static ArchitectureConfig _parseArchitecture(YamlMap arch) {
    final layers = <LayerConfig>[];
    if (arch['layers'] is YamlList) {
      for (final l in arch['layers'] as YamlList) {
        layers.add((
          name: l['name'] as String,
          path: l['path'] as String,
          allowedDeps: List<String>.from(l['allowed_deps'] as YamlList? ?? []),
        ));
      }
    }

    final modules = <ModuleConfig>[];
    if (arch['modules'] is YamlList) {
      for (final m in arch['modules'] as YamlList) {
        modules.add((
          name: m['name'] as String,
          path: m['path'] as String,
          allowedDeps: List<String>.from(m['allowed_deps'] as YamlList? ?? []),
        ));
      }
    }

    return (
      layers: layers,
      modules: modules,
      detectCycles: arch['detect_cycles'] as bool? ?? false,
      layerViolationEnabled: arch['layer_violation']?['enabled'] as bool? ?? true,
      moduleViolationEnabled: arch['module_violation']?['enabled'] as bool? ?? true,
    );
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }
}
