import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';

import 'config_loader.dart';

class FileCollector {
  static List<String> collect(String projectPath, ScanConfig config) {
    final allFiles = <String>{};

    for (final pattern in config.include) {
      final glob = Glob(pattern, recursive: true);
      final root = projectPath;
      for (final entity in glob.listSync(root: root)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          allFiles.add(entity.path);
        }
      }
    }

    for (final pattern in config.exclude) {
      final glob = Glob(pattern, recursive: true);
      final root = projectPath;
      for (final entity in glob.listSync(root: root)) {
        allFiles.remove(entity.path);
      }
      allFiles.removeWhere((f) => glob.matches(f));
    }

    return allFiles.toList()..sort();
  }
}
