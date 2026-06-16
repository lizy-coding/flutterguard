import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../priority.dart';
import '../source_utils.dart';
import '../static_issue.dart';

const _mqttClientTypes = ['MqttClient', 'MQTT', 'MqttConnect'];
const _brokerUrlPrefixes = ['tcp://', 'mqtt://', 'mqtts://'];

class MqttConnectionRule {
  final MqttConnectionRuleConfig config;

  const MqttConnectionRule(this.config);

  List<StaticIssue> analyze(List<String> files) {
    if (!config.enabled) return [];

    final issues = <StaticIssue>[];

    for (final file in files) {
      try {
        final content = File(file).readAsStringSync();
        final result = parseString(content: content, path: file);
        issues.addAll(_checkFile(file, content, result.unit, result.lineInfo));
      } catch (_) {}
    }

    return issues;
  }

  List<StaticIssue> _checkFile(
    String file,
    String rawContent,
    CompilationUnit unit,
    LineInfo lineInfo,
  ) {
    final issues = <StaticIssue>[];

    _checkHardcodedBroker(file, rawContent, lineInfo, issues);

    for (final cls in unit.declarations.whereType<ClassDeclaration>()) {
      final hasMqttField = cls.members
          .whereType<FieldDeclaration>()
          .where((f) {
            final type = f.fields.type?.toString() ?? '';
            return _mqttClientTypes.any((t) => type.contains(t));
          })
          .isNotEmpty;

      if (!hasMqttField) continue;

      final methods = cls.members.whereType<MethodDeclaration>().toList();
      final methodNames = methods.map((m) => m.name.lexeme).toSet();

      if (methodNames.contains('connect') && !methodNames.contains('disconnect')) {
        final connectMethod = methods.firstWhere((m) => m.name.lexeme == 'connect');
        final line = lineNumberForOffset(lineInfo, connectMethod.name.offset);
        issues.add(StaticIssue(
          id: 'mqtt_connection',
          title: 'MQTT 连接未断开',
          file: file,
          line: line,
          level: RiskLevel.high,
          domain: IssueDomain.architecture,
          priority: Priority.p0,
          message: '类 "${cls.name.lexeme}" 包含 MQTT connect() 调用但缺少 disconnect()',
          detail: '类: ${cls.name.lexeme}\n'
              'MqttClient 需要连接与断开配对',
          suggestion: '在类中添加 disconnect() 方法并在 dispose 中调用',
          metadata: {
            'className': cls.name.lexeme,
            'check': 'connect_without_disconnect',
          },
        ));
      }

      if (methodNames.contains('subscribe') && !methodNames.contains('unsubscribe')) {
        final subscribeMethod = methods.firstWhere((m) => m.name.lexeme == 'subscribe');
        final line = lineNumberForOffset(lineInfo, subscribeMethod.name.offset);
        issues.add(StaticIssue(
          id: 'mqtt_connection',
          title: 'MQTT 订阅未取消',
          file: file,
          line: line,
          level: RiskLevel.medium,
          domain: IssueDomain.architecture,
          priority: Priority.p0,
          message: '类 "${cls.name.lexeme}" 包含 MQTT subscribe() 调用但缺少 unsubscribe()',
          detail: '类: ${cls.name.lexeme}\n'
              'MQTT 订阅应在不需要时取消',
          suggestion: '在类中添加 unsubscribe() 方法并在 dispose 中调用',
          metadata: {
            'className': cls.name.lexeme,
            'check': 'subscribe_without_unsubscribe',
          },
        ));
      }
    }

    return issues;
  }

  void _checkHardcodedBroker(
    String file,
    String content,
    LineInfo lineInfo,
    List<StaticIssue> issues,
  ) {
    final lines = content.split('\n');
    for (var i = 0; i < lines.length; i++) {
      for (final prefix in _brokerUrlPrefixes) {
        if (lines[i].contains(prefix)) {
          issues.add(StaticIssue(
            id: 'mqtt_connection',
            title: 'MQTT — 硬编码 Broker URL',
            file: file,
            line: i + 1,
            level: RiskLevel.medium,
            domain: IssueDomain.architecture,
            priority: Priority.p0,
            message: '检测到硬编码的 MQTT broker URL',
            detail: '行 ${i + 1}: ${lines[i].trim()}\n'
                '硬编码 broker URL 降低灵活性和可维护性',
            suggestion: '将 MQTT broker URL 移至配置文件中',
            metadata: {
              'check': 'hardcoded_broker_url',
              'line': i + 1,
            },
          ));
        }
      }
    }
  }
}
