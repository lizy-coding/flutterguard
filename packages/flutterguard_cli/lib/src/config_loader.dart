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

  static const _knownTopLevelKeys = {
    'include',
    'exclude',
    'rules',
    'architecture',
  };
  static const _knownRuleKeys = {
    'large_file',
    'large_class',
    'large_build_method',
    'lifecycle_resource',
    'missing_const_constructor',
  };
  static const _knownLayerKeys = {
    'name',
    'path',
    'allowed_deps',
  };
  static const _knownArchKeys = {
    'layers',
    'modules',
    'detect_cycles',
    'layer_violation',
    'module_violation',
  };

  factory ScanConfig.fromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return _defaultConfig();
    }

    final content = file.readAsStringSync();
    final parsed = loadYaml(content);
    if (parsed == null) {
      return _defaultConfig();
    }
    if (parsed is! YamlMap) {
      throw FormatException('Config file "$path" must contain a YAML map.');
    }
    final yaml = parsed;

    _warnUnknownKeys(yaml, _knownTopLevelKeys, 'config');

    final rules = _optionalMap(yaml['rules'], 'rules');
    _warnUnknownKeys(rules, _knownRuleKeys, 'rules');

    final arch = _optionalMap(yaml['architecture'], 'architecture');
    _warnUnknownKeys(arch, _knownArchKeys, 'architecture');

    if (arch['layers'] is YamlList) {
      for (final layer in arch['layers'] as YamlList) {
        if (layer is! YamlMap) {
          throw const FormatException('Each architecture layer must be a map.');
        }
        _warnUnknownKeys(layer, _knownLayerKeys, 'layer');
      }
    }
    if (arch['modules'] is YamlList) {
      for (final module in arch['modules'] as YamlList) {
        if (module is! YamlMap) {
          throw const FormatException(
              'Each architecture module must be a map.');
        }
        _warnUnknownKeys(module, _knownLayerKeys, 'module');
      }
    }

    return ScanConfig(
      include: _parseStringList(yaml['include']) ?? ['lib/**'],
      exclude: _parseStringList(yaml['exclude']) ??
          [
            'lib/generated/**',
            'lib/**.g.dart',
            'lib/**.freezed.dart',
            'lib/**.mocks.dart',
          ],
      rules: _parseRules(rules),
      architecture: _parseArchitecture(arch),
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

  static RulesConfig _parseRules(YamlMap rules) {
    final largeFile = _optionalMap(rules['large_file'], 'rules.large_file');
    final largeClass = _optionalMap(rules['large_class'], 'rules.large_class');
    final largeBuildMethod = _optionalMap(
      rules['large_build_method'],
      'rules.large_build_method',
    );
    final lifecycleResource = _optionalMap(
      rules['lifecycle_resource'],
      'rules.lifecycle_resource',
    );
    final missingConstConstructor = _optionalMap(
      rules['missing_const_constructor'],
      'rules.missing_const_constructor',
    );

    return (
      largeFile: (
        enabled: _boolValue(largeFile, 'enabled', true),
        maxLines: _intValue(largeFile, 'maxLines', 500),
      ),
      largeClass: (
        enabled: _boolValue(largeClass, 'enabled', true),
        maxLines: _intValue(largeClass, 'maxLines', 300),
      ),
      largeBuildMethod: (
        enabled: _boolValue(largeBuildMethod, 'enabled', true),
        maxLines: _intValue(largeBuildMethod, 'maxLines', 80),
      ),
      lifecycleResource: (
        enabled: _boolValue(lifecycleResource, 'enabled', true),
      ),
      missingConstConstructor: (
        enabled: _boolValue(missingConstConstructor, 'enabled', true),
      ),
    );
  }

  static ArchitectureConfig _parseArchitecture(YamlMap arch) {
    final layers = <LayerConfig>[];
    if (arch['layers'] is YamlList) {
      for (final l in arch['layers'] as YamlList) {
        if (l is! YamlMap) {
          throw const FormatException('Each architecture layer must be a map.');
        }
        layers.add((
          name: _requiredString(l, 'name', 'architecture.layers'),
          path: _requiredString(l, 'path', 'architecture.layers'),
          allowedDeps: _parseStringList(l['allowed_deps']) ?? [],
        ));
      }
    }

    final modules = <ModuleConfig>[];
    if (arch['modules'] is YamlList) {
      for (final m in arch['modules'] as YamlList) {
        if (m is! YamlMap) {
          throw const FormatException(
              'Each architecture module must be a map.');
        }
        modules.add((
          name: _requiredString(m, 'name', 'architecture.modules'),
          path: _requiredString(m, 'path', 'architecture.modules'),
          allowedDeps: _parseStringList(m['allowed_deps']) ?? [],
        ));
      }
    }

    final layerViolation = _optionalMap(
      arch['layer_violation'],
      'architecture.layer_violation',
    );
    final moduleViolation = _optionalMap(
      arch['module_violation'],
      'architecture.module_violation',
    );

    return (
      layers: layers,
      modules: modules,
      detectCycles: _boolValue(arch, 'detect_cycles', false),
      layerViolationEnabled: _boolValue(layerViolation, 'enabled', true),
      moduleViolationEnabled: _boolValue(moduleViolation, 'enabled', true),
    );
  }

  static void _warnUnknownKeys(YamlMap map, Set<String> known, String context) {
    for (final key in map.keys) {
      final keyStr = key.toString();
      if (!known.contains(keyStr)) {
        stderr.writeln('Warning: Unknown $context key "$keyStr"');
      }
    }
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    if (value != null) {
      throw const FormatException('Expected a YAML list of strings.');
    }
    return null;
  }

  static YamlMap _optionalMap(dynamic value, String path) {
    if (value == null) return YamlMap();
    if (value is YamlMap) return value;
    throw FormatException('$path must be a YAML map.');
  }

  static bool _boolValue(YamlMap map, String key, bool defaultValue) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is bool) return value;
    throw FormatException('$key must be a boolean.');
  }

  static int _intValue(YamlMap map, String key, int defaultValue) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is int) return value;
    throw FormatException('$key must be an integer.');
  }

  static String _requiredString(YamlMap map, String key, String path) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('$path.$key must be a non-empty string.');
  }
}
