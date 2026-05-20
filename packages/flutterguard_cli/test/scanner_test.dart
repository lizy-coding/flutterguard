import 'dart:io';

import 'package:flutterguard_cli/src/config_loader.dart';
import 'package:flutterguard_cli/src/domain.dart';
import 'package:flutterguard_cli/src/import_utils.dart';
import 'package:flutterguard_cli/src/path_utils.dart';
import 'package:flutterguard_cli/src/priority.dart';
import 'package:flutterguard_cli/src/report_generator.dart';
import 'package:flutterguard_cli/src/rules/circular_dependency.dart';
import 'package:flutterguard_cli/src/rules/large_units.dart';
import 'package:flutterguard_cli/src/rules/layer_violation.dart';
import 'package:flutterguard_cli/src/rules/lifecycle_resource.dart';
import 'package:flutterguard_cli/src/rules/missing_const_constructor.dart';
import 'package:flutterguard_cli/src/rules/module_violation.dart';
import 'package:flutterguard_cli/src/static_issue.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String get fixturesPath => p.join(Directory.current.path, 'test', 'fixtures');

void main() {
  group('Static Rules', () {
    test('scan detects large file', () {
      final config =
          ScanConfig.fromFile(p.join(fixturesPath, 'architecture_config.yaml'));
      final files = [p.join(fixturesPath, 'large_file.dart')];

      final issues = LargeUnitsRule(
        largeFileConfig: config.rules.largeFile,
        largeClassConfig: config.rules.largeClass,
        largeBuildMethodConfig: config.rules.largeBuildMethod,
      ).analyze(files);

      final largeFileIssue = issues.where((i) => i.id == 'large_file').toList();
      expect(largeFileIssue, isNotEmpty);
      expect(largeFileIssue.first.metadata['actual'], greaterThan(500));
    });

    test('scan detects large class', () {
      final config =
          ScanConfig.fromFile(p.join(fixturesPath, 'architecture_config.yaml'));
      final files = [p.join(fixturesPath, 'large_class.dart')];

      final issues = LargeUnitsRule(
        largeFileConfig: config.rules.largeFile,
        largeClassConfig: config.rules.largeClass,
        largeBuildMethodConfig: config.rules.largeBuildMethod,
      ).analyze(files);

      final largeClassIssue =
          issues.where((i) => i.id == 'large_class').toList();
      expect(largeClassIssue, isNotEmpty);
    });

    test('scan detects large build method', () {
      final config =
          ScanConfig.fromFile(p.join(fixturesPath, 'architecture_config.yaml'));
      final files = [p.join(fixturesPath, 'large_build.dart')];

      final issues = LargeUnitsRule(
        largeFileConfig: config.rules.largeFile,
        largeClassConfig: config.rules.largeClass,
        largeBuildMethodConfig: config.rules.largeBuildMethod,
      ).analyze(files);

      final largeBuildIssue =
          issues.where((i) => i.id == 'large_build_method').toList();
      expect(largeBuildIssue, isNotEmpty);
    });

    test('scan detects lifecycle resource not disposed', () {
      final config =
          ScanConfig.fromFile(p.join(fixturesPath, 'architecture_config.yaml'));
      final files = [p.join(fixturesPath, 'lifecycle_issue.dart')];

      final issues =
          LifecycleResourceRule(config.rules.lifecycleResource).analyze(files);

      expect(issues, isNotEmpty);
      expect(
          issues.any((i) => i.id == 'lifecycle_resource_not_disposed'), isTrue);
    });

    test('scan detects layer violation', () {
      final config =
          ScanConfig.fromFile(p.join(fixturesPath, 'architecture_config.yaml'));
      final files = [
        p.join(fixturesPath, 'boundary_issue.dart'),
        p.join(fixturesPath, 'forbidden_file.dart'),
      ];

      final issues =
          LayerViolationRule(config.architecture.layers).analyze(files);

      expect(issues, isNotEmpty);
      expect(issues.any((i) => i.id == 'layer_violation'), isTrue);
    });

    test('layer violation matches project-relative architecture paths', () {
      final files = [
        p.join(fixturesPath, 'boundary_issue.dart'),
        p.join(fixturesPath, 'forbidden_file.dart'),
      ];

      final issues = LayerViolationRule(
        const [
          (
            name: 'ui',
            path: 'test/fixtures/boundary_issue.dart',
            allowedDeps: []
          ),
          (
            name: 'model',
            path: 'test/fixtures/forbidden_file.dart',
            allowedDeps: [],
          ),
        ],
        projectPath: Directory.current.path,
      ).analyze(files);

      expect(issues, isNotEmpty);
      expect(issues.any((i) => i.id == 'layer_violation'), isTrue);
    });

    test('scan detects module violation', () {
      final config =
          ScanConfig.fromFile(p.join(fixturesPath, 'architecture_config.yaml'));
      final files = [
        p.join(fixturesPath, 'boundary_issue.dart'),
        p.join(fixturesPath, 'forbidden_file.dart'),
      ];

      final issues =
          ModuleViolationRule(config.architecture.modules).analyze(files);

      expect(issues, isNotEmpty);
      expect(issues.any((i) => i.id == 'module_violation'), isTrue);
    });

    test('scan detects circular dependency', () {
      final files = [
        p.join(fixturesPath, 'cycle_a.dart'),
        p.join(fixturesPath, 'cycle_b.dart'),
        p.join(fixturesPath, 'cycle_c.dart'),
      ];

      final issues = const CircularDependencyRule(enabled: true).analyze(files);

      expect(issues, isNotEmpty);
      expect(issues.any((i) => i.id == 'circular_dependency'), isTrue);
    });

    test('scan detects missing const constructor in widgets', () {
      final config =
          ScanConfig.fromFile(p.join(fixturesPath, 'architecture_config.yaml'));
      final files = [p.join(fixturesPath, 'missing_const.dart')];

      final issues = MissingConstConstructorRule(
        config.rules.missingConstConstructor,
      ).analyze(files);

      expect(issues, hasLength(2));
      expect(issues.any((i) => i.id == 'missing_const_constructor'), isTrue);
      expect(issues.any((i) => i.metadata['className'] == 'MissingConstWidget'),
          isTrue);
      expect(issues.any((i) => i.metadata['className'] == 'MyStatefulWidget'),
          isTrue);
    });

    test('architecture config parses layer/module enabled flags', () {
      final enabledConfig =
          ScanConfig.fromFile(p.join(fixturesPath, 'architecture_config.yaml'));
      expect(enabledConfig.architecture.layerViolationEnabled, isTrue);
      expect(enabledConfig.architecture.moduleViolationEnabled, isTrue);

      final disabledConfig = ScanConfig.fromFile(
          p.join(fixturesPath, 'architecture_disabled.yaml'));
      expect(disabledConfig.architecture.layerViolationEnabled, isFalse);
      expect(disabledConfig.architecture.moduleViolationEnabled, isFalse);
    });

    test('wiring: disabled layer/module violations produce no issues', () {
      final config = ScanConfig.fromFile(
          p.join(fixturesPath, 'architecture_disabled.yaml'));
      final files = [
        p.join(fixturesPath, 'boundary_issue.dart'),
        p.join(fixturesPath, 'forbidden_file.dart'),
      ];

      List<StaticIssue> issues = [];
      if (config.architecture.layerViolationEnabled) {
        issues.addAll(
            LayerViolationRule(config.architecture.layers).analyze(files));
      }
      if (config.architecture.moduleViolationEnabled) {
        issues.addAll(
            ModuleViolationRule(config.architecture.modules).analyze(files));
      }
      expect(issues, isEmpty);
    });

    test('ci fail on high returns exit 1 scenario', () {
      final issues = [
        StaticIssue(
          id: 'test_high',
          title: 'Test high',
          file: 'test.dart',
          level: RiskLevel.high,
          domain: IssueDomain.architecture,
          priority: Priority.p0,
          message: 'High severity issue',
          detail: '',
          suggestion: 'Fix it',
        ),
      ];

      expect(ReportGenerator.shouldFail(issues, 'high'), isTrue);
      expect(ReportGenerator.shouldFail(issues, 'medium'), isTrue);
    });
  });

  group('Report Generation', () {
    test('json report is generated', () {
      final issues = [
        StaticIssue(
          id: 'test_issue',
          title: 'Test issue',
          file: '/test/file.dart',
          line: 42,
          level: RiskLevel.medium,
          domain: IssueDomain.architecture,
          priority: Priority.p1,
          message: 'A medium architecture issue',
          detail: 'Detailed description',
          suggestion: 'Try fixing it',
        ),
      ];

      final json = ReportGenerator.generateJson(
        projectPath: '/test',
        issues: issues,
      );

      expect(json, contains('"version"'));
      expect(json, contains('"projectPath"'));
      expect(json, contains('"score"'));
      expect(json, contains('"issues"'));
      expect(json, contains('"byDomain"'));
      expect(json, contains('test_issue'));
    });
  });

  group('Path handling', () {
    test('matches project-relative globs against Windows paths', () {
      final windows = p.Context(style: p.Style.windows, current: r'C:\repo');

      expect(
        matchesProjectGlob(
          r'C:\repo\lib\presentation\device_page.dart',
          'lib/presentation/**',
          r'C:\repo',
          context: windows,
        ),
        isTrue,
      );
    });

    test('resolves nested package imports from project lib root', () {
      final source =
          p.join(Directory.current.path, 'lib', 'presentation', 'page.dart');
      final target = p.join(Directory.current.path, 'lib', 'data', 'repo.dart');

      final resolved = resolveImport(
        source,
        'package:app/data/repo.dart',
        {source, target},
        projectPath: Directory.current.path,
      );

      expect(resolved, target);
    });

    test('resolves Windows package imports from project lib root', () {
      final windows = p.Context(style: p.Style.windows, current: r'C:\repo');
      const source = r'C:\repo\lib\presentation\page.dart';
      const target = r'C:\repo\lib\data\repo.dart';

      final resolved = resolveImport(
        source,
        'package:app/data/repo.dart',
        {source, target},
        projectPath: r'C:\repo',
        context: windows,
      );

      expect(resolved, target);
    });
  });
}
