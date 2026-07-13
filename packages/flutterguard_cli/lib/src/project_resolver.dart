import 'dart:io';

import 'package:path/path.dart' as p;

class ProjectResolver {
  static const defaultConfigPath = 'flutterguard.yaml';

  static const _discoveryMarkers = [
    defaultConfigPath,
    'pubspec.yaml',
  ];

  static String resolveProjectPath(String? explicitPath) {
    if (explicitPath != null && explicitPath != '.') {
      return p.normalize(p.absolute(explicitPath));
    }
    final discovered = _walkUpFind(Directory.current.path);
    return discovered ?? Directory.current.path;
  }

  static String resolveConfigPath({
    required String projectPath,
    required String? explicitConfig,
  }) {
    final configPath = explicitConfig ?? defaultConfigPath;
    final resolvedPath = p.isAbsolute(configPath)
        ? p.normalize(configPath)
        : p.normalize(p.join(projectPath, configPath));

    if (explicitConfig != null && !File(resolvedPath).existsSync()) {
      throw FormatException('Config file "$resolvedPath" does not exist.');
    }

    return resolvedPath;
  }

  static String? _walkUpFind(String startPath) {
    var dir = Directory(startPath);
    while (true) {
      for (final marker in _discoveryMarkers) {
        final candidate = p.join(dir.path, marker);
        if (File(candidate).existsSync()) return dir.path;
      }
      final libCandidate = p.join(dir.path, 'lib');
      if (Directory(libCandidate).existsSync()) return dir.path;

      final parent = dir.parent.path;
      if (parent == dir.path) break;
      dir = dir.parent;
    }
    return null;
  }
}
