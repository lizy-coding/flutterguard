import 'dart:io';

class InstallDoctor {
  static String generate({required String version}) {
    final buffer = StringBuffer()
      ..writeln('FlutterGuard install doctor')
      ..writeln('Version: $version')
      ..writeln('Dart executable: ${Platform.resolvedExecutable}')
      ..writeln('Entrypoint: ${Platform.script}')
      ..writeln('Operating system: ${Platform.operatingSystem}')
      ..writeln('PATH entries named flutterguard:');

    final matches = _findFlutterGuardCommands();
    if (matches.isEmpty) {
      buffer.writeln('  none found');
    } else {
      for (final match in matches) {
        buffer.writeln('  $match');
      }
    }

    buffer
      ..writeln()
      ..writeln('Recommended checks:')
      ..writeln('  flutterguard --version')
      ..writeln('  flutterguard --help')
      ..writeln()
      ..writeln(
          'If the version is stale, reinstall or use the source launcher:')
      ..writeln('  dart pub global activate flutterguard_cli')
      ..writeln('  ./scripts/flutterguard-dev --version');

    return buffer.toString();
  }

  static List<String> _findFlutterGuardCommands() {
    final path = Platform.environment['PATH'];
    if (path == null || path.isEmpty) return const [];

    final names = Platform.isWindows
        ? const ['flutterguard.exe', 'flutterguard.bat', 'flutterguard.cmd']
        : const ['flutterguard'];
    final matches = <String>[];

    for (final dir in path.split(Platform.isWindows ? ';' : ':')) {
      if (dir.isEmpty) continue;
      for (final name in names) {
        final candidate = File(_joinPath(dir, name));
        if (candidate.existsSync()) {
          matches.add(candidate.path);
        }
      }
    }
    return matches;
  }

  static String _joinPath(String left, String right) {
    final separator = Platform.isWindows ? r'\' : '/';
    if (left.endsWith(separator)) return '$left$right';
    return '$left$separator$right';
  }
}
