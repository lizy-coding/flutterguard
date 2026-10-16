import 'dart:convert';
import 'dart:io';

import 'package:flutterguard_cli/src/scanner.dart';
import 'package:flutterguard_cli/src/baseline.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('fg_entry_');
    File(
      p.join(root.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: entry_test\n');
  });
  tearDown(() => root.deleteSync(recursive: true));

  void source(String name, String text) {
    final f = File(p.join(root.path, name));
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(text);
  }

  void config({
    String extra = '',
    String allowed = '[payment]',
    bool entries = true,
  }) {
    source('lib/payment/api.dart', "export 'internal.dart';");
    source('lib/payment/internal.dart', 'class Payment {}');
    source('flutterguard.yaml', '''
include: [lib/**]
architecture:
  modules:
    - name: checkout
      path: lib/checkout/**
      allowed_deps: $allowed
      ${entries ? 'entry_points: [lib/checkout/main.dart]' : ''}
    - name: payment
      path: lib/payment/**
      allowed_deps: []
      ${entries ? 'entry_points: [lib/payment/api.dart]' : ''}
$extra
''');
  }

  ScanResult scan({String? target, String? baseline}) =>
      FlutterGuardScanner.scan(
        projectPath: target ?? root.path,
        writeStdout: true,
        writeJson: true,
        baselinePath: baseline,
      );
  List<dynamic> issues(ScanResult r) =>
      (jsonDecode(r.structuredOutput!) as Map<String, dynamic>)['issues']
          as List<dynamic>;
  Map<String, dynamic> coverage(ScanResult r) =>
      ((jsonDecode(r.structuredOutput!) as Map<String, dynamic>)['coverage']
              as Map<String, dynamic>)['moduleBoundary']
          as Map<String, dynamic>;

  for (final directive in ['import', 'export']) {
    test('$directive may use public entry but cannot reach private file', () {
      source(
        'lib/checkout/main.dart',
        "$directive '../payment/internal.dart';",
      );
      config();
      final r = scan();
      expect(r.issues.where((i) => i.id == 'module_violation'), hasLength(1));
      expect(
        ((issues(r).single as Map)['metadata'] as Map)['reason'],
        'private_entry',
      );
      source('lib/checkout/main.dart', "$directive '../payment/api.dart';");
      expect(scan().issues, isEmpty);
    });
  }
  test('package identity is retained and own-package entry works', () {
    source(
      'lib/checkout/main.dart',
      "import 'package:entry_test/payment/internal.dart';",
    );
    config();
    expect(scan().issues, hasLength(1));
    source(
      'lib/checkout/main.dart',
      "import 'package:foreign/payment/internal.dart';",
    );
    final external = scan();
    expect(external.issues, isEmpty);
    expect(external.diagnostics, isEmpty);
    source(
      'lib/checkout/main.dart',
      "import 'package:entry_test/payment/api.dart';",
    );
    expect(scan().issues, isEmpty);
  });
  test('conditional import and export alternatives are checked', () {
    config();
    for (final directive in ['import', 'export']) {
      source(
        'lib/checkout/main.dart',
        "$directive '../payment/api.dart' if (dart.library.io) '../payment/internal.dart';",
      );
      expect(scan().issues, hasLength(1));
    }
  });
  test('internal implementation and public facade may use internal files', () {
    source('lib/checkout/main.dart', "import '../payment/api.dart';");
    config();
    source('lib/payment/service.dart', "import 'internal.dart';");
    expect(scan().issues, isEmpty);
    expect(coverage(scan())['status'], 'complete');
  });
  test('dependency permission is still required for public entry', () {
    source('lib/checkout/main.dart', "import '../payment/api.dart';");
    config(allowed: '[]');
    final r = scan();
    expect(r.issues, hasLength(1));
    expect(
      ((issues(r).single as Map)['metadata'] as Map)['reason'],
      'dependency',
    );
  });
  test('overlapping modules fail instead of depending on order', () {
    source('lib/checkout/main.dart', 'class Checkout {}');
    config(
      extra: '    - name: broad\n      path: lib/**\n      allowed_deps: []',
    );
    expect(scan, throwsFormatException);
  });
  test('unknown module names and duplicate names fail on scan', () {
    source('lib/checkout/main.dart', 'class Checkout {}');
    config(allowed: '[typo]');
    expect(scan, throwsFormatException);
    config(
      extra:
          '    - name: payment\n      path: other/**\n      allowed_deps: []',
    );
    expect(scan, throwsFormatException);
  });
  test('entry outside module and missing entry fail configuration', () {
    source('lib/checkout/main.dart', 'class Checkout {}');
    config();
    final f = File(p.join(root.path, 'flutterguard.yaml'));
    f.writeAsStringSync(
      f.readAsStringSync().replaceAll(
        'entry_points: [lib/payment/api.dart]',
        'entry_points: [lib/checkout/main.dart]',
      ),
    );
    expect(scan, throwsFormatException);
    config();
    f.writeAsStringSync(
      f.readAsStringSync().replaceAll(
        'lib/payment/api.dart',
        'lib/payment/missing.dart',
      ),
    );
    expect(scan, throwsFormatException);
  });
  test('legacy boundaries work but do not claim entry protection', () {
    source('lib/checkout/main.dart', "import '../payment/internal.dart';");
    config(entries: false);
    final r = scan();
    expect(r.issues, isEmpty);
    expect(coverage(r)['status'], 'partial');
  });
  test('unconfigured and disabled module checks are explicit', () {
    source('lib/checkout/main.dart', 'class Checkout {}');
    expect(coverage(scan())['status'], 'not_configured');
    config(extra: 'rules:\n  module_violation:\n    enabled: false');
    expect(coverage(scan())['status'], 'disabled');
  });
  test('unresolved local references and unowned sources are incomplete', () {
    source('lib/checkout/main.dart', "import '../payment/missing.dart';");
    config();
    expect(coverage(scan())['status'], 'partial');
    expect(
      scan().diagnostics.map((d) => d.stage),
      contains('reference_resolution'),
    );
    source('lib/checkout/main.dart', 'class Checkout {}');
    source('lib/unowned.dart', "import 'payment/internal.dart';");
    expect(coverage(scan())['status'], 'partial');
  });
  test('single-file request preserves file scope and filters findings', () {
    source('lib/checkout/main.dart', "import '../payment/internal.dart';");
    config();
    final r = scan(target: p.join(root.path, 'lib/checkout/main.dart'));
    expect(r.issues, hasLength(1));
    expect(coverage(r)['scope'], 'file');
    expect(coverage(r)['checkedFiles'], 1);
    expect(coverage(r)['totalFiles'], 3);
    expect(Directory(p.join(root.path, '.flutterguard')).existsSync(), isFalse);
  });
  test('module finding supports suppression and severity override', () {
    source(
      'lib/checkout/main.dart',
      "// flutterguard: ignore module_violation\nimport '../payment/internal.dart';",
    );
    config(extra: 'rules:\n  module_violation:\n    severity: low');
    final r = scan();
    expect(r.issues, isEmpty);
    expect(r.suppressedCount, 1);
    source('lib/checkout/main.dart', "import '../payment/internal.dart';");
    expect(scan().issues.single.level.name, 'low');
  });
  test('module findings preserve baseline filtering', () {
    source('lib/checkout/main.dart', "import '../payment/internal.dart';");
    config();
    final first = scan();
    final baseline = File(p.join(root.path, 'baseline.json'));
    baseline.writeAsStringSync(
      Baseline.encode(projectPath: root.path, issues: first.issues),
    );
    final second = scan(baseline: baseline.path);
    expect(second.issues, isEmpty);
    expect(second.suppressedByBaselineCount, 1);
    expect(coverage(second)['status'], 'complete');
  });
  test('CLI gate keeps exit 1 JSON usable and invalid contracts exit 2', () {
    source('lib/checkout/main.dart', "import '../payment/internal.dart';");
    config();
    ProcessResult cli() => Process.runSync(Platform.resolvedExecutable, [
      p.join(Directory.current.path, 'bin/flutterguard.dart'),
      'scan',
      root.path,
      '--format',
      'json',
      '--stdout',
      '--no-color',
      '--fail-on',
      'high',
    ]);
    final finding = cli();
    expect(finding.exitCode, 1);
    expect(
      (jsonDecode(finding.stdout as String) as Map)['issues'],
      hasLength(1),
    );
    config(allowed: '[unknown]');
    final invalid = cli();
    expect(invalid.exitCode, 2);
    expect(invalid.stdout, isEmpty);
  });
  test(
    'changed-only retains selected source scope with full module context',
    () {
      source('lib/checkout/main.dart', "import '../payment/api.dart';");
      config();
      for (final args in <List<String>>[
        ['init', '-b', 'main'],
        ['config', 'user.email', 'test@example.invalid'],
        ['config', 'user.name', 'Test'],
        ['add', '.'],
        ['commit', '-m', 'seed'],
      ]) {
        final result = Process.runSync(
          'git',
          args,
          workingDirectory: root.path,
        );
        expect(result.exitCode, 0, reason: result.stderr as String);
      }
      source('lib/checkout/main.dart', "import '../payment/internal.dart';");
      final result = FlutterGuardScanner.scan(
        projectPath: root.path,
        changedOnly: true,
        base: 'HEAD',
        writeStdout: true,
        writeJson: true,
      );
      expect(result.issues, hasLength(1));
      expect(coverage(result)['scope'], 'changed');
      expect(coverage(result)['checkedFiles'], 1);
      expect(coverage(result)['totalFiles'], 3);
    },
  );
  test('SARIF carries scope coverage and resolution diagnostics', () {
    source('lib/checkout/main.dart', "import '../payment/missing.dart';");
    config();
    final result = FlutterGuardScanner.scan(
      projectPath: root.path,
      writeStdout: true,
      writeSarif: true,
    );
    final sarif = jsonDecode(result.structuredOutput!) as Map;
    expect(sarif['version'], '2.1.0');
    final run = (sarif['runs'] as List).single as Map;
    final properties = run['properties'] as Map;
    final c = (properties['coverage'] as Map)['moduleBoundary'] as Map;
    expect(c['status'], 'partial');
    expect(
      (properties['diagnostics'] as List).single,
      containsPair('stage', 'reference_resolution'),
    );
    expect(Directory(p.join(root.path, '.flutterguard')).existsSync(), isFalse);
  });
}
