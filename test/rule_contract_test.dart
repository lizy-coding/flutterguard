import 'dart:convert';
import 'dart:io';

import 'package:boundarylens_cli/src/config_loader.dart';
import 'package:boundarylens_cli/src/config_tools.dart';
import 'package:boundarylens_cli/src/scan_context.dart';
import 'package:boundarylens_cli/src/scanner.dart';
import 'package:boundarylens_cli/src/source_workspace.dart';
import 'package:boundarylens_cli/src/report_generator.dart';
import 'package:boundarylens_cli/src/static_issue.dart';
import 'package:boundarylens_cli/src/rules/registry.dart';
import 'package:boundarylens_cli/src/rules/rule.dart';
import 'package:boundarylens_cli/src/rules/rule_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;
  late String mainFile;
  setUp(() {
    project = Directory.systemTemp.createTempSync('boundarylens_contract_');
    Directory(p.join(project.path, 'lib')).createSync();
    File(
      p.join(project.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: contract_fixture\n');
    mainFile = p.join(project.path, 'lib/main.dart');
    File(mainFile).writeAsStringSync('class Example {}');
  });
  tearDown(() => project.deleteSync(recursive: true));
  ScanContext context({
    RuleScope scope = RuleScope.project,
    ScanConfig? config,
  }) => ScanContext(
    projectPath: project.path,
    config: config ?? ScanConfig.defaults(),
    allFiles: [mainFile],
    targetFiles: [mainFile],
    mode: scope == RuleScope.changed ? ScanMode.changed : ScanMode.full,
    sources: SourceWorkspace(),
    scope: scope,
  );
  RuleDefinition definition({
    String id = 'test_rule',
    bool enabled = true,
    Set<RuleInput> inputs = const {RuleInput.targetSyntax},
    Set<RuleScope> scopes = const {
      RuleScope.file,
      RuleScope.changed,
      RuleScope.project,
    },
  }) => RuleDefinition(
    id: id,
    name: 'Test-only rule',
    domain: IssueDomain.architecture,
    defaultSeverity: RiskLevel.medium,
    defaultEnabled: enabled,
    purpose: 'fixture',
    riskReason: 'fixture',
    badExample: 'fixture',
    fixSuggestion: 'fixture',
    inputs: inputs,
    scopes: scopes,
  );

  test(
    'ephemeral internal rule uses existing facts and normal report contract',
    () {
      final c = context();
      final result = RuleRunner.run(c, [
        RuleRegistration(
          definition: definition(),
          execute: (ctx, config, graph) {
            expect(ctx.sources.source(mainFile), isNotNull);
            return [
              StaticIssue(
                id: 'test_rule',
                title: 'Fixture',
                file: mainFile,
                line: 1,
                level: config.severity,
                domain: IssueDomain.architecture,
                message: 'Fixture',
                suggestion: 'Fix',
              ),
            ];
          },
        ),
      ]);
      expect(
        result.issues.single.toJson(),
        containsPair('ruleId', 'test_rule'),
      );
      final payload =
          jsonDecode(
                ReportGenerator.generateJson(
                  projectPath: project.path,
                  issues: result.issues,
                  scanMode: 'full',
                  coverage: {'rules': result.coverage},
                ),
              )
              as Map;
      expect(
        (payload['issues'] as List).single,
        containsPair('ruleId', 'test_rule'),
      );
      expect(result.coverage['test_rule']!['status'], 'complete');
      expect(RuleRegistry.find('test_rule'), isNull);
      expect(RuleRegistry.all(), hasLength(16));
    },
  );
  test('disabled rule is not invoked and no input is read', () {
    File(mainFile).writeAsStringSync('not valid Dart {{{');
    final c = context();
    final result = RuleRunner.run(c, [
      RuleRegistration(
        definition: definition(enabled: false),
        execute: (_, _, _) => throw StateError('must not run'),
      ),
    ]);
    expect(result.coverage['test_rule']!['status'], 'disabled');
    expect(c.sources.diagnostics, isEmpty);
  });
  test(
    'graph preparation follows declared input without architecture configuration',
    () {
      File(
        p.join(project.path, 'lib/other.dart'),
      ).writeAsStringSync('class Other {}');
      File(mainFile).writeAsStringSync("import 'other.dart';");
      final c = ScanContext(
        projectPath: project.path,
        config: ScanConfig.defaults(),
        allFiles: [mainFile, p.join(project.path, 'lib/other.dart')],
        targetFiles: [mainFile],
        mode: ScanMode.full,
        sources: SourceWorkspace(),
      );
      final result = RuleRunner.run(c, [
        RuleRegistration(
          definition: definition(inputs: {RuleInput.importGraph}),
          execute: (_, _, graph) {
            expect(graph, isNotNull);
            expect(graph!.outgoing(mainFile), hasLength(1));
            return [];
          },
        ),
      ]);
      expect(result.coverage['test_rule']!['status'], 'complete');
    },
  );
  test('unavailable syntax and unsupported scope never report complete', () {
    File(mainFile).deleteSync();
    final result = RuleRunner.run(context(), [
      RuleRegistration(
        definition: definition(),
        execute: (_, _, _) => throw StateError('missing input'),
      ),
    ]);
    expect(result.coverage['test_rule']!['status'], 'partial');
    final unsupported = RuleRunner.run(context(scope: RuleScope.changed), [
      RuleRegistration(
        definition: definition(scopes: {RuleScope.project}),
        execute: (_, _, _) => throw StateError('unsupported'),
      ),
    ]);
    expect(unsupported.coverage['test_rule']!['status'], 'unsupported_scope');
  });
  test(
    'duplicate identities and inconsistent option defaults fail registration',
    () {
      final registration = RuleRegistration(
        definition: definition(),
        execute: (_, _, _) => [],
      );
      expect(
        () => RuleRunner.run(context(), [registration, registration]),
        throwsStateError,
      );
      final d = RuleDefinition(
        id: 'bad_schema',
        name: 'Bad',
        domain: IssueDomain.architecture,
        defaultSeverity: RiskLevel.low,
        purpose: '',
        riskReason: '',
        badExample: '',
        fixSuggestion: '',
        defaultOptions: {'flag': true},
      );
      expect(
        () => RuleRunner.run(context(), [
          RuleRegistration(definition: d, execute: (_, _, _) => []),
        ]),
        throwsStateError,
      );
    },
  );
  test(
    'invalid typed parameter is rejected before scan for every source shape',
    () {
      File(p.join(project.path, 'boundarylens.yaml')).writeAsStringSync(
        'rules:\n  iot_security:\n    enabled: true\n    requireTls: invalid\n',
      );
      expect(ConfigTools.doctor(projectPath: project.path).hasErrors, isTrue);
      for (final text in [
        'class Example {}',
        "void f() { final url = 'https://example.invalid'; }",
      ]) {
        File(mainFile).writeAsStringSync(text);
        expect(
          () => BoundaryLensScanner.scan(
            projectPath: project.path,
            writeStdout: true,
            writeJson: true,
          ),
          throwsFormatException,
        );
      }
    },
  );
  test('per-rule execution status is additive in structured output', () {
    final r = BoundaryLensScanner.scan(
      projectPath: project.path,
      writeStdout: true,
      writeJson: true,
    );
    final payload = jsonDecode(r.structuredOutput!) as Map;
    final coverage = payload['coverage'] as Map;
    expect(coverage, contains('moduleBoundary'));
    expect(
      (coverage['rules'] as Map)['module_violation'],
      containsPair('status', 'not_configured'),
    );
    expect(
      (coverage['rules'] as Map)['iot_security'],
      containsPair('status', 'disabled'),
    );
  });
  test('rule cannot emit findings under another identity', () {
    expect(
      () => RuleRunner.run(context(), [
        RuleRegistration(
          definition: definition(),
          execute: (ctx, config, _) => [
            StaticIssue(
              id: 'wrong_owner',
              title: 'Wrong',
              file: mainFile,
              line: 1,
              level: config.severity,
              domain: IssueDomain.architecture,
              message: '',
              suggestion: '',
            ),
          ],
        ),
      ]),
      throwsStateError,
    );
  });
  test('invalid parameter fails both CLI commands before execution', () {
    File(p.join(project.path, 'boundarylens.yaml')).writeAsStringSync(
      'rules:\n  iot_security:\n    enabled: true\n    requireTls: invalid\n',
    );
    final cli = p.join(Directory.current.path, 'bin/boundarylens.dart');
    for (final command in [
      ['config', 'check', project.path],
      ['scan', project.path, '--format', 'json', '--stdout'],
    ]) {
      final result = Process.runSync(Platform.resolvedExecutable, [
        cli,
        ...command,
      ]);
      expect(result.exitCode, command.first == 'config' ? 1 : 2);
      expect('${result.stdout}${result.stderr}', contains('requireTls'));
    }
  });
  test(
    'input failures affect graph rule without poisoning unrelated syntax rule',
    () {
      File(mainFile).writeAsStringSync("import 'missing.dart';");
      final result = RuleRunner.run(context(), [
        RuleRegistration(
          definition: definition(id: 'syntax_fixture'),
          execute: (_, _, _) => [],
        ),
        RuleRegistration(
          definition: definition(
            id: 'graph_fixture',
            inputs: {RuleInput.importGraph},
          ),
          execute: (_, _, _) => [],
        ),
      ]);
      expect(result.coverage['syntax_fixture']!['status'], 'complete');
      expect(result.coverage['graph_fixture']!['status'], 'partial');
    },
  );
  test('scope defaults follow changed scan mode', () {
    final c = ScanContext(
      projectPath: project.path,
      config: ScanConfig.defaults(),
      allFiles: [mainFile],
      targetFiles: [mainFile],
      mode: ScanMode.changed,
      sources: SourceWorkspace(),
    );
    expect(c.scope, RuleScope.changed);
  });
}
