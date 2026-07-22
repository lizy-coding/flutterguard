import 'dart:convert';
import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import 'config_loader.dart';
import 'path_utils.dart';

class ChangedFilesException implements Exception {
  final String message;

  const ChangedFilesException(this.message);

  @override
  String toString() => message;
}

class FileCollector {
  static List<String> collect(String projectPath, ScanConfig config) {
    final context = projectPathContext(projectPath);
    final allFiles = <String>{};

    for (final pattern in config.include) {
      final glob = Glob(pattern.replaceAll('\\', '/'), context: context);
      for (final entity in glob.listSync(root: context.current)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          allFiles.add(normalizePath(entity.path, context: context));
        }
      }
    }

    for (final pattern in config.exclude) {
      final glob = Glob(pattern.replaceAll('\\', '/'), context: context);
      for (final entity in glob.listSync(root: context.current)) {
        allFiles.remove(normalizePath(entity.path, context: context));
      }
      allFiles.removeWhere((f) => glob.matches(f));
    }

    return allFiles.toList()..sort();
  }

  static Set<String>? getChangedFiles(String projectPath, String base) {
    try {
      final rootResult = Process.runSync(
        'git',
        ['rev-parse', '--show-toplevel'],
        workingDirectory: projectPath,
        stdoutEncoding: utf8,
      );
      if (rootResult.exitCode != 0) return null;

      final gitRoot = (rootResult.stdout as String).trim();
      final canonicalGitRoot = Directory(gitRoot).resolveSymbolicLinksSync();
      final canonicalProjectPath = Directory(
        projectPath,
      ).resolveSymbolicLinksSync();
      if (base.startsWith('-')) {
        throw ChangedFilesException('Invalid Git base "$base".');
      }
      final refResult = Process.runSync(
        'git',
        ['rev-parse', '--verify', '$base^{commit}'],
        workingDirectory: gitRoot,
        stdoutEncoding: utf8,
      );
      if (refResult.exitCode != 0) {
        throw ChangedFilesException(
          _gitFailureMessage(
            'Invalid Git base "$base"',
            refResult.stderr.toString(),
          ),
        );
      }
      final verifiedRef = (refResult.stdout as String).trim();
      final result = Process.runSync(
        'git',
        ['diff', '--name-only', '--diff-filter=ACMR', '-z', verifiedRef, '--'],
        workingDirectory: gitRoot,
        stdoutEncoding: utf8,
      );
      if (result.exitCode != 0) {
        throw ChangedFilesException(
          _gitFailureMessage('git diff', result.stderr.toString()),
        );
      }
      final untracked = Process.runSync(
        'git',
        ['ls-files', '--others', '--exclude-standard', '-z'],
        workingDirectory: gitRoot,
        stdoutEncoding: utf8,
      );
      if (untracked.exitCode != 0) {
        throw ChangedFilesException(
          _gitFailureMessage('git ls-files', untracked.stderr.toString()),
        );
      }

      final changed = <String>{};
      for (final path in (result.stdout as String).split('\x00')) {
        if (path.isNotEmpty) {
          changed.add(
            _projectAnchoredGitPath(
              projectPath: projectPath,
              canonicalProjectPath: canonicalProjectPath,
              canonicalGitRoot: canonicalGitRoot,
              gitRelativePath: path,
            ),
          );
        }
      }
      for (final path in (untracked.stdout as String).split('\x00')) {
        if (path.isNotEmpty) {
          changed.add(
            _projectAnchoredGitPath(
              projectPath: projectPath,
              canonicalProjectPath: canonicalProjectPath,
              canonicalGitRoot: canonicalGitRoot,
              gitRelativePath: path,
            ),
          );
        }
      }
      return changed;
    } on ProcessException {
      return null;
    }
  }

  static String _gitFailureMessage(String command, Object stderr) {
    final detail = stderr.toString().trim();
    return detail.isEmpty ? '$command failed.' : '$command failed: $detail';
  }

  static String _projectAnchoredGitPath({
    required String projectPath,
    required String canonicalProjectPath,
    required String canonicalGitRoot,
    required String gitRelativePath,
  }) {
    final canonicalPath = p.join(canonicalGitRoot, gitRelativePath);
    final projectRelativePath = p.relative(
      canonicalPath,
      from: canonicalProjectPath,
    );
    return p.normalize(p.join(projectPath, projectRelativePath));
  }
}
