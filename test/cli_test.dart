import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void _runGit(Directory directory, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: directory.path);
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

void main() {
  test('CLI version matches package version', () {
    final pubspec = File(
      p.join(Directory.current.path, 'pubspec.yaml'),
    ).readAsStringSync();
    final version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1);
    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'boundarylens.dart',
    );
    final result = Process.runSync(Platform.resolvedExecutable, [
      entrypoint,
      '--version',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0);
    expect((result.stdout as String).trim(), 'boundarylens $version');
  });

  test(
    'scan exits with setup error when the project matches no Dart files',
    () {
      final project = Directory.systemTemp.createTempSync(
        'boundarylens_cli_empty_project_',
      );
      addTearDown(() => project.deleteSync(recursive: true));

      final entrypoint = p.join(
        Directory.current.path,
        'bin',
        'boundarylens.dart',
      );
      final result = Process.runSync(Platform.resolvedExecutable, [
        entrypoint,
        'scan',
        project.path,
        '--format',
        'json',
        '--output',
        '.boundarylens/test',
        '--no-color',
      ], workingDirectory: Directory.current.path);

      expect(result.exitCode, 2);
      expect(result.stderr, contains('No Dart files matched'));
      expect(
        File(
          p.join(project.path, '.boundarylens', 'test', 'report.json'),
        ).existsSync(),
        isFalse,
      );
    },
  );

  test('--stdout with --format table exits with error', () {
    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'boundarylens.dart',
    );
    final result = Process.runSync(Platform.resolvedExecutable, [
      entrypoint,
      'scan',
      'example',
      '--stdout',
      '--no-color',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 2);
    expect(result.stdout, isEmpty);
    expect(result.stderr, contains('--stdout requires'));
  });

  test('--stdout with --format json writes valid JSON to stdout', () {
    final output = Directory.systemTemp.createTempSync(
      'boundarylens_cli_stdout_output_',
    );
    addTearDown(() => output.deleteSync(recursive: true));
    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'boundarylens.dart',
    );
    final result = Process.runSync(Platform.resolvedExecutable, [
      entrypoint,
      'scan',
      'example',
      '--format',
      'json',
      '--stdout',
      '--output',
      output.path,
      '--no-color',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0);
    final payload = jsonDecode(result.stdout as String);
    expect(payload, isA<Map<String, Object?>>());
    expect((payload as Map<String, Object?>)['schemaVersion'], '2.0.0');
    expect(File(p.join(output.path, 'report.json')).existsSync(), isFalse);
  });

  test('single .dart file path scans only that file', () {
    final project = Directory.systemTemp.createTempSync(
      'boundarylens_cli_single_file_',
    );
    addTearDown(() => project.deleteSync(recursive: true));
    Directory(p.join(project.path, 'lib')).createSync();
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('''
name: single_file_fixture
environment:
  sdk: ^3.11.0
''');
    File(
      p.join(project.path, 'boundarylens.yaml'),
    ).writeAsStringSync('rules:\n  iot_security:\n    enabled: true\n');
    final selectedFile = File(p.join(project.path, 'lib', 'selected.dart'))
      ..writeAsStringSync('''
void connect() {
  final password = 'admin123';
}
''');
    File(p.join(project.path, 'lib', 'other.dart')).writeAsStringSync('''
void connect() {
  final password = 'other-secret';
}
''');

    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'boundarylens.dart',
    );
    final result = Process.runSync(Platform.resolvedExecutable, [
      entrypoint,
      'scan',
      selectedFile.path,
      '--format',
      'json',
      '--stdout',
      '--no-color',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr as String);
    final payload = jsonDecode(result.stdout as String) as Map<String, Object?>;
    expect(payload['scanMode'], 'full');
    final issues = payload['issues'] as List<Object?>;
    expect(issues, isNotEmpty);
    expect(
      issues.cast<Map<String, Object?>>(),
      everyElement(containsPair('file', selectedFile.path)),
    );
  });

  test('single .dart file without parent pubspec exits with error', () {
    final directory = Directory.systemTemp.createTempSync(
      'boundarylens_cli_orphan_file_',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File(p.join(directory.path, 'orphan.dart'))
      ..writeAsStringSync('void main() {}\n');
    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'boundarylens.dart',
    );
    final result = Process.runSync(Platform.resolvedExecutable, [
      entrypoint,
      'scan',
      file.path,
      '--format',
      'json',
      '--stdout',
      '--no-color',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 2);
    expect(result.stdout, isEmpty);
    expect(result.stderr, contains('No pubspec.yaml found above file'));
  });

  test('JSON issue includes fileRelative field', () {
    final project = Directory.systemTemp.createTempSync(
      'boundarylens_cli_relative_file_',
    );
    addTearDown(() => project.deleteSync(recursive: true));
    Directory(p.join(project.path, 'lib')).createSync();
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync('''
name: relative_file_fixture
environment:
  sdk: ^3.11.0
''');
    File(
      p.join(project.path, 'boundarylens.yaml'),
    ).writeAsStringSync('rules:\n  iot_security:\n    enabled: true\n');
    File(p.join(project.path, 'lib', 'device.dart')).writeAsStringSync('''
void connect() {
  final password = 'admin123';
}
''');

    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'boundarylens.dart',
    );
    final result = Process.runSync(Platform.resolvedExecutable, [
      entrypoint,
      'scan',
      project.path,
      '--format',
      'json',
      '--stdout',
      '--no-color',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0, reason: result.stderr as String);
    final payload = jsonDecode(result.stdout as String) as Map<String, Object?>;
    final issue =
        (payload['issues'] as List<Object?>).first as Map<String, Object?>;
    expect(issue['fileRelative'], startsWith('lib/'));
  });

  test('changed-only clean scan succeeds and writes an empty JSON report', () {
    final project = Directory.systemTemp.createTempSync(
      'boundarylens_cli_clean_project_',
    );
    addTearDown(() => project.deleteSync(recursive: true));
    Directory(p.join(project.path, 'lib')).createSync();
    File(
      p.join(project.path, 'lib', 'clean.dart'),
    ).writeAsStringSync('class Clean {}\n');
    _runGit(project, ['init', '-b', 'main']);
    _runGit(project, ['config', 'user.email', 'test@example.com']);
    _runGit(project, ['config', 'user.name', 'BoundaryLens Test']);
    _runGit(project, ['add', '.']);
    _runGit(project, ['commit', '-m', 'initial']);

    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'boundarylens.dart',
    );
    final result = Process.runSync(Platform.resolvedExecutable, [
      entrypoint,
      'scan',
      project.path,
      '--changed-only',
      '--base',
      'main',
      '--format',
      'json',
      '--output',
      '.boundarylens/test',
      '--no-color',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 0);
    expect(result.stdout, contains('No changed Dart files matched'));
    final report = File(
      p.join(project.path, '.boundarylens', 'test', 'report.json'),
    );
    expect(report.existsSync(), isTrue);
    final payload =
        jsonDecode(report.readAsStringSync()) as Map<String, Object?>;
    expect(payload['scanMode'], 'changed');
    expect(payload['issues'], isEmpty);
  });

  test('explicitly selected default config must exist', () {
    final project = Directory.systemTemp.createTempSync(
      'boundarylens_cli_required_config_',
    );
    addTearDown(() => project.deleteSync(recursive: true));
    Directory(p.join(project.path, 'lib')).createSync();
    File(
      p.join(project.path, 'lib', 'plain.dart'),
    ).writeAsStringSync('class Plain {}\n');

    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'boundarylens.dart',
    );
    final result = Process.runSync(Platform.resolvedExecutable, [
      entrypoint,
      'scan',
      project.path,
      '--config',
      'boundarylens.yaml',
      '--no-color',
    ], workingDirectory: Directory.current.path);

    expect(result.exitCode, 2);
    expect(result.stderr, contains('Config file'));
    expect(result.stderr, contains('does not exist'));
  });

  test('target project config is not shadowed by the working directory', () {
    final sandbox = Directory.systemTemp.createTempSync(
      'boundarylens_cli_config_scope_',
    );
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final workingProject = Directory(p.join(sandbox.path, 'working'))
      ..createSync(recursive: true);
    final targetProject = Directory(p.join(sandbox.path, 'target'))
      ..createSync(recursive: true);
    Directory(p.join(targetProject.path, 'lib')).createSync();
    File(
      p.join(targetProject.path, 'lib', 'target.dart'),
    ).writeAsStringSync('class Target {}\n');
    File(p.join(workingProject.path, 'boundarylens.yaml')).writeAsStringSync('''
include:
  - cwd_only/**
''');
    File(p.join(targetProject.path, 'boundarylens.yaml')).writeAsStringSync('''
include:
  - lib/**
''');

    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'boundarylens.dart',
    );
    final result = Process.runSync(Platform.resolvedExecutable, [
      entrypoint,
      'scan',
      targetProject.path,
      '--format',
      'json',
      '--output',
      '.boundarylens/test',
      '--no-color',
    ], workingDirectory: workingProject.path);

    expect(result.exitCode, 0);
    expect(
      File(
        p.join(targetProject.path, '.boundarylens', 'test', 'report.json'),
      ).existsSync(),
      isTrue,
    );
  });
}
