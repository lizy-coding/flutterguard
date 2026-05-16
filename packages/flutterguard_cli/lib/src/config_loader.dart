import 'dart:io';

import 'package:yaml/yaml.dart';

typedef BoundaryConfig = ({
  String name,
  String from,
  List<String> forbidden,
});

typedef RulesConfig = ({
  LargeFileRuleConfig largeFile,
  LargeClassRuleConfig largeClass,
  LargeBuildMethodRuleConfig largeBuildMethod,
  LifecycleResourceRuleConfig lifecycleResource,
});

typedef LargeFileRuleConfig = ({bool enabled, int maxLines});
typedef LargeClassRuleConfig = ({bool enabled, int maxLines});
typedef LargeBuildMethodRuleConfig = ({bool enabled, int maxLines});
typedef LifecycleResourceRuleConfig = ({bool enabled});

class ScanConfig {
  final List<String> include;
  final List<String> exclude;
  final RulesConfig rules;
  final List<BoundaryConfig> boundaries;

  const ScanConfig({
    required this.include,
    required this.exclude,
    required this.rules,
    required this.boundaries,
  });

  factory ScanConfig.fromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return const ScanConfig(
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
        ),
        boundaries: [],
      );
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap;

    final rules = yaml['rules'] as YamlMap? ?? YamlMap();

    final boundaries = <BoundaryConfig>[];
    if (yaml['boundaries'] is YamlList) {
      for (final b in yaml['boundaries'] as YamlList) {
        boundaries.add((
          name: b['name'] as String,
          from: b['from'] as String,
          forbidden: List<String>.from(b['forbidden'] as YamlList),
        ));
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
      rules: (
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
      ),
      boundaries: boundaries,
    );
  }

  static List<String>? _parseStringList(dynamic value) {
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }
}
