import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../config_loader.dart';
import 'rule.dart';
import '../source_workspace.dart';
import '../static_issue.dart';

final _secretNamePattern = RegExp(
  r'^(password|token|secret|api[_]?key)$',
  caseSensitive: false,
);
final _cleartextMqttPattern = RegExp(
  r'tcp://|port:\s*1883',
  caseSensitive: false,
);
const _insecureBleValues = {'withoutBonding', 'withoutPairing'};

class IotSecurityRule {
  final RuleConfig config;

  const IotSecurityRule(this.config);

  List<StaticIssue> analyze(List<String> files, {SourceWorkspace? workspace}) {
    if (!config.enabled) return [];

    final issues = <StaticIssue>[];
    final sources = workspace ?? SourceWorkspace();

    for (final file in files) {
      final source = sources.source(file);
      if (source == null) continue;
      final visitor = _IotSecurityVisitor(
        config,
        file,
        source.lineInfo,
        issues,
      );
      source.unit.accept(visitor);
    }

    return issues;
  }

  static RuleDefinition describe() => const RuleDefinition(
    id: 'iot_security',
    name: 'IoT 安全风险',
    domain: IssueDomain.architecture,
    defaultSeverity: RiskLevel.high,
    purpose: '检测硬编码凭据、明文 MQTT/HTTP、不安全的 BLE 配置',
    riskReason: '硬编码凭据泄露导致设备被入侵；明文传输导致数据窃听',
    badExample: 'password: "123456"；tcp://broker:1883；BLE 使用 withoutBonding',
    fixSuggestion: '使用环境变量或安全存储管理凭据；使用 TLS 加密通信',
    defaultOptions: {'requireTls': true},
  );
}

class _IotSecurityVisitor extends RecursiveAstVisitor<void> {
  final RuleConfig config;
  final String file;
  final LineInfo lineInfo;
  final List<StaticIssue> issues;

  _IotSecurityVisitor(this.config, this.file, this.lineInfo, this.issues);

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    _checkSecret(node);
    _checkCleartextMqtt(node);
    _checkCleartextHttp(node);
    _checkInsecureBle(node);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    _checkSecretArg(node);
    _checkCleartextMqttArg(node);
    _checkInsecureBleArg(node);
    super.visitNamedExpression(node);
  }

  void _checkSecret(VariableDeclaration node) {
    final name = node.name.lexeme;
    if (!_secretNamePattern.hasMatch(name)) return;
    final value = node.initializer;
    if (value is! SimpleStringLiteral || value.stringValue == null) return;
    final stringValue = value.stringValue!;
    if (stringValue.isEmpty) return;

    final line = lineNumberForOffset(lineInfo, node.name.offset);
    issues.add(
      StaticIssue(
        id: 'iot_security',
        title: 'IoT 安全 — 硬编码凭证',
        file: file,
        line: line,
        level: config.severity,
        domain: IssueDomain.architecture,
        message: '检测到可疑的硬编码凭证',
        detail:
            '行 $line: $name = "***"\n'
            '硬编码凭证可能导致安全泄露，应使用环境变量或安全存储',
        suggestion: '使用环境变量或安全存储方案替代硬编码凭证',
        metadata: {'securityCheck': 'hardcoded_secret', 'line': line},
      ),
    );
  }

  void _checkSecretArg(NamedExpression node) {
    final label = node.name.label.name;
    if (!_secretNamePattern.hasMatch(label)) return;
    final value = node.expression;
    if (value is! SimpleStringLiteral || value.stringValue == null) return;
    if (value.stringValue!.isEmpty) return;

    final line = lineNumberForOffset(lineInfo, node.offset);
    issues.add(
      StaticIssue(
        id: 'iot_security',
        title: 'IoT 安全 — 硬编码凭证',
        file: file,
        line: line,
        level: config.severity,
        domain: IssueDomain.architecture,
        message: '检测到可疑的硬编码凭证',
        detail:
            '行 $line: $label = "***"\n'
            '硬编码凭证可能导致安全泄露，应使用环境变量或安全存储',
        suggestion: '使用环境变量或安全存储方案替代硬编码凭证',
        metadata: {'securityCheck': 'hardcoded_secret', 'line': line},
      ),
    );
  }

  void _checkCleartextMqtt(VariableDeclaration node) {
    if (!config.boolOption('requireTls')) return;
    final value = node.initializer;
    if (value is! SimpleStringLiteral || value.stringValue == null) return;
    if (!_cleartextMqttPattern.hasMatch(value.stringValue!)) return;

    final line = lineNumberForOffset(lineInfo, node.name.offset);
    issues.add(
      StaticIssue(
        id: 'iot_security',
        title: 'IoT 安全 — 明文 MQTT 连接',
        file: file,
        line: line,
        level: config.severity,
        domain: IssueDomain.architecture,
        message: '检测到明文 MQTT 连接配置',
        detail:
            '行 $line: ${value.toSource()}\n'
            '明文 MQTT 连接不安全，应使用 mqtts:// (TLS) 或端口 8883',
        suggestion: '将 MQTT 连接升级为 mqtts:// 并使用端口 8883',
        metadata: {'securityCheck': 'cleartext_mqtt', 'line': line},
      ),
    );
  }

  void _checkCleartextMqttArg(NamedExpression node) {
    if (!config.boolOption('requireTls')) return;
    final value = node.expression;
    if (value is! SimpleStringLiteral || value.stringValue == null) return;
    if (!_cleartextMqttPattern.hasMatch(value.stringValue!)) return;

    final line = lineNumberForOffset(lineInfo, node.offset);
    issues.add(
      StaticIssue(
        id: 'iot_security',
        title: 'IoT 安全 — 明文 MQTT 连接',
        file: file,
        line: line,
        level: config.severity,
        domain: IssueDomain.architecture,
        message: '检测到明文 MQTT 连接配置',
        detail:
            '行 $line: ${value.toSource()}\n'
            '明文 MQTT 连接不安全，应使用 mqtts:// (TLS) 或端口 8883',
        suggestion: '将 MQTT 连接升级为 mqtts:// 并使用端口 8883',
        metadata: {'securityCheck': 'cleartext_mqtt', 'line': line},
      ),
    );
  }

  void _checkCleartextHttp(VariableDeclaration node) {
    if (!config.boolOption('requireTls')) return;
    final value = node.initializer;
    if (value is! SimpleStringLiteral || value.stringValue == null) return;
    final url = value.stringValue!;
    if (!url.startsWith('http://')) return;
    if (url.contains('localhost') || url.contains('127.0.0.1')) return;

    final line = lineNumberForOffset(lineInfo, node.name.offset);
    issues.add(
      StaticIssue(
        id: 'iot_security',
        title: 'IoT 安全 — 明文 HTTP 连接',
        file: file,
        line: line,
        level: config.severity,
        domain: IssueDomain.architecture,
        message: '检测到明文 HTTP URL: $url',
        detail: '行 $line: ${value.toSource()}\n明文 HTTP 不安全，应使用 HTTPS',
        suggestion: '将 HTTP 连接升级为 HTTPS',
        metadata: {'securityCheck': 'cleartext_http', 'url': url},
      ),
    );
  }

  void _checkInsecureBle(VariableDeclaration node) {
    final value = node.initializer;
    if (value is! SimpleStringLiteral || value.stringValue == null) return;
    final literalValue = value.stringValue!;
    if (!_insecureBleValues.contains(literalValue)) return;

    final line = lineNumberForOffset(lineInfo, node.name.offset);
    issues.add(
      StaticIssue(
        id: 'iot_security',
        title: 'IoT 安全 — 不安全 BLE 配置',
        file: file,
        line: line,
        level: config.severity,
        domain: IssueDomain.architecture,
        message: '检测到不安全的 BLE 连接配置: "$literalValue"',
        detail:
            '行 $line: ${value.toSource()}\n'
            'BLE 连接应启用配对和加密 (bond / pair)',
        suggestion: '启用 BLE 配对和加密配置',
        metadata: {
          'securityCheck': 'insecure_ble',
          'keyword': literalValue,
          'line': line,
        },
      ),
    );
  }

  void _checkInsecureBleArg(NamedExpression node) {
    final value = node.expression;
    if (value is! SimpleStringLiteral || value.stringValue == null) return;
    final literalValue = value.stringValue!;
    if (!_insecureBleValues.contains(literalValue)) return;

    final line = lineNumberForOffset(lineInfo, node.offset);
    issues.add(
      StaticIssue(
        id: 'iot_security',
        title: 'IoT 安全 — 不安全 BLE 配置',
        file: file,
        line: line,
        level: config.severity,
        domain: IssueDomain.architecture,
        message: '检测到不安全的 BLE 连接配置: "$literalValue"',
        detail:
            '行 $line: ${value.toSource()}\n'
            'BLE 连接应启用配对和加密 (bond / pair)',
        suggestion: '启用 BLE 配对和加密配置',
        metadata: {
          'securityCheck': 'insecure_ble',
          'keyword': literalValue,
          'line': line,
        },
      ),
    );
  }
}
