import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_cli/src/baseline.dart';
import 'package:flutterguard_cli/src/config_loader.dart';
import 'package:flutterguard_cli/src/config_tools.dart';
import 'package:flutterguard_cli/src/domain.dart';
import 'package:flutterguard_cli/src/import_utils.dart';
import 'package:flutterguard_cli/src/install_doctor.dart';
import 'package:flutterguard_cli/src/issue_export.dart';
import 'package:flutterguard_cli/src/path_utils.dart';
import 'package:flutterguard_cli/src/priority.dart';
import 'package:flutterguard_cli/src/report_generator.dart';
import 'package:flutterguard_cli/src/rules/circular_dependency.dart';
import 'package:flutterguard_cli/src/rules/large_units.dart';
import 'package:flutterguard_cli/src/rules/layer_violation.dart';
import 'package:flutterguard_cli/src/rules/ble_scanning.dart';
import 'package:flutterguard_cli/src/rules/bloc_state_management.dart';
import 'package:flutterguard_cli/src/rules/device_lifecycle.dart';
import 'package:flutterguard_cli/src/rules/generic_state_management.dart';
import 'package:flutterguard_cli/src/rules/iot_security.dart';
import 'package:flutterguard_cli/src/rules/lifecycle_resource.dart';
import 'package:flutterguard_cli/src/rules/missing_const_constructor.dart';
import 'package:flutterguard_cli/src/rules/module_violation.dart';
import 'package:flutterguard_cli/src/rules/mqtt_connection.dart';
import 'package:flutterguard_cli/src/rules/pubspec_security.dart';
import 'package:flutterguard_cli/src/rules/provider_state_management.dart';
import 'package:flutterguard_cli/src/rules/registry.dart';
import 'package:flutterguard_cli/src/rules/riverpod_state_management.dart';
import 'package:flutterguard_cli/src/rules/state_dependency_cycle.dart';
import 'package:flutterguard_cli/src/sarif_report.dart';
import 'package:flutterguard_cli/src/scanner.dart';
import 'package:flutterguard_cli/src/source_workspace.dart';
import 'package:flutterguard_cli/src/static_issue.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String get fixturesPath => p.join(Directory.current.path, 'test', 'fixtures');

const _stateRuleIds = {
  'side_effect_in_build',
  'state_manager_created_in_build',
  'mutable_state_exposed',
  'state_layer_ui_dependency',
  'state_dependency_cycle',
  'riverpod_read_used_for_render',
  'riverpod_watch_in_callback',
  'bloc_equatable_props_incomplete',
  'provider_value_lifecycle_misuse',
  'notify_listeners_in_loop',
};

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

StateManagementConfig _stateManagement({
  bool enabled = true,
  bool frameworkAutoDetect = true,
}) =>
    (
      enabled: enabled,
      frameworkAutoDetect: frameworkAutoDetect,
      confidenceThreshold: RuleConfidence.certain,
    );

StateRuleConfig _stateRule(
  RiskLevel severity, {
  bool enabled = true,
  List<String> allowlist = const [],
  List<String> ignorePaths = const [],
}) =>
    (
      enabled: enabled,
      severity: severity,
      allowlist: allowlist,
      ignorePaths: ignorePaths,
    );

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
      final decoded = jsonDecode(json) as Map<String, Object?>;
      final issue = (decoded['issues'] as List).single as Map;
      expect(issue['ruleId'], 'test_issue');
      expect(issue['severity'], 'medium');
      expect(issue['framework'], 'generic');
      expect(issue['confidence'], 'certain');
      expect(issue['evidence'], isEmpty);
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
        diagnostics: const [
          ScanDiagnostic(stage: 'read', message: 'unreadable'),
        ],
      );
      final decoded = jsonDecode(json) as Map<String, Object?>;
      final summary = decoded['summary'] as Map<String, Object?>;

      expect(summary['suppressed'], 2);
      expect(summary['suppressedByBaseline'], 3);
      expect(summary['diagnostics'], 1);
      expect(decoded['diagnostics'], hasLength(1));
    });
  });

  group('Scanner Orchestration', () {
    test('scanner allows built-in defaults when the default config is absent',
        () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_no_config_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync();
      File(p.join(dir.path, 'lib', 'plain.dart'))
          .writeAsStringSync('class Plain {}\n');

      final result = FlutterGuardScanner.scan(projectPath: dir.path);

      expect(result.files, [p.join(dir.path, 'lib', 'plain.dart')]);
    });

    test('scanner analyzes the project-root pubspec', () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_root_pubspec_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync();
      File(p.join(dir.path, 'lib', 'plain.dart'))
          .writeAsStringSync('class Plain {}\n');
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('''
name: root_pubspec_test
dependencies:
  mqtt_client: ^9.0.0
''');

      final result = FlutterGuardScanner.scan(projectPath: dir.path);

      expect(
        result.issues.where((issue) => issue.id == 'pubspec_security'),
        isNotEmpty,
      );
    });

    test('source workspace retains read failures as diagnostics', () {
      final workspace = SourceWorkspace();

      expect(workspace.source(p.join(fixturesPath, 'missing.dart')), isNull);
      expect(workspace.diagnostics, hasLength(1));
      expect(workspace.diagnostics.single.stage, 'read');
    });

    test('scanner rejects a missing custom config', () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_custom_config_');
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(
        () => FlutterGuardScanner.scan(
          projectPath: dir.path,
          configPath: 'policy/flutterguard.yaml',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('does not exist'),
          ),
        ),
      );
    });

    test('scanner rejects a missing explicitly selected default config', () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_required_config_');
      addTearDown(() => dir.deleteSync(recursive: true));

      expect(
        () => FlutterGuardScanner.scan(
          projectPath: dir.path,
          configPath: 'flutterguard.yaml',
        ),
        throwsA(isA<FormatException>()),
      );
    });

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

    test('config parser rejects a required file that is absent', () {
      expect(
        () => ScanConfig.fromFile(
          p.join(fixturesPath, 'does_not_exist.yaml'),
          requireFile: true,
        ),
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

    test('baseline stats prune and no-growth helpers work', () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_baseline_tools_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      _writeWidgetIssue(p.join(dir.path, 'lib', 'old.dart'), 'OldWidget');

      final initial = FlutterGuardScanner.scan(
        projectPath: dir.path,
        applySuppression: false,
      );
      final staleIssue = StaticIssue(
        id: 'missing_const_constructor',
        title: 'Stale',
        file: p.join(dir.path, 'lib', 'deleted.dart'),
        line: 2,
        level: RiskLevel.low,
        domain: IssueDomain.standards,
        priority: Priority.p2,
        message: 'stale issue',
        suggestion: 'fix',
      );
      final baselineJson = Baseline.encode(
        projectPath: initial.projectPath,
        issues: [...initial.rawIssues, staleIssue],
      );
      final baseline = Baseline.loadFromString(baselineJson);

      expect(baseline.fingerprints, hasLength(2));

      final pruned = Baseline.loadFromString(Baseline.prune(
        projectPath: initial.projectPath,
        baseline: baseline,
        issues: initial.rawIssues,
      ));
      expect(pruned.fingerprints, hasLength(1));

      _writeWidgetIssue(p.join(dir.path, 'lib', 'new.dart'), 'NewWidget');
      final current = FlutterGuardScanner.scan(
        projectPath: dir.path,
        applySuppression: false,
      );
      final newFingerprints = Baseline.newFingerprints(
        projectPath: current.projectPath,
        baseline: pruned,
        issues: current.rawIssues,
      );
      expect(newFingerprints, hasLength(1));
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
      final properties = second['properties'] as Map;
      expect(properties['framework'], 'generic');
      expect(properties['confidence'], 'certain');
      expect(properties['evidence'], isEmpty);
      final locations = second['locations'] as List<Object?>;
      final physical = (locations.single as Map)['physicalLocation'] as Map;
      final region = physical['region'] as Map;
      expect(region['startLine'], 1);
      expect(jsonEncode(second), contains('lib/b.dart'));
    });

    test('issue export includes rule metadata context and fingerprint', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_export_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      final file = p.join(dir.path, 'lib', 'widget.dart');
      _writeWidgetIssue(file, 'ExportedWidget');

      final result = FlutterGuardScanner.scan(
        projectPath: dir.path,
        applySuppression: false,
      );
      final exported = IssueExporter.export(
        projectPath: result.projectPath,
        issues: result.rawIssues,
        ruleId: 'missing_const_constructor',
        filePath: 'lib/widget.dart',
        line: 2,
      );
      final decoded = jsonDecode(exported) as Map<String, Object?>;

      expect(decoded['fingerprint'], isA<String>());
      expect(
          jsonEncode(decoded['rule']), contains('missing_const_constructor'));
      expect(jsonEncode(decoded['context']), contains('ExportedWidget'));
      expect(jsonEncode(decoded['issue']), contains('lib/widget.dart'));
    });
  });

  group('Changed-only mode', () {
    test('changed_only_filters_files', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_changed_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      final changedFile = p.join(dir.path, 'lib', 'changed 设备.dart');
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

    test('changed_only resolves imports to unchanged architecture targets', () {
      final dir = Directory.systemTemp.createTempSync(
        'flutterguard_changed_boundary_',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib', 'ui')).createSync(recursive: true);
      Directory(p.join(dir.path, 'lib', 'data')).createSync(recursive: true);
      File(p.join(dir.path, 'flutterguard.yaml')).writeAsStringSync('''
include:
  - lib/**
architecture:
  layers:
    - name: ui
      path: lib/ui/**
      allowed_deps: []
    - name: data
      path: lib/data/**
      allowed_deps: []
''');
      final source = p.join(dir.path, 'lib', 'ui', 'screen.dart');
      final target = p.join(dir.path, 'lib', 'data', 'repository.dart');
      File(source).writeAsStringSync(
        "import '../data/repository.dart';\nclass Screen {}\n",
      );
      File(target).writeAsStringSync('class Repository {}\n');
      _runGit(dir, ['init', '-b', 'main']);
      _runGit(dir, ['config', 'user.email', 'test@example.com']);
      _runGit(dir, ['config', 'user.name', 'FlutterGuard Test']);
      _runGit(dir, ['add', '.']);
      _runGit(dir, ['commit', '-m', 'initial']);
      File(source).writeAsStringSync(
        "import '../data/repository.dart';\nclass Screen {}\n// changed\n",
      );

      final result = FlutterGuardScanner.scan(
        projectPath: dir.path,
        changedOnly: true,
        base: 'main',
      );

      expect(result.files, [source]);
      expect(
        result.issues.where((issue) => issue.id == 'layer_violation'),
        hasLength(1),
      );
    });

    test('changed_only_full_scan_when_no_git', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_no_git_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      File(p.join(dir.path, 'lib', 'one.dart')).writeAsStringSync(
        "import 'two.dart';\nclass One {}\n",
      );
      File(p.join(dir.path, 'lib', 'two.dart')).writeAsStringSync(
        "import 'one.dart';\nclass Two {}\n",
      );

      final result = FlutterGuardScanner.scan(
        projectPath: dir.path,
        changedOnly: true,
      );

      expect(result.scanMode, 'full');
      expect(result.files, hasLength(2));
      expect(
        result.issues.where((issue) => issue.id == 'circular_dependency'),
        isNotEmpty,
      );
    });

    test('changed_only clean repository returns an empty changed scan', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_clean_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      File(p.join(dir.path, 'lib', 'clean.dart'))
          .writeAsStringSync('class Clean {}\n');
      _runGit(dir, ['init', '-b', 'main']);
      _runGit(dir, ['config', 'user.email', 'test@example.com']);
      _runGit(dir, ['config', 'user.name', 'FlutterGuard Test']);
      _runGit(dir, ['add', '.']);
      _runGit(dir, ['commit', '-m', 'initial']);

      final result = FlutterGuardScanner.scan(
        projectPath: dir.path,
        changedOnly: true,
        base: 'main',
      );

      expect(result.scanMode, 'changed');
      expect(result.files, isEmpty);
      expect(result.issues, isEmpty);
    });

    test('changed_only runs project rules when pubspec changes', () {
      final dir = Directory.systemTemp.createTempSync(
        'flutterguard_changed_pubspec_',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      File(p.join(dir.path, 'lib', 'clean.dart'))
          .writeAsStringSync('class Clean {}\n');
      final pubspec = File(p.join(dir.path, 'pubspec.yaml'))
        ..writeAsStringSync('name: changed_pubspec_test\n');
      _runGit(dir, ['init', '-b', 'main']);
      _runGit(dir, ['config', 'user.email', 'test@example.com']);
      _runGit(dir, ['config', 'user.name', 'FlutterGuard Test']);
      _runGit(dir, ['add', '.']);
      _runGit(dir, ['commit', '-m', 'initial']);
      pubspec.writeAsStringSync('''
name: changed_pubspec_test
dependencies:
  mqtt_client: ^9.0.0
''');

      final result = FlutterGuardScanner.scan(
        projectPath: dir.path,
        changedOnly: true,
        base: 'main',
      );

      expect(result.files, isEmpty);
      expect(
        result.issues.where((issue) => issue.id == 'pubspec_security'),
        isNotEmpty,
      );
    });

    test('changed_only rejects invalid or option-like base refs', () {
      final dir = Directory.systemTemp.createTempSync(
        'flutterguard_invalid_base_',
      );
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync(recursive: true);
      _writeMinimalProjectConfig(dir);
      File(p.join(dir.path, 'lib', 'tracked.dart'))
          .writeAsStringSync('class Tracked {}\n');
      _runGit(dir, ['init', '-b', 'main']);
      _runGit(dir, ['config', 'user.email', 'test@example.com']);
      _runGit(dir, ['config', 'user.name', 'FlutterGuard Test']);
      _runGit(dir, ['add', '.']);
      _runGit(dir, ['commit', '-m', 'initial']);

      expect(
        () => FlutterGuardScanner.scan(
          projectPath: dir.path,
          changedOnly: true,
          base: 'missing-ref',
        ),
        throwsA(
          isA<ScanException>().having(
            (error) => error.message,
            'message',
            contains('Invalid Git base'),
          ),
        ),
      );
      expect(
        () => FlutterGuardScanner.scan(
          projectPath: dir.path,
          changedOnly: true,
          base: '--cached',
        ),
        throwsA(
          isA<ScanException>().having(
            (error) => error.message,
            'message',
            contains('Invalid Git base'),
          ),
        ),
      );
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
      _runGit(dir, ['config', 'user.email', 'test@example.com']);
      _runGit(dir, ['config', 'user.name', 'FlutterGuard Test']);
      _runGit(dir, ['commit', '--allow-empty', '-m', 'initial']);

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

  group('State Management Rules', () {
    final genericFile = p.join(fixturesPath, 'generic_state.dart');
    final riverpodFile = p.join(fixturesPath, 'riverpod_state.dart');
    final blocFile = p.join(fixturesPath, 'bloc_state.dart');
    final providerFile = p.join(fixturesPath, 'provider_state.dart');

    test('detects build side effects and excludes callback/local collection',
        () {
      final issues = SideEffectInBuildRule(
        _stateRule(RiskLevel.high),
        _stateManagement(),
        projectPath: Directory.current.path,
      ).analyze([genericFile]);

      expect(issues, hasLength(2));
      expect(issues.every((issue) => issue.evidence.isNotEmpty), isTrue);
      expect(
        issues.expand((issue) => issue.evidence),
        isNot(contains(contains('values.add'))),
      );
    });

    test('detects state manager creation in build and excludes callbacks', () {
      final issues = StateManagerCreatedInBuildRule(
        _stateRule(RiskLevel.high),
        _stateManagement(),
        projectPath: Directory.current.path,
      ).analyze([genericFile]);

      expect(issues, hasLength(2));
      expect(
        issues.map((issue) => issue.metadata['type']),
        containsAll(['DeviceController', 'DeviceBloc']),
      );
    });

    test('detects exposed mutable state and excludes Flutter State/safe data',
        () {
      final issues = MutableStateExposedRule(
        _stateRule(RiskLevel.medium),
        _stateManagement(),
        projectPath: Directory.current.path,
      ).analyze([genericFile]);

      expect(issues.length, greaterThanOrEqualTo(4));
      expect(
        issues.any((issue) => issue.metadata['className'] == 'PageState'),
        isFalse,
      );
      expect(
        issues.any((issue) => issue.metadata['className'] == 'SafeState'),
        isFalse,
      );
    });

    test('detects state-layer UI dependencies once per owner', () {
      final issues = StateLayerUiDependencyRule(
        _stateRule(RiskLevel.high),
        _stateManagement(),
        projectPath: Directory.current.path,
      ).analyze([genericFile]);

      expect(
        issues.map((issue) => issue.metadata['className']),
        containsAll(['NavigationController', 'ThemeController']),
      );
      expect(
        issues.where(
          (issue) => issue.metadata['className'] == 'NavigationController',
        ),
        hasLength(1),
      );
    });

    test('detects deterministic state dependency cycle and edge allowlist', () {
      final issues = StateDependencyCycleRule(
        _stateRule(RiskLevel.high),
        _stateManagement(),
        projectPath: Directory.current.path,
      ).analyze([genericFile]);

      expect(issues, hasLength(1));
      expect(issues.single.message, contains('CycleController'));
      expect(issues.single.message, contains('CycleService'));

      final allowed = StateDependencyCycleRule(
        _stateRule(
          RiskLevel.high,
          allowlist: ['CycleService->CycleController'],
        ),
        _stateManagement(),
        projectPath: Directory.current.path,
      ).analyze([genericFile]);
      expect(allowed, isEmpty);
    });

    test(
        'detects Riverpod read render flow and excludes command/callback reads',
        () {
      final issues = RiverpodReadUsedForRenderRule(
        _stateRule(RiskLevel.medium),
        _stateManagement(frameworkAutoDetect: false),
        projectPath: Directory.current.path,
      ).analyze([riverpodFile]);

      expect(issues, hasLength(2));
      expect(
        issues.every(
          (issue) => issue.framework == StateManagementFramework.riverpod,
        ),
        isTrue,
      );
    });

    test('detects Riverpod watch in event callbacks only', () {
      final issues = RiverpodWatchInCallbackRule(
        _stateRule(RiskLevel.medium),
        _stateManagement(frameworkAutoDetect: false),
        projectPath: Directory.current.path,
      ).analyze([riverpodFile]);

      expect(issues, hasLength(2));
    });

    test('merges missing Equatable props per class', () {
      final issues = BlocEquatablePropsIncompleteRule(
        _stateRule(RiskLevel.medium),
        _stateManagement(frameworkAutoDetect: false),
        projectPath: Directory.current.path,
      ).analyze([blocFile]);

      expect(issues, hasLength(2));
      expect(
        issues.map((issue) => issue.metadata['className']),
        containsAll(['DeviceState', 'ReadingState']),
      );
    });

    test('detects Provider value/create ownership inversions', () {
      final issues = ProviderValueLifecycleMisuseRule(
        _stateRule(RiskLevel.medium),
        _stateManagement(frameworkAutoDetect: false),
        projectPath: Directory.current.path,
      ).analyze([providerFile]);

      expect(issues, hasLength(2));
      expect(
        issues.map((issue) => issue.metadata['ownershipError']),
        containsAll(['value_creates', 'create_reuses']),
      );
    });

    test(
        'detects notifyListeners in repeated loops and skips literal singleton',
        () {
      final issues = NotifyListenersInLoopRule(
        _stateRule(RiskLevel.medium),
        _stateManagement(frameworkAutoDetect: false),
        projectPath: Directory.current.path,
      ).analyze([providerFile]);

      expect(issues, hasLength(2));
    });

    test('global and per-rule switches disable state rules', () {
      final globalOff = SideEffectInBuildRule(
        _stateRule(RiskLevel.high),
        _stateManagement(enabled: false),
        projectPath: Directory.current.path,
      ).analyze([genericFile]);
      final ruleOff = SideEffectInBuildRule(
        _stateRule(RiskLevel.high, enabled: false),
        _stateManagement(),
        projectPath: Directory.current.path,
      ).analyze([genericFile]);

      expect(globalOff, isEmpty);
      expect(ruleOff, isEmpty);
    });

    test('framework auto-detection can be disabled without weakening AST shape',
        () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_framework_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File(p.join(dir.path, 'view.dart'))..writeAsStringSync('''
class View {
  Object build(Object context, dynamic ref) {
    return Text(ref.read(deviceProvider));
  }
}
''');
      final imported = File(p.join(dir.path, 'imported_view.dart'))
        ..writeAsStringSync('''
import 'package:flutter_riverpod/flutter_riverpod.dart';
class ImportedView {
  Object build(Object context, dynamic ref) {
    return Text(ref.read(deviceProvider));
  }
}
''');

      final detected = RiverpodReadUsedForRenderRule(
        _stateRule(RiskLevel.medium),
        _stateManagement(),
        projectPath: dir.path,
      ).analyze([file.path]);
      final forced = RiverpodReadUsedForRenderRule(
        _stateRule(RiskLevel.medium),
        _stateManagement(frameworkAutoDetect: false),
        projectPath: dir.path,
      ).analyze([file.path]);
      final autoDetected = RiverpodReadUsedForRenderRule(
        _stateRule(RiskLevel.medium),
        _stateManagement(),
        projectPath: dir.path,
      ).analyze([imported.path]);

      expect(detected, isEmpty);
      expect(forced, hasLength(1));
      expect(autoDetected, hasLength(1));
    });

    test('severity override updates priority and JSON compatibility aliases',
        () {
      final issue = SideEffectInBuildRule(
        _stateRule(RiskLevel.low),
        _stateManagement(),
        projectPath: Directory.current.path,
      ).analyze([genericFile]).first;
      final json = issue.toJson();

      expect(issue.level, RiskLevel.low);
      expect(issue.priority, Priority.p2);
      expect(json['ruleId'], issue.id);
      expect(json['severity'], 'low');
      expect(json['framework'], 'generic');
      expect(json['confidence'], 'certain');
    });

    test('config validates new enums/types and prints complete defaults', () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_state_cfg_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final valid = File(p.join(dir.path, 'valid.yaml'))..writeAsStringSync('''
state_management:
  enabled: true
  framework_auto_detect: false
  confidence_threshold: probable
rules:
  side_effect_in_build:
    severity: low
    allowlist: [refresh]
    ignore_paths: [lib/generated/**]
''');
      final config = ScanConfig.fromFile(valid.path);
      expect(config.stateManagement.frameworkAutoDetect, isFalse);
      expect(
          config.stateManagement.confidenceThreshold, RuleConfidence.probable);
      expect(config.rules.sideEffectInBuild.severity, RiskLevel.low);
      expect(ConfigTools.effectiveYaml(config), contains('state_management:'));

      for (final invalidBody in const [
        'state_management:\n  confidence_threshold: maybe\n',
        'rules:\n  side_effect_in_build:\n    severity: critical\n',
        'rules:\n  side_effect_in_build:\n    allowlist: value\n',
      ]) {
        final invalid = File(p.join(dir.path, 'invalid.yaml'))
          ..writeAsStringSync(invalidBody);
        expect(() => ScanConfig.fromFile(invalid.path), throwsFormatException);
      }
    });

    test('state findings reuse line suppression and keep raw issues', () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_state_suppress_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync();
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: app\n');
      File(p.join(dir.path, 'flutterguard.yaml')).writeAsStringSync('''
include: [lib/**]
state_management:
  framework_auto_detect: false
''');
      File(p.join(dir.path, 'lib', 'view.dart')).writeAsStringSync('''
class View {
  // flutterguard: ignore side_effect_in_build
  Object build(Object context) {
    notifyListeners();
    return Object();
  }
}
''');

      final result = FlutterGuardScanner.scan(projectPath: dir.path);
      expect(
        result.rawIssues.where((issue) => issue.id == 'side_effect_in_build'),
        hasLength(1),
      );
      expect(
        result.issues.where((issue) => issue.id == 'side_effect_in_build'),
        isEmpty,
      );
      expect(result.suppressedCount, greaterThanOrEqualTo(1));
    });

    test('changed mode builds the full state graph and anchors to target file',
        () {
      final target = p.join(fixturesPath, 'generic_state.dart');
      final issues = StateDependencyCycleRule(
        _stateRule(RiskLevel.high),
        _stateManagement(),
        projectPath: Directory.current.path,
      ).analyze(
        [target],
        targetFiles: [target],
        changedOnly: true,
      );

      expect(issues, hasLength(1));
      expect(issues.single.file, target);
    });

    test('every state rule honors its independent enabled switch', () {
      final highOff = _stateRule(RiskLevel.high, enabled: false);
      final mediumOff = _stateRule(RiskLevel.medium, enabled: false);
      final analyzers = <String, List<StaticIssue> Function()>{
        'side_effect_in_build': () => SideEffectInBuildRule(
              highOff,
              _stateManagement(),
              projectPath: Directory.current.path,
            ).analyze([genericFile]),
        'state_manager_created_in_build': () => StateManagerCreatedInBuildRule(
              highOff,
              _stateManagement(),
              projectPath: Directory.current.path,
            ).analyze([genericFile]),
        'mutable_state_exposed': () => MutableStateExposedRule(
              mediumOff,
              _stateManagement(),
              projectPath: Directory.current.path,
            ).analyze([genericFile]),
        'state_layer_ui_dependency': () => StateLayerUiDependencyRule(
              highOff,
              _stateManagement(),
              projectPath: Directory.current.path,
            ).analyze([genericFile]),
        'state_dependency_cycle': () => StateDependencyCycleRule(
              highOff,
              _stateManagement(),
              projectPath: Directory.current.path,
            ).analyze([genericFile]),
        'riverpod_read_used_for_render': () => RiverpodReadUsedForRenderRule(
              mediumOff,
              _stateManagement(),
              projectPath: Directory.current.path,
            ).analyze([riverpodFile]),
        'riverpod_watch_in_callback': () => RiverpodWatchInCallbackRule(
              mediumOff,
              _stateManagement(),
              projectPath: Directory.current.path,
            ).analyze([riverpodFile]),
        'bloc_equatable_props_incomplete': () =>
            BlocEquatablePropsIncompleteRule(
              mediumOff,
              _stateManagement(),
              projectPath: Directory.current.path,
            ).analyze([blocFile]),
        'provider_value_lifecycle_misuse': () =>
            ProviderValueLifecycleMisuseRule(
              mediumOff,
              _stateManagement(),
              projectPath: Directory.current.path,
            ).analyze([providerFile]),
        'notify_listeners_in_loop': () => NotifyListenersInLoopRule(
              mediumOff,
              _stateManagement(),
              projectPath: Directory.current.path,
            ).analyze([providerFile]),
      };

      expect(analyzers.keys.toSet(), _stateRuleIds);
      for (final entry in analyzers.entries) {
        expect(entry.value(), isEmpty, reason: entry.key);
      }
    });

    test('all state rules reuse suppression and baseline pipelines', () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_state_all_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync();
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: app\n');
      File(p.join(dir.path, 'flutterguard.yaml')).writeAsStringSync('''
include: [lib/**]
state_management:
  framework_auto_detect: false
''');
      File(p.join(dir.path, 'lib', 'state_suppression.dart')).writeAsStringSync(
        File(p.join(fixturesPath, 'state_suppression.dart')).readAsStringSync(),
      );

      final suppressed = FlutterGuardScanner.scan(projectPath: dir.path);
      final rawStateIds = suppressed.rawIssues
          .where((issue) => _stateRuleIds.contains(issue.id))
          .map((issue) => issue.id)
          .toSet();
      final visibleStateIds = suppressed.issues
          .where((issue) => _stateRuleIds.contains(issue.id))
          .map((issue) => issue.id)
          .toSet();
      expect(rawStateIds, _stateRuleIds);
      expect(visibleStateIds, isEmpty);

      final unsuppressed = FlutterGuardScanner.scan(
        projectPath: dir.path,
        applySuppression: false,
      );
      final baselinePath = p.join(dir.path, 'baseline.json');
      File(baselinePath).writeAsStringSync(Baseline.encode(
        projectPath: unsuppressed.projectPath,
        issues: unsuppressed.rawIssues,
      ));
      final baselined = FlutterGuardScanner.scan(
        projectPath: dir.path,
        applySuppression: false,
        baselinePath: baselinePath,
      );
      expect(
        baselined.issues.where((issue) => _stateRuleIds.contains(issue.id)),
        isEmpty,
      );
      expect(
        baselined.suppressedByBaselineCount,
        unsuppressed.rawIssues.length,
      );
    });

    test('duplicate type names do not create a false state cycle', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_names_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final a = Directory(p.join(dir.path, 'a'))..createSync();
      final b = Directory(p.join(dir.path, 'b'))..createSync();
      final controller = File(p.join(a.path, 'controller.dart'))
        ..writeAsStringSync('''
import 'service.dart';
class DeviceController { final DuplicateService service; }
''');
      final serviceA = File(p.join(a.path, 'service.dart'))
        ..writeAsStringSync('class DuplicateService {}\n');
      final serviceB = File(p.join(b.path, 'service.dart'))
        ..writeAsStringSync('''
import '../a/controller.dart';
class DuplicateService { final DeviceController controller; }
''');

      final issues = StateDependencyCycleRule(
        _stateRule(RiskLevel.high),
        _stateManagement(),
        projectPath: dir.path,
      ).analyze([controller.path, serviceA.path, serviceB.path]);

      expect(issues, isEmpty);
    });

    test('real cycles disambiguate duplicate type names in evidence', () {
      final dir = Directory.systemTemp.createTempSync('flutterguard_names_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final a = Directory(p.join(dir.path, 'a'))..createSync();
      final b = Directory(p.join(dir.path, 'b'))..createSync();
      final controller = File(p.join(a.path, 'controller.dart'))
        ..writeAsStringSync('''
import 'service.dart';
class DeviceController { final DuplicateService service; }
''');
      final serviceA = File(p.join(a.path, 'service.dart'))
        ..writeAsStringSync('''
import 'controller.dart';
class DuplicateService { final DeviceController controller; }
''');
      final serviceB = File(p.join(b.path, 'service.dart'))
        ..writeAsStringSync('class DuplicateService {}\n');

      final issues = StateDependencyCycleRule(
        _stateRule(RiskLevel.high),
        _stateManagement(),
        projectPath: dir.path,
      ).analyze([controller.path, serviceA.path, serviceB.path]);

      expect(issues, hasLength(1));
      expect(
          issues.single.message, contains('a/service.dart::DuplicateService'));
    });

    test('scanner changed-only uses unchanged files in the state graph', () {
      final dir =
          Directory.systemTemp.createTempSync('flutterguard_changed_state_');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory(p.join(dir.path, 'lib')).createSync();
      File(p.join(dir.path, 'flutterguard.yaml')).writeAsStringSync('''
include: [lib/**]
''');
      File(p.join(dir.path, 'lib', 'controller.dart')).writeAsStringSync('''
import 'service.dart';
class DeviceController { final DeviceService service; }
''');
      final service = File(p.join(dir.path, 'lib', 'service.dart'))
        ..writeAsStringSync('''
import 'controller.dart';
class DeviceService { final DeviceController controller; }
''');
      _runGit(dir, ['init', '-b', 'main']);
      _runGit(dir, ['config', 'user.email', 'test@example.com']);
      _runGit(dir, ['config', 'user.name', 'FlutterGuard Test']);
      _runGit(dir, ['add', '.']);
      _runGit(dir, ['commit', '-m', 'initial']);
      service.writeAsStringSync('${service.readAsStringSync()}\n// changed\n');

      final result = FlutterGuardScanner.scan(
        projectPath: dir.path,
        changedOnly: true,
        base: 'HEAD',
      );
      final cycles = result.issues
          .where((issue) => issue.id == 'state_dependency_cycle')
          .toList();

      expect(result.files, [service.path]);
      expect(cycles, hasLength(1));
      expect(cycles.single.file, service.path);
    });
  });

  group('Rules Registry', () {
    test('registry_contains_all_23_rules', () {
      expect(RuleRegistry.all(), hasLength(23));
      for (final id in const [
        'side_effect_in_build',
        'state_manager_created_in_build',
        'mutable_state_exposed',
        'state_layer_ui_dependency',
        'state_dependency_cycle',
        'riverpod_read_used_for_render',
        'riverpod_watch_in_callback',
        'bloc_equatable_props_incomplete',
        'provider_value_lifecycle_misuse',
        'notify_listeners_in_loop',
      ]) {
        expect(RuleRegistry.find(id), isNotNull, reason: id);
      }
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

    test('init template profiles tune rule defaults', () {
      final migration = ConfigTools.initTemplate(
        withArchitecture: false,
        profile: 'migration',
      );
      final security = ConfigTools.initTemplate(
        withArchitecture: false,
        profile: 'iot-security',
      );

      expect(migration, contains('maxLines: 800'));
      expect(migration, contains('missing_const_constructor:'));
      expect(migration, contains('enabled: false'));
      expect(security, contains('iot_security:'));
      expect(security, contains('requireTls: true'));
      expect(
        () => ConfigTools.initTemplate(
          withArchitecture: false,
          profile: 'unknown',
        ),
        throwsA(isA<FormatException>()),
      );

      final dir = Directory.systemTemp.createTempSync('flutterguard_profiles_');
      addTearDown(() => dir.deleteSync(recursive: true));
      for (final profile in ConfigTools.profiles) {
        final file = File(p.join(dir.path, '$profile.yaml'))
          ..writeAsStringSync(ConfigTools.initTemplate(
            withArchitecture: false,
            profile: profile,
          ));
        final parsed = ScanConfig.fromFile(file.path);
        expect(parsed.rules.sideEffectInBuild.severity, RiskLevel.high);
      }
      final performance = ScanConfig.fromFile(
        p.join(dir.path, 'performance-only.yaml'),
      );
      expect(performance.rules.sideEffectInBuild.enabled, isTrue);
      expect(performance.rules.mutableStateExposed.enabled, isFalse);
      final architecture = ScanConfig.fromFile(
        p.join(dir.path, 'architecture-only.yaml'),
      );
      expect(architecture.rules.sideEffectInBuild.enabled, isFalse);
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

    test('doctor rejects configs that match no Dart files', () {
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

      expect(result.hasErrors, isTrue);
      expect(
        result.messages.any((message) =>
            message.severity == DoctorSeverity.error &&
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

    test('install doctor reports version and path checks', () {
      final report = InstallDoctor.generate(version: '0.4.0-test');

      expect(report, contains('FlutterGuard install doctor'));
      expect(report, contains('0.4.0-test'));
      expect(report, contains('PATH entries named flutterguard'));
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
