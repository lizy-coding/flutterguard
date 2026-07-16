import 'domain.dart';
import 'priority.dart';

enum RiskLevel { low, medium, high }

enum StateManagementFramework { riverpod, bloc, provider, generic }

enum RuleConfidence { certain, probable, informational }

class StaticIssue {
  final String id;
  final String title;
  final String file;
  final int? line;
  final RiskLevel level;
  final IssueDomain domain;
  final Priority priority;
  final String message;
  final String detail;
  final String suggestion;
  final Map<String, Object?> metadata;
  final StateManagementFramework framework;
  final RuleConfidence confidence;
  final List<String> evidence;

  const StaticIssue({
    required this.id,
    required this.title,
    required this.file,
    this.line,
    required this.level,
    required this.domain,
    required this.priority,
    required this.message,
    this.detail = '',
    required this.suggestion,
    this.metadata = const {},
    this.framework = StateManagementFramework.generic,
    this.confidence = RuleConfidence.certain,
    this.evidence = const [],
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'ruleId': id,
        'title': title,
        'file': file,
        'line': line,
        'level': level.name,
        'severity': level.name,
        'domain': domain.name,
        'priority': priority.name,
        'message': message,
        'detail': detail,
        'suggestion': suggestion,
        'metadata': metadata,
        'framework': framework.name,
        'confidence': confidence.name,
        'evidence': evidence.take(5).toList(),
      };
}
