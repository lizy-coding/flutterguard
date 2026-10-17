import 'dart:convert';
import 'dart:io';

import 'package:boundarylens_cli/src/config_tools.dart';
import 'package:boundarylens_cli/src/project_resolver.dart';
import 'package:boundarylens_cli/src/scanner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  setUp(() {
    root = Directory.systemTemp.createTempSync('boundarylens_rename_');
    Directory(p.join(root.path, 'lib')).createSync();
    File(
      p.join(root.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: rename_fixture\n');
  });
  tearDown(() => root.deleteSync(recursive: true));

  test(
    'new config wins; old config is fallback; explicit path always wins',
    () {
      final legacy = File(p.join(root.path, 'flutterguard.yaml'))
        ..writeAsStringSync('rules: {}');
      expect(
        ProjectResolver.resolveConfigPath(
          projectPath: root.path,
          explicitConfig: null,
        ),
        legacy.path,
      );
      expect(
        ConfigTools.doctor(projectPath: root.path).configPath,
        legacy.path,
      );
      final current = File(p.join(root.path, 'boundarylens.yaml'))
        ..writeAsStringSync('rules: {}');
      expect(
        ProjectResolver.resolveConfigPath(
          projectPath: root.path,
          explicitConfig: null,
        ),
        current.path,
      );
      expect(
        ProjectResolver.resolveConfigPath(
          projectPath: root.path,
          explicitConfig: 'flutterguard.yaml',
        ),
        legacy.path,
      );
    },
  );

  for (final marker in ['boundarylens', 'flutterguard']) {
    test('$marker suppression works through legacy config fallback', () {
      File(p.join(root.path, 'lib/device.dart')).writeAsStringSync('''
// $marker: ignore lifecycle_resource_not_disposed
class Owner { Timer? timer; }
''');
      File(p.join(root.path, 'flutterguard.yaml')).writeAsStringSync(
        'rules:\n  lifecycle_resource_not_disposed:\n    enabled: true\n',
      );
      final result = BoundaryLensScanner.scan(
        projectPath: root.path,
        writeStdout: true,
        writeJson: true,
      );
      expect(result.issues, isEmpty);
      expect(result.suppressedCount, 1);
    });
  }

  test('new executable advertises new name and retains JSON schema', () {
    File(
      p.join(root.path, 'lib/main.dart'),
    ).writeAsStringSync('class Example {}');
    final cli = p.join(Directory.current.path, 'bin/boundarylens.dart');
    final version = Process.runSync(Platform.resolvedExecutable, [
      cli,
      '--version',
    ]);
    expect(version.exitCode, 0);
    expect(version.stdout, startsWith('boundarylens '));
    final report = Process.runSync(Platform.resolvedExecutable, [
      cli,
      'scan',
      root.path,
      '--format',
      'json',
      '--stdout',
    ]);
    expect(report.exitCode, 0);
    final json = jsonDecode(report.stdout as String) as Map;
    expect(json['schemaVersion'], '2.0.0');
    expect(json['issues'], isEmpty);
    expect(json['coverage'], isNotNull);
  });
}
