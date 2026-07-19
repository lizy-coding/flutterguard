import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_cli/src/baseline.dart';
import 'package:flutterguard_cli/src/report_generator.dart';
import 'package:flutterguard_cli/src/sarif_report.dart';
import 'package:flutterguard_cli/src/scanner.dart';
import 'package:flutterguard_cli/src/static_issue.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Directory _project() {
  final project = Directory.systemTemp.createTempSync('fg_project_');
  Directory(p.join(project.path, 'lib')).createSync();
  File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('''
name: fixture_project
environment:
  sdk: ^3.11.0
''');
  File(p.join(project.path, 'lib', 'device.dart')).writeAsStringSync('''
class Device {
  void connect() {
    final password = 'admin123';
    final broker = 'tcp://192.168.1.2:1883';
  }
}
''');
  return project;
}

void main() {
  test('scanner uses built-in defaults and sorts findings', () {
    final project = _project();
    addTearDown(() => project.deleteSync(recursive: true));
    final result = FlutterGuardScanner.scan(projectPath: project.path);
    expect(result.files, hasLength(1));
    expect(result.issues, isNotEmpty);
    expect(result.issues.first.level, RiskLevel.high);
  });

  test('JSON report uses the compact 2.0 contract', () {
    final project = _project();
    addTearDown(() => project.deleteSync(recursive: true));
    final result = FlutterGuardScanner.scan(
      projectPath: project.path,
      writeJson: true,
    );
    final report = File(p.join(result.reportDir, 'report.json'));
    final json = jsonDecode(report.readAsStringSync()) as Map<String, Object?>;
    expect(json['schemaVersion'], '2.0.0');
    final issue = (json['issues'] as List).first as Map<String, Object?>;
    expect(issue, contains('ruleId'));
    expect(issue, contains('severity'));
    expect(issue, isNot(contains('id')));
    expect(issue, isNot(contains('priority')));
    expect(issue, isNot(contains('confidence')));
  });

  test('severity is the only CI gate dimension', () {
    final issues = [
      StaticIssue(
        id: 'test',
        title: 'test',
        file: '/tmp/test.dart',
        level: RiskLevel.medium,
        domain: IssueDomain.architecture,
        message: 'test',
        suggestion: 'fix',
      ),
    ];
    expect(ReportGenerator.shouldFail(issues, 'high'), isFalse);
    expect(ReportGenerator.shouldFail(issues, 'medium'), isTrue);
    expect(ReportGenerator.shouldFail(issues, 'none'), isFalse);
  });

  test('baseline fingerprints remain stable for the compact issue model', () {
    final issue = StaticIssue(
      id: 'test',
      title: 'test',
      file: '/project/lib/test.dart',
      line: 3,
      level: RiskLevel.medium,
      domain: IssueDomain.architecture,
      message: 'message',
      suggestion: 'fix',
    );
    final encoded = Baseline.encode(projectPath: '/project', issues: [issue]);
    final baseline = Baseline.loadFromString(encoded);
    expect(baseline.contains(issue, '/project'), isTrue);
  });

  test('SARIF contains the same registry and finding IDs', () {
    final issue = StaticIssue(
      id: 'iot_security',
      title: 'security',
      file: '/project/lib/test.dart',
      level: RiskLevel.high,
      domain: IssueDomain.architecture,
      message: 'message',
      suggestion: 'fix',
    );
    final sarif =
        jsonDecode(
              SarifReport.generate(projectPath: '/project', issues: [issue]),
            )
            as Map<String, Object?>;
    expect(jsonEncode(sarif), contains('iot_security'));
    expect(jsonEncode(sarif), isNot(contains('confidence')));
  });
}
