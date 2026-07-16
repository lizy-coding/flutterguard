import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void _runGit(Directory directory, List<String> args) {
  final result = Process.runSync(
    'git',
    args,
    workingDirectory: directory.path,
  );
  if (result.exitCode != 0) {
    throw StateError('git ${args.join(' ')} failed: ${result.stderr}');
  }
}

void main() {
  test('CLI version matches package version', () {
    final pubspec =
        File(p.join(Directory.current.path, 'pubspec.yaml')).readAsStringSync();
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec)!
        .group(1);
    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'flutterguard.dart',
    );
    final result = Process.runSync(
      Platform.resolvedExecutable,
      [entrypoint, '--version'],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0);
    expect((result.stdout as String).trim(), 'flutterguard $version');
  });

  test('scan exits with setup error when the project matches no Dart files',
      () {
    final project = Directory.systemTemp.createTempSync(
      'flutterguard_cli_empty_project_',
    );
    addTearDown(() => project.deleteSync(recursive: true));

    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'flutterguard.dart',
    );
    final result = Process.runSync(
      Platform.resolvedExecutable,
      [
        entrypoint,
        'scan',
        project.path,
        '--format',
        'json',
        '--output',
        '.flutterguard/test',
        '--no-color',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 2);
    expect(result.stderr, contains('No Dart files matched'));
    expect(
      File(p.join(project.path, '.flutterguard', 'test', 'report.json'))
          .existsSync(),
      isFalse,
    );
  });

  test('changed-only clean scan succeeds and writes an empty JSON report', () {
    final project = Directory.systemTemp.createTempSync(
      'flutterguard_cli_clean_project_',
    );
    addTearDown(() => project.deleteSync(recursive: true));
    Directory(p.join(project.path, 'lib')).createSync();
    File(p.join(project.path, 'lib', 'clean.dart'))
        .writeAsStringSync('class Clean {}\n');
    _runGit(project, ['init', '-b', 'main']);
    _runGit(project, ['config', 'user.email', 'test@example.com']);
    _runGit(project, ['config', 'user.name', 'FlutterGuard Test']);
    _runGit(project, ['add', '.']);
    _runGit(project, ['commit', '-m', 'initial']);

    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'flutterguard.dart',
    );
    final result = Process.runSync(
      Platform.resolvedExecutable,
      [
        entrypoint,
        'scan',
        project.path,
        '--changed-only',
        '--base',
        'main',
        '--format',
        'json',
        '--output',
        '.flutterguard/test',
        '--no-color',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0);
    expect(result.stdout, contains('No changed Dart files matched'));
    final report = File(
      p.join(project.path, '.flutterguard', 'test', 'report.json'),
    );
    expect(report.existsSync(), isTrue);
    final payload =
        jsonDecode(report.readAsStringSync()) as Map<String, Object?>;
    expect(payload['scanMode'], 'changed');
    expect(payload['issues'], isEmpty);
  });

  test('explicitly selected default config must exist', () {
    final project = Directory.systemTemp.createTempSync(
      'flutterguard_cli_required_config_',
    );
    addTearDown(() => project.deleteSync(recursive: true));
    Directory(p.join(project.path, 'lib')).createSync();
    File(p.join(project.path, 'lib', 'plain.dart'))
        .writeAsStringSync('class Plain {}\n');

    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'flutterguard.dart',
    );
    final result = Process.runSync(
      Platform.resolvedExecutable,
      [
        entrypoint,
        'scan',
        project.path,
        '--config',
        'flutterguard.yaml',
        '--no-color',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 2);
    expect(result.stderr, contains('Config file'));
    expect(result.stderr, contains('does not exist'));
  });

  test('target project config is not shadowed by the working directory', () {
    final sandbox = Directory.systemTemp.createTempSync(
      'flutterguard_cli_config_scope_',
    );
    addTearDown(() => sandbox.deleteSync(recursive: true));
    final workingProject = Directory(p.join(sandbox.path, 'working'))
      ..createSync(recursive: true);
    final targetProject = Directory(p.join(sandbox.path, 'target'))
      ..createSync(recursive: true);
    Directory(p.join(targetProject.path, 'lib')).createSync();
    File(p.join(targetProject.path, 'lib', 'target.dart'))
        .writeAsStringSync('class Target {}\n');
    File(p.join(workingProject.path, 'flutterguard.yaml')).writeAsStringSync('''
include:
  - cwd_only/**
''');
    File(p.join(targetProject.path, 'flutterguard.yaml')).writeAsStringSync('''
include:
  - lib/**
''');

    final entrypoint = p.join(
      Directory.current.path,
      'bin',
      'flutterguard.dart',
    );
    final result = Process.runSync(
      Platform.resolvedExecutable,
      [
        entrypoint,
        'scan',
        targetProject.path,
        '--format',
        'json',
        '--output',
        '.flutterguard/test',
        '--no-color',
      ],
      workingDirectory: workingProject.path,
    );

    expect(result.exitCode, 0);
    expect(
      File(p.join(
        targetProject.path,
        '.flutterguard',
        'test',
        'report.json',
      )).existsSync(),
      isTrue,
    );
  });
}
