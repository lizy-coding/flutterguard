import 'dart:io';

import 'package:flutterguard_cli/src/config_loader.dart';
import 'package:flutterguard_cli/src/config_tools.dart';
import 'package:flutterguard_cli/src/rules/registry.dart';
import 'package:flutterguard_cli/src/static_issue.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('zero-config defaults remain small and deterministic', () {
    final config = ScanConfig.defaults();
    expect(config.include, ['lib/**']);
    expect(config.architecture.layers, isEmpty);
    expect(config.configuredRuleIds, isEmpty);
  });

  test('generic rule config parses severity and typed options', () {
    final directory = Directory.systemTemp.createTempSync('fg_config_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File(p.join(directory.path, 'flutterguard.yaml'))
      ..writeAsStringSync('''
rules:
  iot_security:
    enabled: true
    severity: high
    requireTls: false
''');
    final config = ScanConfig.fromFile(file.path);
    final definition = RuleRegistry.find('iot_security')!;
    final rule = config.rule(
      definition.id,
      defaultSeverity: definition.defaultSeverity,
      defaultOptions: definition.defaultOptions,
    );
    expect(rule.severity, RiskLevel.high);
    expect(rule.boolOption('requireTls'), isFalse);
  });

  test('rule registry drives the generated starter config', () {
    final template = ConfigTools.initTemplate(withArchitecture: false);
    expect(RuleRegistry.all(), hasLength(16));
    for (final rule in RuleRegistry.all()) {
      expect(template, contains('  ${rule.id}:'));
    }
    expect(template, isNot(contains('confidence_threshold')));
    expect(template, isNot(contains('large_file:')));
    expect(template, isNot(contains('mqtt_connection:')));
    expect(template, isNot(contains('pubspec_security:')));
  });

  test('invalid config values fail fast', () {
    final directory = Directory.systemTemp.createTempSync('fg_bad_config_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File(p.join(directory.path, 'flutterguard.yaml'))
      ..writeAsStringSync('rules:\n  ble_scanning: false\n');
    expect(() => ScanConfig.fromFile(file.path), throwsFormatException);
  });

  test('config check rejects unknown rule IDs', () {
    final project = Directory.systemTemp.createTempSync('fg_doctor_');
    addTearDown(() => project.deleteSync(recursive: true));
    Directory(p.join(project.path, 'lib')).createSync();
    File(
      p.join(project.path, 'lib', 'main.dart'),
    ).writeAsStringSync('class A {}');
    File(p.join(project.path, 'flutterguard.yaml')).writeAsStringSync('''
rules:
  removed_rule:
    enabled: true
''');
    final result = ConfigTools.doctor(projectPath: project.path);
    expect(result.hasErrors, isTrue);
    expect(result.messages.single.message, contains('removed_rule'));
  });

  test('config check rejects options absent from the rule definition', () {
    final project = Directory.systemTemp.createTempSync('fg_options_');
    addTearDown(() => project.deleteSync(recursive: true));
    Directory(p.join(project.path, 'lib')).createSync();
    File(
      p.join(project.path, 'lib', 'main.dart'),
    ).writeAsStringSync('class A {}');
    File(p.join(project.path, 'flutterguard.yaml')).writeAsStringSync('''
rules:
  ble_scanning:
    allowlist: [LegacyScanner]
''');
    expect(
      () => ConfigTools.doctor(projectPath: project.path),
      throwsFormatException,
    );

    File(p.join(project.path, 'flutterguard.yaml')).writeAsStringSync('''
rules:
  ble_scanning:
    timeoutAlias: 5000
''');
    final result = ConfigTools.doctor(projectPath: project.path);
    expect(result.hasErrors, isTrue);
    expect(result.messages.single.message, contains('timeoutAlias'));
  });
}
