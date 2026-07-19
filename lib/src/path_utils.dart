import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

p.Context projectPathContext(String projectPath, {p.Context? context}) {
  context ??= p.context;
  final absoluteRoot = context.normalize(context.absolute(projectPath));
  return p.Context(style: context.style, current: absoluteRoot);
}

String normalizePath(String path, {p.Context? context, String? basePath}) {
  context ??= p.context;
  if (basePath != null) {
    context = projectPathContext(basePath, context: context);
  }
  final absolute = context.isAbsolute(path) ? path : context.absolute(path);
  return context.normalize(absolute);
}

bool matchesProjectGlob(
  String filePath,
  String pattern,
  String projectPath, {
  p.Context? context,
}) {
  final projectContext = projectPathContext(projectPath, context: context);
  final normalizedFile = normalizePath(filePath, context: projectContext);
  final normalizedPattern = pattern.replaceAll('\\', '/');
  return Glob(
    normalizedPattern,
    context: projectContext,
  ).matches(normalizedFile);
}

String projectRelativePath(
  String filePath,
  String projectPath, {
  p.Context? context,
}) {
  final projectContext = projectPathContext(projectPath, context: context);
  return projectContext.relative(
    normalizePath(filePath, context: projectContext),
    from: projectContext.current,
  );
}
