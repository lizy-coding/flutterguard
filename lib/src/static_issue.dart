enum IssueDomain { architecture, performance, standards }

enum RiskLevel { low, medium, high }

enum StateManagementFramework { riverpod, bloc, provider, generic }

class StaticIssue {
  final String id;
  final String title;
  final String file;
  final int? line;
  final RiskLevel level;
  final IssueDomain domain;
  final String message;
  final String detail;
  final String suggestion;
  final Map<String, Object?> metadata;
  final StateManagementFramework framework;
  final List<String> evidence;

  const StaticIssue({
    required this.id,
    required this.title,
    required this.file,
    this.line,
    required this.level,
    required this.domain,
    required this.message,
    this.detail = '',
    required this.suggestion,
    this.metadata = const {},
    this.framework = StateManagementFramework.generic,
    this.evidence = const [],
  });

  Map<String, Object?> toJson() => {
    'ruleId': id,
    'title': title,
    'file': file,
    'line': line,
    'severity': level.name,
    'domain': domain.name,
    'message': message,
    'detail': detail,
    'suggestion': suggestion,
    'metadata': metadata,
    'framework': framework.name,
    'evidence': evidence.take(5).toList(),
  };
}
