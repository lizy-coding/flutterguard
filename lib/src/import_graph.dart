import 'package:analyzer/dart/ast/ast.dart';

import 'import_utils.dart';
import 'path_utils.dart';
import 'source_workspace.dart';

class ImportEdge {
  final String source;
  final String target;
  final String uri;
  final int line;
  final String kind;

  const ImportEdge({
    required this.source,
    required this.target,
    required this.uri,
    required this.line,
    this.kind = 'import',
  });
}

class ImportGraph {
  final Set<String> files;
  final Map<String, List<ImportEdge>> _outgoing;

  const ImportGraph._(this.files, this._outgoing);

  factory ImportGraph.build({
    required Iterable<String> files,
    required Iterable<String> sourceFiles,
    required SourceWorkspace workspace,
    String? projectPath,
  }) {
    final fileSet = {for (final file in files) normalizePath(file)};
    final outgoing = <String, List<ImportEdge>>{};

    for (final sourcePath in sourceFiles.map(normalizePath)) {
      final source = workspace.source(sourcePath);
      if (source == null) {
        outgoing[sourcePath] = const [];
        continue;
      }

      final edges = <ImportEdge>[];
      for (final directive
          in source.unit.directives.whereType<NamespaceDirective>()) {
        final literals = [
          directive.uri,
          ...directive.configurations.map((c) => c.uri),
        ];
        for (final literal in literals) {
          final uri = literal.stringValue;
          if (uri == null) continue;
          final parsed = Uri.tryParse(uri);
          if (parsed?.scheme == 'dart') continue;
          final packageName = projectPath == null
              ? null
              : workspace.packageName(projectPath);
          if (parsed?.scheme == 'package' &&
              packageName != null &&
              parsed!.pathSegments.isNotEmpty &&
              parsed.pathSegments.first != packageName) {
            continue;
          }
          final target = resolveImport(
            sourcePath,
            uri,
            fileSet,
            projectPath: projectPath,
            packageName: packageName,
          );
          if (target == null) {
            workspace.addDiagnostic(
              ScanDiagnostic(
                stage: 'reference_resolution',
                file: sourcePath,
                message:
                    'Reference "$uri" is unresolved or outside the selected source context.',
              ),
            );
            continue;
          }
          if (target == sourcePath) continue;
          edges.add(
            ImportEdge(
              source: sourcePath,
              target: target,
              uri: uri,
              kind: directive is ExportDirective ? 'export' : 'import',
              line: lineNumberForOffset(source.lineInfo, literal.offset),
            ),
          );
        }
      }
      outgoing[sourcePath] = edges;
    }

    return ImportGraph._(fileSet, outgoing);
  }

  List<ImportEdge> outgoing(String source) =>
      _outgoing[normalizePath(source)] ?? const [];

  Set<String> dependenciesOf(String source) =>
      outgoing(source).map((edge) => edge.target).toSet();
}
