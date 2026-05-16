enum RiskLevel { low, medium, high }

class StaticIssue {
  final String id;
  final String title;
  final String file;
  final int? line;
  final RiskLevel level;
  final String message;
  final String suggestion;
  final Map<String, Object?> metadata;

  const StaticIssue({
    required this.id,
    required this.title,
    required this.file,
    this.line,
    required this.level,
    required this.message,
    required this.suggestion,
    this.metadata = const {},
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'file': file,
        'line': line,
        'level': level.name,
        'message': message,
        'suggestion': suggestion,
        'metadata': metadata,
      };
}
