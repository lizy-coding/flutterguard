import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

import '../rules/registry.dart';
import '../rules/rule.dart';

class RuleCommands {
  static void run(ArgResults args) {
    if (args.rest.isNotEmpty) {
      _describe(args.rest.first, json: args['format'] == 'json');
      return;
    }
    final rules = RuleRegistry.all()..sort((a, b) => a.id.compareTo(b.id));
    if (args['format'] == 'json') {
      stdout.writeln(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(rules.map((rule) => rule.toJson()).toList()),
      );
      return;
    }
    stdout.writeln('Available rules (${rules.length}):');
    for (final rule in rules) {
      stdout.writeln(
        '  ${rule.id.padRight(36)} '
        '${rule.domain.name.padRight(14)} '
        '${rule.defaultSeverity.name.padRight(8)} ${rule.name}',
      );
    }
    stdout.writeln();
    stdout.writeln('Run flutterguard rules <rule-id> for details.');
  }

  static void _describe(String id, {required bool json}) {
    final rule = RuleRegistry.find(id);
    if (rule == null) {
      stderr.writeln('Error: unknown rule "$id".');
      exit(2);
    }
    if (json) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(rule.toJson()));
      return;
    }
    _writeDefinition(rule);
  }

  static void _writeDefinition(RuleDefinition rule) {
    stdout.writeln('Rule: ${rule.id}');
    stdout.writeln('Name: ${rule.name}');
    stdout.writeln('Domain: ${rule.domain.name}');
    stdout.writeln('Severity: ${rule.defaultSeverity.name}');
    stdout.writeln('Framework: ${rule.framework}');
    stdout.writeln();
    stdout.writeln('Purpose: ${rule.purpose}');
    stdout.writeln('Risk: ${rule.riskReason}');
    stdout.writeln('Example: ${rule.badExample}');
    stdout.writeln('Fix: ${rule.fixSuggestion}');
    stdout.writeln('Config: ${rule.configKeys.join(', ')}');
  }
}
