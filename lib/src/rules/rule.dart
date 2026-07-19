import '../config_loader.dart';
import '../import_graph.dart';
import '../scan_context.dart';
import '../static_issue.dart';

typedef RuleExecutor =
    List<StaticIssue> Function(
      ScanContext context,
      RuleConfig config,
      ImportGraph? importGraph,
    );

class RuleDefinition {
  final String id;
  final String name;
  final IssueDomain domain;
  final RiskLevel defaultSeverity;
  final String purpose;
  final String riskReason;
  final String badExample;
  final String fixSuggestion;
  final Map<String, Object?> defaultOptions;
  final String framework;

  const RuleDefinition({
    required this.id,
    required this.name,
    required this.domain,
    required this.defaultSeverity,
    required this.purpose,
    required this.riskReason,
    required this.badExample,
    required this.fixSuggestion,
    this.defaultOptions = const {},
    this.framework = 'generic',
  });

  List<String> get configKeys => [
    'enabled',
    'severity',
    ...defaultOptions.keys,
  ];

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'domain': domain.name,
    'severity': defaultSeverity.name,
    'purpose': purpose,
    'riskReason': riskReason,
    'badExample': badExample,
    'fixSuggestion': fixSuggestion,
    'configKeys': configKeys,
    'options': defaultOptions,
    'framework': framework,
  };
}

class RuleRegistration {
  final RuleDefinition definition;
  final RuleExecutor execute;

  const RuleRegistration({required this.definition, required this.execute});
}
