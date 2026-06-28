import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../priority.dart';
import '../rule_meta.dart';
import '../static_issue.dart';

const _vulnerableDeps = <String, String>{
  'mqtt_client': '10.0.0',
  'http': '1.0.0',
};

const _deprecatedPackages = <String, String>{
  'flutter_blue': 'flutter_blue_plus',
};

class PubspecSecurityRule {
  final PubspecSecurityRuleConfig config;

  const PubspecSecurityRule(this.config);

  List<StaticIssue> analyze(List<String> files) {
    if (!config.enabled) return [];

    final issues = <StaticIssue>[];

    for (final file in files) {
      final dir = p.dirname(file);
      final pubspec = p.join(dir, 'pubspec.yaml');
      if (!File(pubspec).existsSync()) continue;

      try {
        final content = File(pubspec).readAsStringSync();
        final yaml = loadYaml(content);
        if (yaml is! YamlMap) continue;
        issues.addAll(_checkPubspec(pubspec, yaml));
      } catch (_) {}
    }

    return _deduplicate(issues);
  }

  List<StaticIssue> _checkPubspec(String pubspecPath, YamlMap root) {
    final issues = <StaticIssue>[];

    final dependencies = <String, String>{};
    final devDependencies = <String, String>{};

    _collectDeps(root['dependencies'], dependencies);
    _collectDeps(root['dev_dependencies'], devDependencies);

    for (final dep in {...dependencies.keys, ...devDependencies.keys}) {
      final version = dependencies[dep] ?? devDependencies[dep] ?? '';

      if (version.isEmpty || version == 'any') {
        issues.add(StaticIssue(
          id: 'pubspec_security',
          title: '依赖安全 — 无界版本',
          file: pubspecPath,
          line: null,
          level: RiskLevel.medium,
          domain: IssueDomain.standards,
          priority: Priority.p2,
          message: '依赖 "$dep" 没有版本约束 ($version)',
          detail: '包: $dep\n'
              '版本: ${version.isEmpty ? "未指定" : version}\n'
              '无界依赖可能导致不兼容的版本被引入',
          suggestion: '为 "$dep" 添加具体的版本约束 (如 ^1.0.0)',
          metadata: {
            'package': dep,
            'version': version,
            'check': 'unbounded_dependency',
          },
        ));
      }

      if (_deprecatedPackages.containsKey(dep)) {
        final replacement = _deprecatedPackages[dep]!;
        issues.add(StaticIssue(
          id: 'pubspec_security',
          title: '依赖安全 — 已废弃包',
          file: pubspecPath,
          line: null,
          level: RiskLevel.high,
          domain: IssueDomain.standards,
          priority: Priority.p2,
          message: '"$dep" 已废弃，应迁移至 "$replacement"',
          detail: '包: $dep\n'
              '替代: $replacement\n'
              '$dep 已不再维护，存在安全风险',
          suggestion: '将 "$dep" 替换为 "$replacement"',
          metadata: {
            'package': dep,
            'replacement': replacement,
            'check': 'deprecated_package',
          },
        ));
      }

      if (_vulnerableDeps.containsKey(dep)) {
        final minVersion = _vulnerableDeps[dep]!;
        final currentVersion = _cleanVersion(version);
        if (currentVersion.isNotEmpty &&
            _compareVersion(currentVersion, minVersion) < 0) {
          issues.add(StaticIssue(
            id: 'pubspec_security',
            title: '依赖安全 — 过旧版本',
            file: pubspecPath,
            line: null,
            level: RiskLevel.high,
            domain: IssueDomain.standards,
            priority: Priority.p2,
            message: '"$dep" 版本 $currentVersion 低于推荐的最低版本 $minVersion',
            detail: '包: $dep\n'
                '当前: $currentVersion\n'
                '最低推荐: $minVersion\n'
                '旧版本可能包含已知安全漏洞',
            suggestion: '将 "$dep" 升级至至少 $minVersion',
            metadata: {
              'package': dep,
              'currentVersion': currentVersion,
              'minVersion': minVersion,
              'check': 'outdated_dependency',
            },
          ));
        }
      }
    }

    return issues;
  }

  void _collectDeps(dynamic deps, Map<String, String> target) {
    if (deps is! YamlMap) return;
    for (final entry in deps.entries) {
      final name = entry.key.toString();
      final value = entry.value;
      if (value is String) {
        target[name] = value;
      } else if (value is YamlMap) {
        target[name] = value['version']?.toString() ?? '';
      }
    }
  }

  String _cleanVersion(String version) {
    return version.replaceAll(RegExp(r'[\^~]'), '').trim();
  }

  int _compareVersion(String a, String b) {
    final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (var i = 0; i < aParts.length && i < bParts.length; i++) {
      final cmp = aParts[i].compareTo(bParts[i]);
      if (cmp != 0) return cmp;
    }
    return aParts.length.compareTo(bParts.length);
  }

  List<StaticIssue> _deduplicate(List<StaticIssue> issues) {
    final seen = <String>{};
    return issues.where((i) {
      final key = '${i.id}|${i.file}|${i.line}|${i.message}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  static RuleMeta describe() => const RuleMeta(
        id: 'pubspec_security',
        name: '依赖安全风险',
        domain: 'standards',
        riskLevel: 'medium',
        priority: 'p2',
        purpose: '检测依赖版本无界、已废弃包、过旧版本',
        riskReason: '无界依赖引入不兼容更新；废弃包存在安全漏洞',
        badExample: 'mqtt_client: ^9.0.0（低于 10.0.0）；flutter_blue（已废弃）',
        fixSuggestion: '固定大版本号；将 flutter_blue 迁移至 flutter_blue_plus',
        cicdSafe: true,
      );
}
