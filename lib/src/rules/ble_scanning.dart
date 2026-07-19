import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../config_loader.dart';
import 'rule.dart';
import '../source_workspace.dart';
import '../static_issue.dart';

const _bleTypePatterns = ['Ble', 'BluetoothDevice', 'Bluetooth'];

class BleScanningRule {
  final RuleConfig config;

  const BleScanningRule(this.config);

  List<StaticIssue> analyze(List<String> files, {SourceWorkspace? workspace}) {
    if (!config.enabled) return [];

    final issues = <StaticIssue>[];
    final sources = workspace ?? SourceWorkspace();

    for (final file in files) {
      final source = sources.source(file);
      if (source == null) continue;
      issues.addAll(_checkFile(file, source.unit, source.lineInfo));
    }

    return issues;
  }

  List<StaticIssue> _checkFile(
    String file,
    CompilationUnit unit,
    LineInfo lineInfo,
  ) {
    final issues = <StaticIssue>[];

    for (final cls in unit.declarations.whereType<ClassDeclaration>()) {
      final hasBleField = cls.members.whereType<FieldDeclaration>().where((f) {
        final type = f.fields.type?.toString() ?? '';
        return _bleTypePatterns.any((t) => type.contains(t));
      }).isNotEmpty;

      final hasBleRef = cls.members.whereType<MethodDeclaration>().any((m) {
        final body = m.toString().toLowerCase();
        return _bleTypePatterns.any((t) => body.contains(t.toLowerCase()));
      });

      if (!hasBleField && !hasBleRef) continue;

      final methods = cls.members.whereType<MethodDeclaration>().toList();
      _checkScanTimeout(
        file,
        startScanMethod: methods,
        lineInfo: lineInfo,
        issues: issues,
      );
    }

    return issues;
  }

  void _checkScanTimeout(
    String file, {
    required List<MethodDeclaration> startScanMethod,
    required LineInfo lineInfo,
    required List<StaticIssue> issues,
  }) {
    for (final method in startScanMethod) {
      if (method.name.lexeme != 'startScan') continue;

      final body = method.toString().toLowerCase();
      final hasTimeout =
          body.contains('timeout') ||
          body.contains('duration') ||
          body.contains('maxscanduration');

      if (!hasTimeout) {
        final line = lineNumberForOffset(lineInfo, method.name.offset);
        issues.add(
          StaticIssue(
            id: 'ble_scanning',
            title: 'BLE 扫描缺少超时配置',
            file: file,
            line: line,
            level: config.severity,
            domain: IssueDomain.architecture,
            message: 'startScan() 调用未配置超时参数',
            detail:
                '方法: ${method.name.lexeme}\n'
                'BLE 扫描应设置超时以限制扫描时间，避免过度耗电',
            suggestion: '为 startScan() 添加明确的 timeout 或 duration 参数',
            metadata: {'check': 'scan_without_timeout'},
          ),
        );
      }
    }
  }

  static RuleDefinition describe() => const RuleDefinition(
    id: 'ble_scanning',
    name: 'BLE 扫描管理异常',
    domain: IssueDomain.architecture,
    defaultSeverity: RiskLevel.medium,
    purpose: '检测 BLE 扫描是否配置明确超时',
    riskReason: '无限扫描会持续占用无线资源并消耗电量',
    badExample: 'startScan() 没有 timeout 或 duration 限制',
    fixSuggestion: '为 startScan 添加明确超时，并由资源生命周期规则检查释放',
  );
}
