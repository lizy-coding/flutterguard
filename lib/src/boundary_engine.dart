import 'package:glob/glob.dart';

import 'import_graph.dart';
import 'path_utils.dart';
import 'source_workspace.dart';

class BoundaryDefinition {
  final String name;
  final String path;
  final List<String> allowedDeps;
  final List<String>? entryPoints;

  const BoundaryDefinition({
    required this.name,
    required this.path,
    required this.allowedDeps,
    this.entryPoints,
  });
}

class BoundaryViolation {
  final ImportEdge edge;
  final BoundaryDefinition source;
  final BoundaryDefinition target;
  final String reason;

  const BoundaryViolation({
    required this.edge,
    required this.source,
    required this.target,
    this.reason = 'dependency',
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
    bool protectEntries = false,
  }) {
    final fileToBoundary = <String, BoundaryDefinition>{};
    for (final file in allFiles.map(normalizePath)) {
      final owners = <BoundaryDefinition>[];
      for (final boundary in boundaries) {
        try {
          if (projectPath == null
              ? Glob(boundary.path.replaceAll('\\', '/')).matches(file)
              : matchesProjectGlob(file, boundary.path, projectPath)) {
            owners.add(boundary);
          }
        } on Object catch (error) {
          workspace.addDiagnostic(
            ScanDiagnostic(
              stage: 'boundary_glob',
              file: file,
              message: 'Invalid boundary glob "${boundary.path}": $error',
            ),
          );
        }
      }
      if (owners.length == 1) {
        fileToBoundary[file] = owners.single;
      } else if (owners.length > 1) {
        workspace.addDiagnostic(
          ScanDiagnostic(
            stage: 'boundary_ownership',
            file: file,
            message:
                'Ambiguous module ownership: ${owners.map((b) => b.name).join(', ')}',
          ),
        );
      }
    }

    final violations = <BoundaryViolation>[];
    for (final file in sourceFiles.map(normalizePath)) {
      final source = fileToBoundary[file];
      if (source == null) {
        workspace.addDiagnostic(
          ScanDiagnostic(
            stage: 'boundary_scope',
            file: file,
            message:
                'Source is outside declared boundaries; no boundary verdict.',
          ),
        );
        continue;
      }
      for (final edge in graph.outgoing(file)) {
        final target = fileToBoundary[edge.target];
        if (target == null) {
          workspace.addDiagnostic(
            ScanDiagnostic(
              stage: 'boundary_scope',
              file: file,
              message:
                  'Target "${edge.uri}" is outside declared boundaries; no boundary verdict.',
            ),
          );
          continue;
        }
        if (target.name == source.name) continue;
        if (!source.allowedDeps.contains(target.name)) {
          violations.add(
            BoundaryViolation(edge: edge, source: source, target: target),
          );
        } else if (protectEntries &&
            target.entryPoints != null &&
            !target.entryPoints!.any(
              (pattern) => projectPath == null
                  ? Glob(pattern).matches(edge.target)
                  : matchesProjectGlob(edge.target, pattern, projectPath),
            )) {
          violations.add(
            BoundaryViolation(
              edge: edge,
              source: source,
              target: target,
              reason: 'private_entry',
            ),
          );
        }
      }
    }
    return violations;
  }
}
