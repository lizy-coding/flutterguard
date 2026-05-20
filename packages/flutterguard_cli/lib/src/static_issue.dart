import 'domain.dart';
import 'priority.dart';

enum RiskLevel { low, medium, high }

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
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'file': file,
        'line': line,
        'level': level.name,
        'domain': domain.name,
        'priority': priority.name,
        'message': message,
        'detail': detail,
        'suggestion': suggestion,
        'metadata': metadata,
      };
}
