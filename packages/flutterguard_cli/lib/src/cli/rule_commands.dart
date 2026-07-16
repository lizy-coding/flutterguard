import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../rules/registry.dart';

class RuleCommands {
  static void list(ArgResults args) {
    final all = RuleRegistry.all();
    if (args['format'] == 'json') {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(
        all.map((meta) => meta.toJson()).toList(),
      ));
      return;
    }

    all.sort((a, b) => a.id.compareTo(b.id));
    stdout.writeln('可用规则 (${all.length}):');
    stdout.writeln();
    for (final rule in all) {
      stdout.writeln(
        '  ${rule.id.padRight(36)} ${rule.domain.padRight(14)} '
        '${rule.framework.padRight(10)} ${rule.confidence.padRight(14)} '
        '${rule.name}',
      );
    }
    stdout.writeln();
    stdout.writeln('执行 flutterguard explain <rule-id> 查看详情');
  }

  static void explain(ArgResults args) {
    final rest = args.rest;
    if (rest.isEmpty) {
      stderr.writeln('Error: 请指定规则 ID');
      stderr.writeln('用法: flutterguard explain <rule-id>');
      stderr.writeln('可用规则: ${_ruleIds()}');
      exit(2);
    }

    final ruleId = rest.first;
    final meta = RuleRegistry.find(ruleId);
    if (meta == null) {
      stderr.writeln('Error: 未找到规则 "$ruleId"');
      stderr.writeln('可用规则: ${_ruleIds()}');
      exit(2);
    }

    stdout.writeln('规则: ${meta.id}');
    stdout.writeln('名称: ${meta.name}');
    stdout.writeln('领域: ${meta.domain}');
    stdout.writeln('风险: ${meta.riskLevel}');
    stdout.writeln('优先级: ${meta.priority}');
    stdout.writeln('框架: ${meta.framework}');
    stdout.writeln('置信度: ${meta.confidence}');
    stdout.writeln('CI 阻断: ${meta.cicdSafe ? "是" : "否"}');
    stdout.writeln();
    stdout.writeln('检测目的:');
    stdout.writeln('  ${meta.purpose}');
    stdout.writeln();
    stdout.writeln('风险原因:');
    stdout.writeln('  ${meta.riskReason}');
    stdout.writeln();
    stdout.writeln('典型坏例子:');
    stdout.writeln('  ${meta.badExample}');
    stdout.writeln();
    stdout.writeln('推荐修复:');
    stdout.writeln('  ${meta.fixSuggestion}');
    if (meta.configKeys.isNotEmpty) {
      stdout.writeln();
      stdout.writeln('配置项:');
      for (final key in meta.configKeys) {
        stdout.writeln('  - $key');
      }
    }
  }

  static String _ruleIds() =>
      RuleRegistry.all().map((meta) => meta.id).join(', ');
}
