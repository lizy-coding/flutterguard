import 'dart:io';

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import 'config_loader.dart';

class FileCollector {
  static List<String> collect(String projectPath, ScanConfig config) {
    final allFiles = <String>{};

    for (final pattern in config.include) {
      final fullPattern = p.join(projectPath, pattern);
      final glob = Glob(fullPattern);
      for (final entity in glob.listSync()) {
        if (entity is File && entity.path.endsWith('.dart')) {
          allFiles.add(entity.path);
        }
      }
    }

    for (final pattern in config.exclude) {
      final fullPattern = p.join(projectPath, pattern);
      final glob = Glob(fullPattern);
      for (final entity in glob.listSync()) {
        allFiles.remove(entity.path);
      }
      allFiles.removeWhere((f) => glob.matches(f));
    }

    return allFiles.toList()..sort();
  }
}
