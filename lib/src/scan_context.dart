import 'config_loader.dart';
import 'source_workspace.dart';

enum ScanMode { full, changed }

enum RuleScope { file, changed, project }

class ScanContext {
  final String projectPath;
  final ScanConfig config;
  final List<String> allFiles;
  final List<String> targetFiles;
  final ScanMode mode;
  final SourceWorkspace sources;
  final Set<String> changedFiles;
  final RuleScope? _scope;

  const ScanContext({
    required this.projectPath,
    required this.config,
    required this.allFiles,
    required this.targetFiles,
    required this.mode,
    required this.sources,
    this.changedFiles = const {},
    RuleScope? scope,
  }) : _scope = scope;

  RuleScope get scope =>
      _scope ?? (isChanged ? RuleScope.changed : RuleScope.project);

  bool get isChanged => mode == ScanMode.changed;
}
