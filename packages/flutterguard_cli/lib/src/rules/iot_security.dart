import 'dart:io';

import '../config_loader.dart';
import '../domain.dart';
import '../priority.dart';
import '../static_issue.dart';

final _secretPattern = RegExp(
  r"""(password|token|secret|api[_]?key)\s*[:=]\s*["']""",
  caseSensitive: false,
);
const _cleartextMqttPatterns = ['tcp://', 'port: 1883', 'port:1883'];
const _insecureBleKeywords = ['withoutBonding', 'withoutPairing'];
final _httpUrlPattern = RegExp(r"""['"]http://[^'"]+['"]""");

class IotSecurityRule {
  final IotSecurityRuleConfig config;

  const IotSecurityRule(this.config);

  List<StaticIssue> analyze(List<String> files) {
    if (!config.enabled) return [];

    final issues = <StaticIssue>[];

    for (final file in files) {
      try {
        final content = File(file).readAsStringSync();
        issues.addAll(_checkFile(file, content));
      } catch (_) {}
    }

    return issues;
  }

  List<StaticIssue> _checkFile(String file, String content) {
    final issues = <StaticIssue>[];
    final lines = content.split('\n');

    _checkHardcodedSecrets(file, lines, issues);

    if (config.requireTls) {
      _checkCleartextMqtt(file, lines, issues);
      _checkCleartextHttp(file, lines, issues);
    }

    _checkInsecureBle(file, lines, issues);

    return issues;
  }

  void _checkHardcodedSecrets(
    String file,
    List<String> lines,
    List<StaticIssue> issues,
  ) {
    for (var i = 0; i < lines.length; i++) {
      if (_secretPattern.hasMatch(lines[i])) {
        issues.add(StaticIssue(
          id: 'iot_security',
          title: 'IoT 安全 — 硬编码凭证',
          file: file,
          line: i + 1,
          level: RiskLevel.high,
          domain: IssueDomain.architecture,
          priority: Priority.p0,
          message: '检测到可疑的硬编码凭证',
          detail: '行 ${i + 1}: ${lines[i].trim()}\n'
              '硬编码凭证可能导致安全泄露，应使用环境变量或安全存储',
          suggestion: '使用环境变量或安全存储方案替代硬编码凭证',
          metadata: {
            'securityCheck': 'hardcoded_secret',
            'line': i + 1,
          },
        ));
      }
    }
  }

  void _checkCleartextMqtt(
    String file,
    List<String> lines,
    List<StaticIssue> issues,
  ) {
    for (var i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      for (final pattern in _cleartextMqttPatterns) {
        if (lower.contains(pattern)) {
          issues.add(StaticIssue(
            id: 'iot_security',
            title: 'IoT 安全 — 明文 MQTT 连接',
            file: file,
            line: i + 1,
            level: RiskLevel.high,
            domain: IssueDomain.architecture,
            priority: Priority.p0,
            message: '检测到明文 MQTT 连接配置: "$pattern"',
            detail: '行 ${i + 1}: ${lines[i].trim()}\n'
                '明文 MQTT 连接不安全，应使用 mqtts:// (TLS) 或端口 8883',
            suggestion: '将 MQTT 连接升级为 mqtts:// 并使用端口 8883',
            metadata: {
              'securityCheck': 'cleartext_mqtt',
              'pattern': pattern,
              'line': i + 1,
            },
          ));
        }
      }
    }
  }

  void _checkCleartextHttp(
    String file,
    List<String> lines,
    List<StaticIssue> issues,
  ) {
    for (var i = 0; i < lines.length; i++) {
      for (final match in _httpUrlPattern.allMatches(lines[i])) {
        final url = match.group(0) ?? '';
        if (url.contains('localhost') || url.contains('127.0.0.1')) continue;

        issues.add(StaticIssue(
          id: 'iot_security',
          title: 'IoT 安全 — 明文 HTTP 连接',
          file: file,
          line: i + 1,
          level: RiskLevel.medium,
          domain: IssueDomain.architecture,
          priority: Priority.p0,
          message: '检测到明文 HTTP URL: $url',
          detail: '行 ${i + 1}: ${lines[i].trim()}\n明文 HTTP 不安全，应使用 HTTPS',
          suggestion: '将 HTTP 连接升级为 HTTPS',
          metadata: {
            'securityCheck': 'cleartext_http',
            'url': url,
          },
        ));
      }
    }
  }

  void _checkInsecureBle(
    String file,
    List<String> lines,
    List<StaticIssue> issues,
  ) {
    for (var i = 0; i < lines.length; i++) {
      for (final keyword in _insecureBleKeywords) {
        if (lines[i].contains(keyword)) {
          issues.add(StaticIssue(
            id: 'iot_security',
            title: 'IoT 安全 — 不安全 BLE 配置',
            file: file,
            line: i + 1,
            level: RiskLevel.medium,
            domain: IssueDomain.architecture,
            priority: Priority.p0,
            message: '检测到不安全的 BLE 连接配置: "$keyword"',
            detail: '行 ${i + 1}: ${lines[i].trim()}\n'
                'BLE 连接应启用配对和加密 (bond / pair)',
            suggestion: '启用 BLE 配对和加密配置',
            metadata: {
              'securityCheck': 'insecure_ble',
              'keyword': keyword,
              'line': i + 1,
            },
          ));
        }
      }
    }
  }
}
