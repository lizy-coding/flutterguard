import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import 'config_loader.dart';
import 'path_utils.dart';

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

  static Set<String> getChangedFiles(String projectPath, String base) {
    final gitDir = Directory(p.join(projectPath, '.git'));
    if (!gitDir.existsSync()) return {};

    try {
      final result = Process.runSync(
        'git',
        ['diff', '--name-only', base, '--diff-filter=ACMR'],
        workingDirectory: projectPath,
      );
      final untracked = Process.runSync(
        'git',
        ['ls-files', '--others', '--exclude-standard'],
        workingDirectory: projectPath,
      );

      final changed = <String>{};
      for (final line in (result.stdout as String).split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          changed.add(p.normalize(p.join(projectPath, trimmed)));
        }
      }
      for (final line in (untracked.stdout as String).split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          changed.add(p.normalize(p.join(projectPath, trimmed)));
        }
      }
      return changed;
    } catch (_) {
      return {};
    }
  }
}
