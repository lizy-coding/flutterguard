import 'dart:io';

import 'package:flutterguard_cli/src/config_loader.dart';
import 'package:flutterguard_cli/src/import_graph.dart';
import 'package:flutterguard_cli/src/rules/ble_scanning.dart';
import 'package:flutterguard_cli/src/rules/bloc_state_management.dart';
import 'package:flutterguard_cli/src/rules/boundary_rule.dart';
import 'package:flutterguard_cli/src/rules/circular_dependency.dart';
import 'package:flutterguard_cli/src/rules/generic_state_management.dart';
import 'package:flutterguard_cli/src/rules/iot_security.dart';
import 'package:flutterguard_cli/src/rules/lifecycle_resource.dart';
import 'package:flutterguard_cli/src/rules/provider_state_management.dart';
import 'package:flutterguard_cli/src/rules/riverpod_state_management.dart';
import 'package:flutterguard_cli/src/rules/state_dependency_cycle.dart';
import 'package:flutterguard_cli/src/source_workspace.dart';
import 'package:flutterguard_cli/src/static_issue.dart';
import 'package:flutterguard_cli/src/suppression.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String get _fixtures => p.join(Directory.current.path, 'test', 'fixtures');

RuleConfig _config(
  RiskLevel severity, {
  Map<String, Object?> options = const {},
}) => RuleConfig(enabled: true, severity: severity, options: options);

RuleConfig get _disabled =>
    const RuleConfig(enabled: false, severity: RiskLevel.low);

void main() {
  group('IoT and lifecycle rules', () {
    test('resource lifecycle finds undisposed fields', () {
      final issues = LifecycleResourceRule(
        _config(RiskLevel.medium),
      ).analyze([p.join(_fixtures, 'lifecycle_issue.dart')]);
      expect(issues, hasLength(3));
      expect(
        issues.every((issue) => issue.id == 'lifecycle_resource_not_disposed'),
        isTrue,
      );
      expect(
        issues.any(
          (issue) =>
              (issue.metadata['resourceType'] as String) == 'OverlayEntry',
        ),
        isTrue,
      );
    });

    test('resource lifecycle negative: properly disposed resources', () {
      final issues = LifecycleResourceRule(
        _config(RiskLevel.medium),
      ).analyze([p.join(_fixtures, 'lifecycle_negative.dart')]);
      expect(issues, isEmpty);
    });

    test('resource lifecycle disabled produces no findings', () {
      final issues = LifecycleResourceRule(
        _disabled,
      ).analyze([p.join(_fixtures, 'lifecycle_issue.dart')]);
      expect(issues, isEmpty);
    });

    test('BLE rule only owns scan timeout', () {
      final issues = BleScanningRule(
        _config(RiskLevel.medium),
      ).analyze([p.join(_fixtures, 'ble_scanning_issue.dart')]);
      expect(issues, hasLength(1));
      expect(issues.single.metadata['check'], 'scan_without_timeout');
    });

    test('BLE rule negative: startScan with timeout parameter', () {
      final issues = BleScanningRule(
        _config(RiskLevel.medium),
      ).analyze([p.join(_fixtures, 'ble_scanning_negative.dart')]);
      expect(issues, isEmpty);
    });

    test('BLE rule disabled produces no findings', () {
      final issues = BleScanningRule(
        _disabled,
      ).analyze([p.join(_fixtures, 'ble_scanning_issue.dart')]);
      expect(issues, isEmpty);
    });

    test('BLE rule suppression filters findings', () {
      final file = p.join(_fixtures, 'ble_scanning_suppression.dart');
      final rawIssues = BleScanningRule(
        _config(RiskLevel.medium),
      ).analyze([file]);
      expect(rawIssues, isNotEmpty);
      final filter = SuppressionFilter([file]);
      final visible = rawIssues.where((i) => !filter.isSuppressed(i)).toList();
      expect(visible, isEmpty);
    });

    test('IoT security detects transport and credential risks', () {
      final issues = IotSecurityRule(
        _config(RiskLevel.high, options: {'requireTls': true}),
      ).analyze([p.join(_fixtures, 'iot_security_issue.dart')]);
      expect(issues.length, greaterThanOrEqualTo(3));
      expect(issues.every((issue) => issue.level == RiskLevel.high), isTrue);
    });

    test('IoT security negative: safe code with proper protocols', () {
      final issues = IotSecurityRule(
        _config(RiskLevel.high, options: {'requireTls': true}),
      ).analyze([p.join(_fixtures, 'iot_security_negative.dart')]);
      expect(issues, isEmpty);
    });

    test('IoT security disabled produces no findings', () {
      final issues = IotSecurityRule(
        _disabled,
      ).analyze([p.join(_fixtures, 'iot_security_issue.dart')]);
      expect(issues, isEmpty);
    });

    test('IoT security requireTls disabled skips transport checks', () {
      final issues = IotSecurityRule(
        _config(RiskLevel.high, options: {'requireTls': false}),
      ).analyze([p.join(_fixtures, 'iot_security_issue.dart')]);
      final checks = issues.map((i) => i.metadata['securityCheck']).toSet();
      expect(checks, isNot(contains('cleartext_mqtt')));
      expect(checks, isNot(contains('cleartext_http')));
    });

    test('IoT security suppression filters findings', () {
      final file = p.join(_fixtures, 'iot_security_suppression.dart');
      final rawIssues = IotSecurityRule(
        _config(RiskLevel.high, options: {'requireTls': true}),
      ).analyze([file]);
      expect(rawIssues, isNotEmpty);
      final filter = SuppressionFilter([file]);
      final visible = rawIssues.where((i) => !filter.isSuppressed(i)).toList();
      expect(visible, isEmpty);
    });

    test('IoT security report contract: JSON output fields', () {
      final issues = IotSecurityRule(
        _config(RiskLevel.high, options: {'requireTls': true}),
      ).analyze([p.join(_fixtures, 'iot_security_issue.dart')]);
      for (final issue in issues) {
        final json = issue.toJson();
        expect(json['ruleId'], 'iot_security');
        expect(json, contains('severity'));
        expect(json, contains('domain'));
        expect(json, contains('message'));
        expect(json, contains('suggestion'));
        expect(json, isNot(contains('id')));
      }
    });
  });

  group('Architecture rules', () {
    test('one boundary engine serves layer and module rules', () {
      final files = [
        p.join(_fixtures, 'boundary_issue.dart'),
        p.join(_fixtures, 'forbidden_file.dart'),
      ];
      final workspace = SourceWorkspace();
      final graph = ImportGraph.build(
        files: files,
        sourceFiles: files,
        workspace: workspace,
        projectPath: Directory.current.path,
      );
      final boundaries = <BoundaryConfig>[
        (name: 'ui', path: '**/boundary_issue.dart', allowedDeps: const []),
        (name: 'model', path: '**/forbidden_file.dart', allowedDeps: const []),
      ];
      for (final kind in BoundaryKind.values) {
        final issues =
            BoundaryRule(
              kind: kind,
              boundaries: boundaries,
              severity: RiskLevel.high,
              projectPath: Directory.current.path,
            ).analyze(
              files,
              allFiles: files,
              workspace: workspace,
              importGraph: graph,
            );
        expect(issues, hasLength(1));
        expect(issues.single.id, '${kind.name}_violation');
      }
    });

    test('circular dependency uses the shared import graph', () {
      final files = [
        p.join(_fixtures, 'cycle_a.dart'),
        p.join(_fixtures, 'cycle_b.dart'),
        p.join(_fixtures, 'cycle_c.dart'),
      ];
      final issues = CircularDependencyRule(
        projectPath: Directory.current.path,
      ).analyze(files);
      expect(issues, isNotEmpty);
      expect(issues.first.id, 'circular_dependency');
    });
  });

  group('State architecture rules', () {
    test('generic state rules detect build and mutable-state problems', () {
      final file = p.join(_fixtures, 'generic_state.dart');
      final scans = <List<StaticIssue> Function()>[
        () => SideEffectInBuildRule(_config(RiskLevel.high)).analyze([file]),
        () => StateManagerCreatedInBuildRule(
          _config(RiskLevel.high),
        ).analyze([file]),
        () =>
            MutableStateExposedRule(_config(RiskLevel.medium)).analyze([file]),
        () =>
            StateLayerUiDependencyRule(_config(RiskLevel.high)).analyze([file]),
      ];
      for (final scan in scans) {
        expect(scan(), isNotEmpty);
      }
    });

    test('framework-specific rules are activated by imports', () {
      final riverpod = RiverpodReadUsedForRenderRule(
        _config(RiskLevel.medium),
      ).analyze([p.join(_fixtures, 'riverpod_state.dart')]);
      final bloc = BlocEquatablePropsIncompleteRule(
        _config(RiskLevel.medium),
      ).analyze([p.join(_fixtures, 'bloc_state.dart')]);
      final provider = ProviderValueLifecycleMisuseRule(
        _config(RiskLevel.medium),
      ).analyze([p.join(_fixtures, 'provider_state.dart')]);
      expect(riverpod, isNotEmpty);
      expect(bloc, isNotEmpty);
      expect(provider, isNotEmpty);
    });

    test('state dependency cycles remain project-wide', () {
      final issues = StateDependencyCycleRule(
        _config(RiskLevel.high),
        projectPath: Directory.current.path,
      ).analyze([p.join(_fixtures, 'generic_state.dart')]);
      expect(issues, isNotEmpty);
      expect(issues.first.id, 'state_dependency_cycle');
    });
  });
}
