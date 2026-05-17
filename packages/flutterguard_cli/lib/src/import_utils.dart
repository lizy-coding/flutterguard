import 'package:path/path.dart' as p;

String? resolveImport(
    String sourceFile, String importStr, Set<String> fileSet) {
  if (importStr.startsWith('package:')) {
    final relative = importStr.replaceFirst(RegExp(r'^package:[^/]+/'), '');
    final candidate = p.join(p.dirname(sourceFile), relative);
    if (fileSet.contains(candidate)) return candidate;
    final withExt = candidate.endsWith('.dart') ? candidate : '$candidate.dart';
    if (fileSet.contains(withExt)) return withExt;
    return null;
  }

  final sourceDir = p.dirname(sourceFile);
  final resolved = p.normalize(p.join(sourceDir, importStr));
  if (fileSet.contains(resolved)) return resolved;
  final withExt = resolved.endsWith('.dart') ? resolved : '$resolved.dart';
  if (fileSet.contains(withExt)) return withExt;
  return null;
}
