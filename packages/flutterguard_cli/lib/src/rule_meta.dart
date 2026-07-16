class RuleMeta {
  final String id;
  final String name;
  final String domain;
  final String riskLevel;
  final String priority;
  final String purpose;
  final String riskReason;
  final String badExample;
  final String fixSuggestion;
  final List<String> configKeys;
  final bool cicdSafe;
  final String framework;
  final String confidence;

  const RuleMeta({
    required this.id,
    required this.name,
    required this.domain,
    required this.riskLevel,
    required this.priority,
    required this.purpose,
    required this.riskReason,
    required this.badExample,
    required this.fixSuggestion,
    this.configKeys = const [],
    this.cicdSafe = true,
    this.framework = 'generic',
    this.confidence = 'certain',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'domain': domain,
        'riskLevel': riskLevel,
        'priority': priority,
        'purpose': purpose,
        'riskReason': riskReason,
        'badExample': badExample,
        'fixSuggestion': fixSuggestion,
        'configKeys': configKeys,
        'cicdSafe': cicdSafe,
        'framework': framework,
        'confidence': confidence,
      };
}
