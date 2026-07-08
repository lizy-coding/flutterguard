import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_cli/src/baseline.dart';
import 'package:flutterguard_cli/src/config_loader.dart';
import 'package:flutterguard_cli/src/config_tools.dart';
import 'package:flutterguard_cli/src/domain.dart';
import 'package:flutterguard_cli/src/import_utils.dart';
import 'package:flutterguard_cli/src/path_utils.dart';
import 'package:flutterguard_cli/src/priority.dart';
import 'package:flutterguard_cli/src/report_generator.dart';
import 'package:flutterguard_cli/src/rules/circular_dependency.dart';
import 'package:flutterguard_cli/src/rules/large_units.dart';
import 'package:flutterguard_cli/src/rules/layer_violation.dart';
import 'package:flutterguard_cli/src/rules/ble_scanning.dart';
import 'package:flutterguard_cli/src/rules/device_lifecycle.dart';
import 'package:flutterguard_cli/src/rules/iot_security.dart';
import 'package:flutterguard_cli/src/rules/lifecycle_resource.dart';
import 'package:flutterguard_cli/src/rules/missing_const_constructor.dart';
import 'package:flutterguard_cli/src/rules/module_violation.dart';
import 'package:flutterguard_cli/src/rules/mqtt_connection.dart';
import 'package:flutterguard_cli/src/rules/pubspec_security.dart';
import 'package:flutterguard_cli/src/rules/registry.dart';
import 'package:flutterguard_cli/src/sarif_report.dart';
import 'package:flutterguard_cli/src/scanner.dart';
import 'package:flutterguard_cli/src/static_issue.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String get fixturesPath => p.join(Directory.current.path, 'test', 'fixtures');

void _runGit(Directory dir, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: dir.path);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

void _writeMinimalProjectConfig(Directory dir) {
  File(p.join(dir.path, 'flutterguard.yaml')).writeAsStringSync('''
include:
  - lib/**
architecture:
  detect_cycles: true
''');
}

void _writeWidgetIssue(String path, String className) {
  File(path).writeAsStringSync('''
class StatelessWidget {}
class $className extends StatelessWidget {}
''');
}

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

    test('scan detects iot security issues', () {
      final files = [p.join(fixturesPath, 'iot_security_issue.dart')];
      final config = (enabled: true, requireTls: true);

      final issues = IotSecurityRule(config).analyze(files);

      expect(
          issues.any((i) => i.metadata['securityCheck'] == 'hardcoded_secret'),
          isTrue);
      expect(issues.any((i) => i.metadata['securityCheck'] == 'cleartext_mqtt'),
          isTrue);
      expect(issues.any((i) => i.metadata['securityCheck'] == 'cleartext_http'),
          isTrue);
      expect(issues.any((i) => i.metadata['securityCheck'] == 'insecure_ble'),
          isTrue);
    });

    test('scan detects device lifecycle issues', () {
      final files = [p.join(fixturesPath, 'device_lifecycle_issue.dart')];
      final config = (enabled: true);

      final issues = DeviceLifecycleRule(config).analyze(files);

      expect(issues.any((i) => i.id == 'device_lifecycle'), isTrue);
      expect(
          issues.any((i) => i.metadata['initMethod'] == 'initState'), isTrue);
      expect(
          issues.any((i) => i.metadata['teardownMethod'] == 'dispose'), isTrue);
    });

    test('scan detects mqtt connection issues', () {
      final files = [p.join(fixturesPath, 'mqtt_connection_issue.dart')];
      final config = (enabled: true);

      final issues = MqttConnectionRule(config).analyze(files);

      expect(issues.any((i) => i.id == 'mqtt_connection'), isTrue);
      expect(
          issues
              .any((i) => i.metadata['check'] == 'connect_without_disconnect'),
          isTrue);
      expect(issues.any((i) => i.metadata['check'] == 'hardcoded_broker_url'),
          isTrue);
    });

    test('scan detects ble scanning issues', () {
      final files = [p.join(fixturesPath, 'ble_scanning_issue.dart')];
      final config = (enabled: true, maxScanDurationMs: 10000);

      final issues = BleScanningRule(config).analyze(files);

      expect(issues.any((i) => i.id == 'ble_scanning'), isTrue);
      expect(
          issues
              .any((i) => i.metadata['check'] == 'startScan_without_stopScan'),
          isTrue);
    });

    test('scan detects pubspec security issues', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_test_');
      addTearDown(() => dir.deleteSync(recursive: true));

      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: test_app
dependencies:
  mqtt_client: ^9.0.0
  flutter_blue: ^0.8.0
  path: any
''');

      File(p.join(dir.path, 'dummy.dart')).writeAsStringSync('// dummy');
      final files = [p.join(dir.path, 'dummy.dart')];
      final config = (enabled: true);

      final issues = PubspecSecurityRule(config).analyze(files);

      expect(issues.any((i) => i.id == 'pubspec_security'), isTrue);
      expect(issues.any((i) => i.metadata['check'] == 'outdated_dependency'),
          isTrue);
      expect(issues.any((i) => i.metadata['check'] == 'deprecated_package'),
          isTrue);
      expect(issues.any((i) => i.metadata['check'] == 'unbounded_dependency'),
          isTrue);
    });

    test('IoT rules respect disabled config', () {
      final files = [p.join(fixturesPath, 'iot_security_issue.dart')];
      final config = (enabled: false, requireTls: true);

      final issues = IotSecurityRule(config).analyze(files);

      expect(issues, isEmpty);
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
      expect(json, contains('"scanMode"'));
      expect(json, contains('"score"'));
      expect(json, contains('"issues"'));
      expect(json, contains('"byDomain"'));
      expect(json, contains('test_issue'));
    });

    test('stdout report uses scanned file count when provided', () {
      final report = ReportGenerator.generateStdout(
        projectPath: '/test',
        issues: const [],
        scannedFileCount: 3,
      );

      expect(report, contains('扫描文件: 3'));
      expect(report, contains('问题总数: '));
    });

    test('json summary includes suppression counters', () {
      final json = ReportGenerator.generateJson(
        projectPath: '/test',
        issues: const [],
        suppressedCount: 2,
        suppressedByBaselineCount: 3,
      );
      final decoded = jsonDecode(json) as Map<String, Object?>;
      final summary = decoded['summary'] as Map<String, Object?>;

      expect(summary['suppressed'], 2);
      expect(summary['suppressedByBaseline'], 3);
    });
  });

  group('Scanner Orchestration', () {
    test('scanner runs all configured rules and returns sorted result', () {
      final result = FlutterGuardScanner.scan(
        projectPath: Directory.current.path,
        configPath: p.join('test', 'fixtures', 'architecture_config.yaml'),
      );

      expect(result.files, isNotEmpty);
      expect(result.issues, isNotEmpty);
      expect(result.score, inInclusiveRange(0, 100));
      expect(result.issues.first.level, RiskLevel.high);
    });

    test('scanner reports missing project path as scan exception', () {
      expect(
        () => FlutterGuardScanner.scan(
          projectPath: p.join(fixturesPath, 'does_not_exist'),
        ),
        throwsA(isA<ScanException>()),
      );
    });

    test('config parser rejects invalid rule values', () {
      final file = File(p.join(fixturesPath, 'invalid_config.yaml'));
      file.writeAsStringSync('rules:\n  large_file: false\n');
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      expect(
        () => ScanConfig.fromFile(file.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('same-line suppression filters matching rule only', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_suppress_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      File(p.join(dir.path, 'lib', 'ignored.dart')).writeAsStringSync('''
class StatelessWidget {}
class IgnoredWidget extends StatelessWidget {} // flutterguard: ignore missing_const_constructor
''');
      File(p.join(dir.path, 'lib', 'visible.dart')).writeAsStringSync('''
class StatelessWidget {}
class VisibleWidget extends StatelessWidget {} // flutterguard: ignore large_file
''');

      final result = FlutterGuardScanner.scan(projectPath: dir.path);

      expect(result.rawIssues, hasLength(2));
      expect(result.issues, hasLength(1));
      expect(result.suppressedCount, 1);
      expect(result.issues.single.metadata['className'], 'VisibleWidget');
    });

    test('previous-line ignore all filters next line issues', () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_ignore_all_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      File(p.join(dir.path, 'lib', 'widget.dart')).writeAsStringSync('''
class StatelessWidget {}
// flutterguard: ignore all
class IgnoredWidget extends StatelessWidget {}
''');

      final result = FlutterGuardScanner.scan(projectPath: dir.path);

      expect(result.rawIssues, hasLength(1));
      expect(result.issues, isEmpty);
      expect(result.suppressedCount, 1);
    });

    test('baseline filters matching fingerprints and leaves new issues visible',
        () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_baseline_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      _writeWidgetIssue(p.join(dir.path, 'lib', 'old.dart'), 'OldWidget');

      final initial = FlutterGuardScanner.scan(
        projectPath: dir.path,
        applySuppression: false,
      );
      final baselinePath = p.join(dir.path, '.flutterguard', 'baseline.json');
      Directory(p.dirname(baselinePath)).createSync(recursive: true);
      File(baselinePath).writeAsStringSync(Baseline.encode(
        projectPath: initial.projectPath,
        issues: initial.rawIssues,
      ));

      _writeWidgetIssue(p.join(dir.path, 'lib', 'new.dart'), 'NewWidget');
      final result = FlutterGuardScanner.scan(
        projectPath: dir.path,
        baselinePath: '.flutterguard/baseline.json',
      );

      expect(result.rawIssues, hasLength(2));
      expect(result.suppressedByBaselineCount, 1);
      expect(result.issues, hasLength(1));
      expect(result.issues.single.file, endsWith('new.dart'));
    });

    test('missing baseline file fails the scan', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_no_base_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      _writeWidgetIssue(p.join(dir.path, 'lib', 'one.dart'), 'OneWidget');

      expect(
        () => FlutterGuardScanner.scan(
          projectPath: dir.path,
          baselinePath: '.flutterguard/missing.json',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('sarif report contains rules results severity and line fallback', () {
      final issues = [
        StaticIssue(
          id: 'iot_security',
          title: 'High',
          file: p.join('/repo', 'lib', 'a.dart'),
          line: 12,
          level: RiskLevel.high,
          domain: IssueDomain.standards,
          priority: Priority.p0,
          message: 'high issue',
          suggestion: 'fix',
        ),
        StaticIssue(
          id: 'ble_scanning',
          title: 'Medium',
          file: p.join('/repo', 'lib', 'b.dart'),
          level: RiskLevel.medium,
          domain: IssueDomain.performance,
          priority: Priority.p1,
          message: 'medium issue',
          suggestion: 'fix',
        ),
        StaticIssue(
          id: 'missing_const_constructor',
          title: 'Low',
          file: p.join('/repo', 'lib', 'c.dart'),
          line: 3,
          level: RiskLevel.low,
          domain: IssueDomain.standards,
          priority: Priority.p2,
          message: 'low issue',
          suggestion: 'fix',
        ),
      ];

      final decoded = jsonDecode(SarifReport.generate(
        projectPath: '/repo',
        issues: issues,
      )) as Map<String, Object?>;
      final runs = decoded['runs'] as List<Object?>;
      final run = runs.single as Map<String, Object?>;
      final results = run['results'] as List<Object?>;

      expect(decoded['version'], '2.1.0');
      expect(jsonEncode(run), contains('"rules"'));
      expect(results.map((r) => (r as Map)['level']), [
        'error',
        'warning',
        'note',
      ]);
      final second = results[1] as Map<String, Object?>;
      final locations = second['locations'] as List<Object?>;
      final physical = (locations.single as Map)['physicalLocation'] as Map;
      final region = physical['region'] as Map;
      expect(region['startLine'], 1);
      expect(jsonEncode(second), contains('lib/b.dart'));
    });
  });

  group('Changed-only mode', () {
    test('changed_only_filters_files', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_changed_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      final changedFile = p.join(dir.path, 'lib', 'changed.dart');
      final unchangedFile = p.join(dir.path, 'lib', 'unchanged.dart');
      _writeWidgetIssue(changedFile, 'ChangedWidget');
      _writeWidgetIssue(unchangedFile, 'UnchangedWidget');

      _runGit(dir, ['init', '-b', 'main']);
      _runGit(dir, ['config', 'user.email', 'test@example.com']);
      _runGit(dir, ['config', 'user.name', 'FlutterGuard Test']);
      _runGit(dir, ['add', '.']);
      _runGit(dir, ['commit', '-m', 'initial']);
      File(changedFile).writeAsStringSync('''
class StatelessWidget {}
class ChangedWidget extends StatelessWidget {}
class AnotherChangedWidget extends StatelessWidget {}
''');

      final result = FlutterGuardScanner.scan(
        projectPath: dir.path,
        changedOnly: true,
        base: 'main',
      );

      expect(result.scanMode, 'changed');
      expect(result.files, [changedFile]);
      expect(result.issues, isNotEmpty);
      expect(result.issues.every((i) => i.file == changedFile), isTrue);
    });

    test('changed_only_full_scan_when_no_git', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_no_git_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      _writeWidgetIssue(p.join(dir.path, 'lib', 'one.dart'), 'OneWidget');
      _writeWidgetIssue(p.join(dir.path, 'lib', 'two.dart'), 'TwoWidget');

      final result = FlutterGuardScanner.scan(
        projectPath: dir.path,
        changedOnly: true,
      );

      expect(result.scanMode, 'full');
      expect(result.files, hasLength(2));
      expect(result.issues, hasLength(2));
    });

    test('changed_only_skips_circular_dependency', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_cycle_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      File(p.join(dir.path, 'lib', 'a.dart')).writeAsStringSync(
        "import 'b.dart';\nclass A {}\n",
      );
      File(p.join(dir.path, 'lib', 'b.dart')).writeAsStringSync(
        "import 'c.dart';\nclass B {}\n",
      );
      File(p.join(dir.path, 'lib', 'c.dart')).writeAsStringSync(
        "import 'a.dart';\nclass C {}\n",
      );
      _runGit(dir, ['init', '-b', 'main']);

      final result = FlutterGuardScanner.scan(
        projectPath: dir.path,
        changedOnly: true,
        base: 'main',
      );

      expect(result.scanMode, 'changed');
      expect(result.files, hasLength(3));
      expect(
        result.issues.where((i) => i.id == 'circular_dependency'),
        isEmpty,
      );
    });
  });

  group('Rules Registry', () {
    test('registry_contains_all_13_rules', () {
      expect(RuleRegistry.all(), hasLength(13));
    });

    test('registry_find_returns_correct_meta', () {
      final meta = RuleRegistry.find('large_file');

      expect(meta, isNotNull);
      expect(meta!.id, 'large_file');
      expect(meta.domain, 'standards');
    });

    test('registry_find_unknown_returns_null', () {
      expect(RuleRegistry.find('nonexistent'), isNull);
    });
  });

  group('Config Tools', () {
    test('init template includes optional architecture block', () {
      final basic = ConfigTools.initTemplate(withArchitecture: false);
      final withArchitecture = ConfigTools.initTemplate(withArchitecture: true);

      expect(basic, contains('large_file:'));
      expect(basic, isNot(contains('architecture:')));
      expect(withArchitecture, contains('architecture:'));
      expect(withArchitecture, contains('mqtt_feature'));
    });

    test('effective config print includes merged defaults', () {
      final config = ScanConfig.fromFile(
        p.join(fixturesPath, 'does_not_exist.yaml'),
      );

      final yaml = ConfigTools.effectiveYaml(config);

      expect(yaml, contains('include:'));
      expect(yaml, contains('iot_security:'));
      expect(yaml, contains('maxScanDurationMs: 10000'));
      expect(yaml, contains('detect_cycles: false'));
    });

    test('doctor reports unknown architecture dependencies', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_doctor_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib', 'presentation'))
          .createSync(recursive: true);
      File(p.join(dir.path, 'lib', 'presentation', 'page.dart'))
          .writeAsStringSync('class Page {}\n');
      File(p.join(dir.path, 'flutterguard.yaml')).writeAsStringSync('''
include:
  - lib/**
architecture:
  layers:
    - name: presentation
      path: lib/presentation/**
      allowed_deps: [domain]
''');

      final result = ConfigTools.doctor(
        projectPath: dir.path,
        configPath: 'flutterguard.yaml',
      );

      expect(result.hasErrors, isTrue);
      expect(
        result.messages.any((message) =>
            message.severity == DoctorSeverity.error &&
            message.message.contains('unknown dependency "domain"')),
        isTrue,
      );
    });

    test('doctor warns when globs match no Dart files', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_empty_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: app\n');
      File(p.join(dir.path, 'flutterguard.yaml')).writeAsStringSync('''
include:
  - lib/**
''');

      final result = ConfigTools.doctor(
        projectPath: dir.path,
        configPath: 'flutterguard.yaml',
      );

      expect(result.hasErrors, isFalse);
      expect(
        result.messages.any((message) =>
            message.severity == DoctorSeverity.warning &&
            message.message.contains('No Dart files matched')),
        isTrue,
      );
    });

    test('config tools prefer project config for default config name', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_config_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: app\n');
      File(p.join(dir.path, 'flutterguard.yaml')).writeAsStringSync('''
include:
  - custom_lib/**
''');

      final resolved = ConfigTools.resolveConfigPathForProject(
        projectPath: dir.path,
        configPath: 'flutterguard.yaml',
      );

      expect(resolved, p.join(dir.path, 'flutterguard.yaml'));
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
