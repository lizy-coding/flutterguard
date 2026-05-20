import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';

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
}
