import 'package:glob/glob.dart';

import 'import_graph.dart';
import 'path_utils.dart';
import 'source_workspace.dart';

class BoundaryDefinition {
  final String name;
  final String path;
  final List<String> allowedDeps;

  const BoundaryDefinition({
    required this.name,
    required this.path,
    required this.allowedDeps,
  });
}

class BoundaryViolation {
  final ImportEdge edge;
  final BoundaryDefinition source;
  final BoundaryDefinition target;

  const BoundaryViolation({
    required this.edge,
    required this.source,
    required this.target,
  });
}

class DependencyBoundaryEngine {
  static List<BoundaryViolation> analyze({
    required Iterable<String> sourceFiles,
    required Iterable<String> allFiles,
    required List<BoundaryDefinition> boundaries,
    required ImportGraph graph,
    required SourceWorkspace workspace,
    String? projectPath,
  }) {
    final fileToBoundary = <String, BoundaryDefinition>{};
    for (final file in allFiles.map(normalizePath)) {
      for (final boundary in boundaries) {
        try {
          final matches = projectPath == null
              ? Glob(boundary.path.replaceAll('\\', '/')).matches(file)
              : matchesProjectGlob(file, boundary.path, projectPath);
          if (matches) {
            fileToBoundary[file] = boundary;
            break;
          }
        } on Object catch (error) {
          workspace.addDiagnostic(ScanDiagnostic(
            stage: 'boundary_glob',
            file: file,
            message: 'Invalid boundary glob "${boundary.path}": $error',
          ));
        }
      }
    }

    final violations = <BoundaryViolation>[];
    for (final file in sourceFiles.map(normalizePath)) {
      final source = fileToBoundary[file];
      if (source == null) continue;
      for (final edge in graph.outgoing(file)) {
        final target = fileToBoundary[edge.target];
        if (target == null || target.name == source.name) continue;
        if (!source.allowedDeps.contains(target.name)) {
          violations.add(BoundaryViolation(
            edge: edge,
            source: source,
            target: target,
          ));
        }
      }
    }
    return violations;
  }
}
