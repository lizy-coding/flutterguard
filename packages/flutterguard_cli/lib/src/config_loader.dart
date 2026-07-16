// ignore_for_file: avoid_dynamic_calls

import 'dart:io';

import 'package:yaml/yaml.dart';

import 'static_issue.dart';

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
  DeviceLifecycleRuleConfig deviceLifecycle,
  MqttConnectionRuleConfig mqttConnection,
  BleScanningRuleConfig bleScanning,
  IotSecurityRuleConfig iotSecurity,
  PubspecSecurityRuleConfig pubspecSecurity,
  StateRuleConfig sideEffectInBuild,
  StateRuleConfig stateManagerCreatedInBuild,
  StateRuleConfig mutableStateExposed,
  StateRuleConfig stateLayerUiDependency,
  StateRuleConfig stateDependencyCycle,
  StateRuleConfig riverpodReadUsedForRender,
  StateRuleConfig riverpodWatchInCallback,
  StateRuleConfig blocEquatablePropsIncomplete,
  StateRuleConfig providerValueLifecycleMisuse,
  StateRuleConfig notifyListenersInLoop,
});

typedef LargeFileRuleConfig = ({bool enabled, int maxLines});
typedef LargeClassRuleConfig = ({bool enabled, int maxLines});
typedef LargeBuildMethodRuleConfig = ({bool enabled, int maxLines});
typedef LifecycleResourceRuleConfig = ({bool enabled});
typedef MissingConstConstructorRuleConfig = ({bool enabled});
typedef DeviceLifecycleRuleConfig = ({bool enabled});
typedef MqttConnectionRuleConfig = ({bool enabled});
typedef BleScanningRuleConfig = ({bool enabled, int maxScanDurationMs});
typedef IotSecurityRuleConfig = ({bool enabled, bool requireTls});
typedef PubspecSecurityRuleConfig = ({bool enabled});
typedef StateRuleConfig = ({
  bool enabled,
  RiskLevel severity,
  List<String> allowlist,
  List<String> ignorePaths,
});

typedef StateManagementConfig = ({
  bool enabled,
  bool frameworkAutoDetect,
  RuleConfidence confidenceThreshold,
});

class ScanConfig {
  final List<String> include;
  final List<String> exclude;
  final RulesConfig rules;
  final ArchitectureConfig architecture;
  final StateManagementConfig stateManagement;

  const ScanConfig({
    required this.include,
    required this.exclude,
    required this.rules,
    required this.architecture,
    required this.stateManagement,
  });

  static const _knownTopLevelKeys = {
    'include',
    'exclude',
    'rules',
    'architecture',
    'state_management',
  };
  static const _knownRuleKeys = {
    'large_file',
    'large_class',
    'large_build_method',
    'lifecycle_resource',
    'missing_const_constructor',
    'device_lifecycle',
    'mqtt_connection',
    'ble_scanning',
    'iot_security',
    'pubspec_security',
    'side_effect_in_build',
    'state_manager_created_in_build',
    'mutable_state_exposed',
    'state_layer_ui_dependency',
    'state_dependency_cycle',
    'riverpod_read_used_for_render',
    'riverpod_watch_in_callback',
    'bloc_equatable_props_incomplete',
    'provider_value_lifecycle_misuse',
    'notify_listeners_in_loop',
  };
  static const _knownStateRuleKeys = {
    'enabled',
    'severity',
    'allowlist',
    'ignore_paths',
  };
  static const _knownStateManagementKeys = {
    'enabled',
    'framework_auto_detect',
    'confidence_threshold',
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

  factory ScanConfig.fromFile(
    String path, {
    bool requireFile = false,
  }) {
    final file = File(path);
    if (!file.existsSync()) {
      if (requireFile) {
        throw FormatException('Config file "$path" does not exist.');
      }
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

    final stateManagement = _optionalMap(
      yaml['state_management'],
      'state_management',
    );
    _warnUnknownKeys(
      stateManagement,
      _knownStateManagementKeys,
      'state_management',
    );
    for (final ruleId in _stateRuleIds) {
      final rule = _optionalMap(rules[ruleId], 'rules.$ruleId');
      _warnUnknownKeys(rule, _knownStateRuleKeys, 'rules.$ruleId');
    }

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
      stateManagement: _parseStateManagement(stateManagement),
    );
  }

  static ScanConfig _defaultConfig() => ScanConfig(
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
          deviceLifecycle: (enabled: true),
          mqttConnection: (enabled: true),
          bleScanning: (enabled: true, maxScanDurationMs: 10000),
          iotSecurity: (enabled: true, requireTls: true),
          pubspecSecurity: (enabled: true),
          sideEffectInBuild: _defaultStateRule(RiskLevel.high),
          stateManagerCreatedInBuild: _defaultStateRule(RiskLevel.high),
          mutableStateExposed: _defaultStateRule(RiskLevel.medium),
          stateLayerUiDependency: _defaultStateRule(RiskLevel.high),
          stateDependencyCycle: _defaultStateRule(RiskLevel.high),
          riverpodReadUsedForRender: _defaultStateRule(RiskLevel.medium),
          riverpodWatchInCallback: _defaultStateRule(RiskLevel.medium),
          blocEquatablePropsIncomplete: _defaultStateRule(RiskLevel.medium),
          providerValueLifecycleMisuse: _defaultStateRule(RiskLevel.medium),
          notifyListenersInLoop: _defaultStateRule(RiskLevel.medium),
        ),
        architecture: (
          layers: [],
          modules: [],
          detectCycles: false,
          layerViolationEnabled: true,
          moduleViolationEnabled: true,
        ),
        stateManagement: (
          enabled: true,
          frameworkAutoDetect: true,
          confidenceThreshold: RuleConfidence.certain,
        ),
      );

  static const _stateRuleIds = [
    'side_effect_in_build',
    'state_manager_created_in_build',
    'mutable_state_exposed',
    'state_layer_ui_dependency',
    'state_dependency_cycle',
    'riverpod_read_used_for_render',
    'riverpod_watch_in_callback',
    'bloc_equatable_props_incomplete',
    'provider_value_lifecycle_misuse',
    'notify_listeners_in_loop',
  ];

  static StateRuleConfig _defaultStateRule(RiskLevel severity) => (
        enabled: true,
        severity: severity,
        allowlist: const [],
        ignorePaths: const [],
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
    final deviceLifecycle = _optionalMap(
      rules['device_lifecycle'],
      'rules.device_lifecycle',
    );
    final mqttConnection = _optionalMap(
      rules['mqtt_connection'],
      'rules.mqtt_connection',
    );
    final bleScanning = _optionalMap(
      rules['ble_scanning'],
      'rules.ble_scanning',
    );
    final iotSecurity = _optionalMap(
      rules['iot_security'],
      'rules.iot_security',
    );
    final pubspecSecurity = _optionalMap(
      rules['pubspec_security'],
      'rules.pubspec_security',
    );
    StateRuleConfig stateRule(String id, RiskLevel severity) =>
        _parseStateRule(_optionalMap(rules[id], 'rules.$id'), severity);

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
      deviceLifecycle: (enabled: _boolValue(deviceLifecycle, 'enabled', true),),
      mqttConnection: (enabled: _boolValue(mqttConnection, 'enabled', true),),
      bleScanning: (
        enabled: _boolValue(bleScanning, 'enabled', true),
        maxScanDurationMs: _intValue(bleScanning, 'maxScanDurationMs', 10000),
      ),
      iotSecurity: (
        enabled: _boolValue(iotSecurity, 'enabled', true),
        requireTls: _boolValue(iotSecurity, 'requireTls', true),
      ),
      pubspecSecurity: (enabled: _boolValue(pubspecSecurity, 'enabled', true),),
      sideEffectInBuild: stateRule('side_effect_in_build', RiskLevel.high),
      stateManagerCreatedInBuild:
          stateRule('state_manager_created_in_build', RiskLevel.high),
      mutableStateExposed: stateRule('mutable_state_exposed', RiskLevel.medium),
      stateLayerUiDependency:
          stateRule('state_layer_ui_dependency', RiskLevel.high),
      stateDependencyCycle: stateRule('state_dependency_cycle', RiskLevel.high),
      riverpodReadUsedForRender:
          stateRule('riverpod_read_used_for_render', RiskLevel.medium),
      riverpodWatchInCallback:
          stateRule('riverpod_watch_in_callback', RiskLevel.medium),
      blocEquatablePropsIncomplete:
          stateRule('bloc_equatable_props_incomplete', RiskLevel.medium),
      providerValueLifecycleMisuse:
          stateRule('provider_value_lifecycle_misuse', RiskLevel.medium),
      notifyListenersInLoop:
          stateRule('notify_listeners_in_loop', RiskLevel.medium),
    );
  }

  static StateRuleConfig _parseStateRule(
    YamlMap map,
    RiskLevel defaultSeverity,
  ) =>
      (
        enabled: _boolValue(map, 'enabled', true),
        severity: _riskLevelValue(map, 'severity', defaultSeverity),
        allowlist: _parseStringList(map['allowlist']) ?? const [],
        ignorePaths: _parseStringList(map['ignore_paths']) ?? const [],
      );

  static StateManagementConfig _parseStateManagement(YamlMap map) => (
        enabled: _boolValue(map, 'enabled', true),
        frameworkAutoDetect: _boolValue(map, 'framework_auto_detect', true),
        confidenceThreshold: _confidenceValue(
          map,
          'confidence_threshold',
          RuleConfidence.certain,
        ),
      );

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
      if (value.any((element) => element is! String)) {
        throw const FormatException('Expected a YAML list of strings.');
      }
      return value.cast<String>().toList();
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

  static RiskLevel _riskLevelValue(
    YamlMap map,
    String key,
    RiskLevel defaultValue,
  ) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is String) {
      for (final level in RiskLevel.values) {
        if (level.name == value) return level;
      }
    }
    throw FormatException('$key must be one of: high, medium, low.');
  }

  static RuleConfidence _confidenceValue(
    YamlMap map,
    String key,
    RuleConfidence defaultValue,
  ) {
    final value = map[key];
    if (value == null) return defaultValue;
    if (value is String) {
      for (final confidence in RuleConfidence.values) {
        if (confidence.name == value) return confidence;
      }
    }
    throw FormatException(
      '$key must be one of: certain, probable, informational.',
    );
  }

  static String _requiredString(YamlMap map, String key, String path) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw FormatException('$path.$key must be a non-empty string.');
  }
}
