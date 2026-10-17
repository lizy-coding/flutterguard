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

enum RuleInput { targetSyntax, projectSyntax, importGraph }

enum RuleActivation { always, layers, modules, cycles }

enum RuleOptionType {
  boolean,
  integer,
  string;

  bool accepts(Object? value) => switch (this) {
    boolean => value is bool,
    integer => value is int,
    string => value is String,
  };
}

class RuleDefinition {
  final String id;
  final String name;
  final IssueDomain domain;
  final RiskLevel defaultSeverity;
  final bool defaultEnabled;
  final String purpose;
  final String riskReason;
  final String badExample;
  final String fixSuggestion;
  final Map<String, Object?> defaultOptions;
  final String framework;
  final Map<String, RuleOptionType> optionTypes;
  final Set<RuleInput> inputs;
  final Set<RuleScope> scopes;
  final RuleActivation activation;

  const RuleDefinition({
    required this.id,
    required this.name,
    required this.domain,
    required this.defaultSeverity,
    required this.purpose,
    required this.riskReason,
    required this.badExample,
    required this.fixSuggestion,
    this.defaultEnabled = false,
    this.defaultOptions = const {},
    this.framework = 'generic',
    this.optionTypes = const {},
    this.inputs = const {RuleInput.targetSyntax},
    this.scopes = const {RuleScope.file, RuleScope.changed, RuleScope.project},
    this.activation = RuleActivation.always,
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
    'defaultEnabled': defaultEnabled,
    'purpose': purpose,
    'riskReason': riskReason,
    'badExample': badExample,
    'fixSuggestion': fixSuggestion,
    'configKeys': configKeys,
    'options': defaultOptions,
    'framework': framework,
    'optionTypes': {
      for (final entry in optionTypes.entries) entry.key: entry.value.name,
    },
    'inputs': inputs.map((value) => value.name).toList(),
    'scopes': scopes.map((value) => value.name).toList(),
    'activation': activation.name,
  };
}

class RuleRegistration {
  final RuleDefinition definition;
  final RuleExecutor execute;

  const RuleRegistration({required this.definition, required this.execute});
}
