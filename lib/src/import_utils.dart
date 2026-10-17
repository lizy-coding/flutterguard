import 'package:path/path.dart' as p;

import 'path_utils.dart';

String? resolveImport(
  String sourceFile,
  String importStr,
  Set<String> fileSet, {
  String? projectPath,
  String? packageName,
  p.Context? context,
}) {
  context ??= p.context;
  final uri = Uri.tryParse(importStr);
  if (uri == null || uri.hasQuery || uri.hasFragment) return null;
  final normalizedFiles = {
    for (final file in fileSet) normalizePath(file, context: context),
  };
  String candidate;
  if (uri.scheme == 'package') {
    final segments = uri.pathSegments;
    if (projectPath == null ||
        packageName == null ||
        segments.length < 2 ||
        segments.first != packageName) {
      return null;
    }
    final projectContext = projectPathContext(projectPath, context: context);
    final lib = projectContext.join(projectContext.current, 'lib');
    candidate = projectContext.normalize(
      projectContext.joinAll([lib, ...segments.skip(1)]),
    );
    if (!projectContext.isWithin(lib, candidate)) return null;
  } else {
    if (uri.hasScheme || uri.hasAuthority) return null;
    candidate = context.normalize(
      context.join(
        context.dirname(normalizePath(sourceFile, context: context)),
        uri.path,
      ),
    );
  }
  return normalizedFiles.contains(candidate) ? candidate : null;
}
