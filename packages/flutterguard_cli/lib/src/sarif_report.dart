import 'dart:convert';

import 'package:path/path.dart' as p;

import 'rules/registry.dart';
import 'static_issue.dart';

class SarifReport {
  static String generate({
    required String projectPath,
    required List<StaticIssue> issues,
  }) {
    final rules = RuleRegistry.all()..sort((a, b) => a.id.compareTo(b.id));

    final payload = {
      r'$schema': 'https://json.schemastore.org/sarif-2.1.0.json',
      'version': '2.1.0',
      'runs': [
        {
          'tool': {
            'driver': {
              'name': 'FlutterGuard',
              'informationUri': 'https://github.com/lizy-coding/flutterguard',
              'rules': [
                for (final rule in rules)
                  {
                    'id': rule.id,
                    'name': rule.name,
                    'shortDescription': {'text': rule.purpose},
                    'fullDescription': {'text': rule.riskReason},
                    'help': {'text': rule.fixSuggestion},
                    'defaultConfiguration': {
                      'level': _levelFromRule(rule.riskLevel),
                    },
                    'properties': {
                      'framework': rule.framework,
                      'confidence': rule.confidence,
                    },
                  }
              ],
            },
          },
          'results': [
            for (final issue in issues)
              {
                'ruleId': issue.id,
                'level': _level(issue.level),
                'message': {'text': issue.message},
                'properties': {
                  'framework': issue.framework.name,
                  'confidence': issue.confidence.name,
                  'evidence': issue.evidence.take(5).toList(),
                },
                'locations': [
                  {
                    'physicalLocation': {
                      'artifactLocation': {
                        'uri': _relativeUri(issue.file, projectPath),
                      },
                      'region': {
                        'startLine': issue.line ?? 1,
                      },
                    },
                  }
                ],
              }
          ],
        }
      ],
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static String _relativeUri(String filePath, String projectPath) {
    final relative =
        p.isWithin(projectPath, filePath) || p.equals(projectPath, filePath)
            ? p.relative(filePath, from: projectPath)
            : filePath;
    return relative.replaceAll('\\', '/');
  }

  static String _level(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return 'error';
      case RiskLevel.medium:
        return 'warning';
      case RiskLevel.low:
        return 'note';
    }
  }

  static String _levelFromRule(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return 'error';
      case 'medium':
        return 'warning';
      default:
        return 'note';
    }
  }
}
