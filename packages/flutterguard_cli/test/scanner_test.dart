import 'dart:io';

import 'package:flutterguard_cli/src/config_loader.dart';
import 'package:flutterguard_cli/src/file_collector.dart';
import 'package:flutterguard_cli/src/report_generator.dart';
import 'package:flutterguard_cli/src/rules/boundary_import.dart';
import 'package:flutterguard_cli/src/rules/large_units.dart';
import 'package:flutterguard_cli/src/rules/lifecycle_resource.dart';
import 'package:flutterguard_cli/src/static_issue.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String get fixturesPath => p.join(Directory.current.path, 'test', 'fixtures');

void main() {
  group('Static Rules', () {
    test('scan detects large file', () {
      final config = ScanConfig.fromFile(
          p.join(fixturesPath, 'boundary_config.yaml'));
      final files = [p.join(fixturesPath, 'large_file.dart')];

      final issues = LargeUnitsRule(config.rules).analyze(files);

      final largeFileIssue =
          issues.where((i) => i.id == 'large_file').toList();
      expect(largeFileIssue, isNotEmpty);
      expect(largeFileIssue.first.metadata['actual'], greaterThan(500));
    });

    test('scan detects large class', () {
      final config = ScanConfig.fromFile(
          p.join(fixturesPath, 'boundary_config.yaml'));
      final files = [p.join(fixturesPath, 'large_class.dart')];

      final issues = LargeUnitsRule(config.rules).analyze(files);

      final largeClassIssue =
          issues.where((i) => i.id == 'large_class').toList();
      expect(largeClassIssue, isNotEmpty);
    });

    test('scan detects large build method', () {
      final config = ScanConfig.fromFile(
          p.join(fixturesPath, 'boundary_config.yaml'));
      final files = [p.join(fixturesPath, 'large_build.dart')];

      final issues = LargeUnitsRule(config.rules).analyze(files);

      final largeBuildIssue =
          issues.where((i) => i.id == 'large_build_method').toList();
      expect(largeBuildIssue, isNotEmpty);
    });

    test('scan detects lifecycle resource not disposed', () {
      final config = ScanConfig.fromFile(
          p.join(fixturesPath, 'boundary_config.yaml'));
      final files = [p.join(fixturesPath, 'lifecycle_issue.dart')];

      final issues =
          LifecycleResourceRule(config.rules.lifecycleResource).analyze(files);

      expect(issues, isNotEmpty);
      expect(
          issues.any((i) => i.id == 'lifecycle_resource_not_disposed'), isTrue);
    });

    test('scan detects boundary violation', () {
      final config = ScanConfig.fromFile(
          p.join(fixturesPath, 'boundary_config.yaml'));
      final files = [p.join(fixturesPath, 'boundary_issue.dart')];

      final issues = BoundaryImportRule(config.boundaries).analyze(files);

      expect(issues, isNotEmpty);
      expect(issues.any((i) => i.id == 'boundary_import_violation'), isTrue);
    });

    test('ci fail on high returns exit 1 scenario', () {
      final issues = [
        StaticIssue(
          id: 'test_high',
          title: 'Test high',
          file: 'test.dart',
          level: RiskLevel.high,
          message: 'High severity issue',
          suggestion: 'Fix it',
        ),
      ];

      expect(ReportGenerator.shouldFail(issues, 'high'), isTrue);
      expect(ReportGenerator.shouldFail(issues, 'medium'), isTrue);
    });
  });

  group('Report Generation', () {
    test('markdown report is generated', () {
      final issues = [
        StaticIssue(
          id: 'test_issue',
          title: 'Test issue',
          file: '/test/file.dart',
          line: 42,
          level: RiskLevel.medium,
          message: 'A medium issue',
          suggestion: 'Try fixing it',
        ),
      ];

      final md = ReportGenerator.generateMarkdown(
        projectPath: '/test',
        issues: issues,
      );

      expect(md, contains('# FlutterGuard Flow Report'));
      expect(md, contains('## Summary'));
      expect(md, contains('## Static Issues'));
      expect(md, contains('test_issue'));
    });

    test('json report is generated', () {
      final issues = [
        StaticIssue(
          id: 'test_issue',
          title: 'Test issue',
          file: '/test/file.dart',
          level: RiskLevel.low,
          message: 'A low issue',
          suggestion: 'Consider fixing it',
        ),
      ];

      final json = ReportGenerator.generateJson(
        projectPath: '/test',
        issues: issues,
      );

      expect(json, contains('"version"'));
      expect(json, contains('"projectPath"'));
      expect(json, contains('"score"'));
      expect(json, contains('"staticIssues"'));
      expect(json, contains('test_issue'));
    });
  });
}
