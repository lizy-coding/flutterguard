// ignore_for_file: avoid_dynamic_calls

import 'dart:io';

import 'package:yaml/yaml.dart';

import 'static_issue.dart';

typedef BoundaryConfig = ({String name, String path, List<String> allowedDeps});

typedef ArchitectureConfig = ({
  List<BoundaryConfig> layers,
  List<BoundaryConfig> modules,
  bool detectCycles,
});

class RuleConfig {
  final bool enabled;
  final RiskLevel severity;
  final Map<String, Object?> options;

  const RuleConfig({
    required this.enabled,
    required this.severity,
    this.options = const {},
  });

  bool boolOption(String key) {
    final value = options[key];
    if (value is bool) return value;
    throw FormatException('rules option "$key" must be a boolean.');
  }
}

class ScanConfig {
  final List<String> include;
  final List<String> exclude;
  final Map<
    String,
    ({bool enabled, RiskLevel? severity, Map<String, Object?> options})
  >
  _rules;
  final ArchitectureConfig architecture;

  const ScanConfig({
    required this.include,
    required this.exclude,
    required Map<
      String,
      ({bool enabled, RiskLevel? severity, Map<String, Object?> options})
    >
    rules,
    required this.architecture,
  }) : _rules = rules;

  Set<String> get configuredRuleIds => _rules.keys.toSet();

  Map<String, Object?> configuredOptions(String id) =>
      Map.unmodifiable(_rules[id]?.options ?? const {});

  RuleConfig rule(
    String id, {
    required RiskLevel defaultSeverity,
    Map<String, Object?> defaultOptions = const {},
  }) {
    final configured = _rules[id];
    return RuleConfig(
      enabled: configured?.enabled ?? true,
      severity: configured?.severity ?? defaultSeverity,
      options: {...defaultOptions, ...?configured?.options},
    );
  }

  static const _knownTopLevelKeys = {
    'include',
    'exclude',
    'rules',
    'architecture',
  };
  static const _knownArchitectureKeys = {'layers', 'modules', 'detect_cycles'};
  static const _knownBoundaryKeys = {'name', 'path', 'allowed_deps'};

  factory ScanConfig.fromFile(String path, {bool requireFile = false}) {
    final file = File(path);
    if (!file.existsSync()) {
      if (requireFile) {
        throw FormatException('Config file "$path" does not exist.');
      }
      return ScanConfig.defaults();
    }

    final parsed = loadYaml(file.readAsStringSync());
    if (parsed == null) return ScanConfig.defaults();
    if (parsed is! YamlMap) {
      throw FormatException('Config file "$path" must contain a YAML map.');
    }

    _warnUnknownKeys(parsed, _knownTopLevelKeys, 'config');
    final architecture = _optionalMap(parsed['architecture'], 'architecture');
    _warnUnknownKeys(architecture, _knownArchitectureKeys, 'architecture');

    return ScanConfig(
      include: _stringList(parsed['include']) ?? const ['lib/**'],
      exclude:
          _stringList(parsed['exclude']) ??
          const [
            'lib/generated/**',
            'lib/**.g.dart',
            'lib/**.freezed.dart',
            'lib/**.mocks.dart',
          ],
      rules: _parseRules(_optionalMap(parsed['rules'], 'rules')),
      architecture: (
        layers: _parseBoundaries(architecture['layers'], 'layers'),
        modules: _parseBoundaries(architecture['modules'], 'modules'),
        detectCycles: _boolValue(architecture, 'detect_cycles', false),
      ),
    );
  }

  factory ScanConfig.defaults() => const ScanConfig(
    include: ['lib/**'],
    exclude: [
      'lib/generated/**',
      'lib/**.g.dart',
      'lib/**.freezed.dart',
      'lib/**.mocks.dart',
    ],
    rules: {},
    architecture: (layers: [], modules: [], detectCycles: false),
  );

  static Map<
    String,
    ({bool enabled, RiskLevel? severity, Map<String, Object?> options})
  >
  _parseRules(YamlMap rules) {
    final result =
        <
          String,
          ({bool enabled, RiskLevel? severity, Map<String, Object?> options})
        >{};
    for (final entry in rules.entries) {
      final id = entry.key.toString();
      final map = _optionalMap(entry.value, 'rules.$id');
      final options = <String, Object?>{};
      for (final option in map.entries) {
        final key = option.key.toString();
        if (key == 'enabled' || key == 'severity') continue;
        final value = option.value;
        if (value is bool || value is int || value is String) {
          options[key] = value;
        } else {
          throw FormatException('rules.$id.$key must be a scalar value.');
        }
      }
      result[id] = (
        enabled: _boolValue(map, 'enabled', true),
        severity: _optionalRiskLevel(map, 'severity'),
        options: options,
      );
    }
    return result;
  }

  static List<BoundaryConfig> _parseBoundaries(Object? value, String path) {
    if (value == null) return const [];
    if (value is! YamlList) {
      throw FormatException('architecture.$path must be a list.');
    }
    return [
      for (final item in value) _parseBoundary(item, 'architecture.$path'),
    ];
  }

  static BoundaryConfig _parseBoundary(Object? value, String path) {
    if (value is! YamlMap) {
      throw FormatException('Each $path entry must be a map.');
    }
    _warnUnknownKeys(value, _knownBoundaryKeys, path);
    return (
      name: _requiredString(value, 'name', path),
      path: _requiredString(value, 'path', path),
      allowedDeps: _stringList(value['allowed_deps']) ?? const [],
    );
  }

  static YamlMap _optionalMap(Object? value, String path) {
    if (value == null) return YamlMap();
    if (value is YamlMap) return value;
    throw FormatException('$path must be a map.');
  }

  static List<String>? _stringList(Object? value) {
    if (value == null) return null;
    if (value is! YamlList) throw const FormatException('Expected a list.');
    return value.map((item) => item.toString()).toList();
  }

  static bool _boolValue(YamlMap map, String key, bool fallback) {
    final value = map[key];
    if (value == null) return fallback;
    if (value is bool) return value;
    throw FormatException('$key must be a boolean.');
  }

  static RiskLevel? _optionalRiskLevel(YamlMap map, String key) {
    final value = map[key];
    if (value == null) return null;
    for (final severity in RiskLevel.values) {
      if (severity.name == value) return severity;
    }
    throw FormatException('$key must be one of: low, medium, high.');
  }

  static String _requiredString(YamlMap map, String key, String path) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('$path.$key must be a non-empty string.');
  }

  static void _warnUnknownKeys(YamlMap map, Set<String> known, String context) {
    for (final key in map.keys.map((key) => key.toString())) {
      if (!known.contains(key)) {
        stderr.writeln('Warning: unknown $context key "$key".');
      }
    }
  }
}
