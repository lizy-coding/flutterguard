import 'package:analyzer/dart/ast/ast.dart';

import 'import_utils.dart';
import 'path_utils.dart';
import 'source_utils.dart';
import 'source_workspace.dart';

class ImportEdge {
  final String source;
  final String target;
  final String uri;
  final int line;

  const ImportEdge({
    required this.source,
    required this.target,
    required this.uri,
    required this.line,
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
          in source.unit.directives.whereType<ImportDirective>()) {
        final uri = directive.uri.stringValue;
        if (uri == null) continue;
        final target = resolveImport(
          sourcePath,
          uri,
          fileSet,
          projectPath: projectPath,
        );
        if (target == null || target == sourcePath) continue;
        edges.add(ImportEdge(
          source: sourcePath,
          target: target,
          uri: uri,
          line: lineNumberForOffset(source.lineInfo, directive.uri.offset),
        ));
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
