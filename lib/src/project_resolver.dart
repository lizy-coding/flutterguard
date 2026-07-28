import 'dart:io';

import 'package:path/path.dart' as p;

class ResolvedScanTarget {
  final String projectPath;
  final String? singleFile;

  const ResolvedScanTarget({required this.projectPath, this.singleFile});
}

class ProjectResolver {
  static const defaultConfigPath = 'flutterguard.yaml';

  static const _discoveryMarkers = [defaultConfigPath, 'pubspec.yaml'];

  static ResolvedScanTarget resolveScanTarget(String? explicitPath) {
    if (explicitPath != null && explicitPath.endsWith('.dart')) {
      final filePath = p.normalize(p.absolute(explicitPath));
      if (File(filePath).existsSync()) {
        final projectPath = _walkUpFindPubspec(p.dirname(filePath));
        if (projectPath == null) {
          throw FormatException(
            'No pubspec.yaml found above file "$filePath".',
          );
        }
        return ResolvedScanTarget(
          projectPath: projectPath,
          singleFile: filePath,
        );
      }
    }

    return ResolvedScanTarget(projectPath: resolveProjectPath(explicitPath));
  }

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

  static String? _walkUpFindPubspec(String startPath) {
    var dir = Directory(startPath);
    while (true) {
      if (File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
        return p.normalize(dir.path);
      }
      final parent = dir.parent.path;
      if (parent == dir.path) break;
      dir = dir.parent;
    }
    return null;
  }
}
