import 'package:path/path.dart' as p;

import 'path_utils.dart';

String? resolveImport(
  String sourceFile,
  String importStr,
  Set<String> fileSet, {
  String? projectPath,
  p.Context? context,
}) {
  context ??= p.context;
  final source = normalizePath(sourceFile, context: context);
  final normalizedFiles = {
    for (final file in fileSet) normalizePath(file, context: context),
  };

  if (importStr.startsWith('package:')) {
    final packageRelative =
        importStr.replaceFirst(RegExp(r'^package:[^/]+/'), '');
    return _resolvePackageImport(
      packageRelative,
      normalizedFiles,
      projectPath: projectPath,
      context: context,
    );
  }

  final sourceDir = context.dirname(source);
  final resolved = context.normalize(context.join(sourceDir, importStr));
  if (normalizedFiles.contains(resolved)) return resolved;
  final withExt = resolved.endsWith('.dart') ? resolved : '$resolved.dart';
  if (normalizedFiles.contains(withExt)) return withExt;
  return null;
}

String? _resolvePackageImport(
  String packageRelative,
  Set<String> fileSet, {
  String? projectPath,
  required p.Context context,
}) {
  final relativeWithExt = packageRelative.endsWith('.dart')
      ? packageRelative
      : '$packageRelative.dart';
  final normalizedRelative = context.normalize(relativeWithExt);

  if (projectPath != null) {
    final projectContext = projectPathContext(projectPath, context: context);
    final candidate = projectContext.normalize(
      projectContext.join(projectContext.current, 'lib', normalizedRelative),
    );
    if (fileSet.contains(candidate)) return candidate;
  }

  for (final file in fileSet) {
    final libRelative = _relativeToLib(file, context);
    if (libRelative == normalizedRelative) return file;
  }

  return null;
}

String? _relativeToLib(String file, p.Context context) {
  final parts = context.split(context.normalize(file));
  final libIndex = parts.lastIndexOf('lib');
  if (libIndex == -1 || libIndex == parts.length - 1) return null;
  return context.joinAll(parts.skip(libIndex + 1));
}
