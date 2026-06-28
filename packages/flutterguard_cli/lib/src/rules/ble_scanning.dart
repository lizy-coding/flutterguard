import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

import '../config_loader.dart';
import '../domain.dart';
import '../priority.dart';
import '../rule_meta.dart';
import '../source_utils.dart';
import '../static_issue.dart';

const _bleTypePatterns = ['Ble', 'Ble', 'BluetoothDevice', 'Bluetooth'];

class BleScanningRule {
  final BleScanningRuleConfig config;

  const BleScanningRule(this.config);

  List<StaticIssue> analyze(List<String> files) {
    if (!config.enabled) return [];

    final issues = <StaticIssue>[];

    for (final file in files) {
      try {
        final content = File(file).readAsStringSync();
        final result = parseString(content: content, path: file);
        issues.addAll(_checkFile(file, content, result.unit, result.lineInfo));
      } catch (_) {}
    }

    return issues;
  }

  List<StaticIssue> _checkFile(
    String file,
    String rawContent,
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
      final methodNames = methods.map((m) => m.name.lexeme).toSet();

      if (methodNames.contains('startScan') &&
          !methodNames.contains('stopScan')) {
        final startScanMethod =
            methods.firstWhere((m) => m.name.lexeme == 'startScan');
        final line = lineNumberForOffset(lineInfo, startScanMethod.name.offset);
        issues.add(StaticIssue(
          id: 'ble_scanning',
          title: 'BLE 扫描未停止',
          file: file,
          line: line,
          level: RiskLevel.medium,
          domain: IssueDomain.architecture,
          priority: Priority.p1,
          message: '类 "${cls.name.lexeme}" 中有 startScan() 调用但缺少 stopScan()',
          detail: '类: ${cls.name.lexeme}\n'
              'BLE 扫描应在不需要时停止以节省电量',
          suggestion: '在类中添加 stopScan() 方法并在 dispose 中调用',
          metadata: {
            'className': cls.name.lexeme,
            'check': 'startScan_without_stopScan',
          },
        ));
      }

      if (methodNames.contains('connect') &&
          !methodNames.contains('disconnect')) {
        final connectMethod =
            methods.firstWhere((m) => m.name.lexeme == 'connect');
        final line = lineNumberForOffset(lineInfo, connectMethod.name.offset);
        issues.add(StaticIssue(
          id: 'ble_scanning',
          title: 'BLE 连接未断开',
          file: file,
          line: line,
          level: RiskLevel.medium,
          domain: IssueDomain.architecture,
          priority: Priority.p1,
          message: '类 "${cls.name.lexeme}" 中有 BLE connect() 调用但缺少 disconnect()',
          detail: '类: ${cls.name.lexeme}\n'
              'BLE 连接应在不需要时断开以节省电量',
          suggestion: '在类中添加 disconnect() 方法并在 dispose 中调用',
          metadata: {
            'className': cls.name.lexeme,
            'check': 'ble_connect_without_disconnect',
          },
        ));
      }

      _checkScanTimeout(file,
          startScanMethod: methods, lineInfo: lineInfo, issues: issues);
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
      final hasTimeout = body.contains('timeout') ||
          body.contains('duration') ||
          body.contains('maxscanduration');

      if (!hasTimeout) {
        final line = lineNumberForOffset(lineInfo, method.name.offset);
        issues.add(StaticIssue(
          id: 'ble_scanning',
          title: 'BLE 扫描缺少超时配置',
          file: file,
          line: line,
          level: RiskLevel.low,
          domain: IssueDomain.architecture,
          priority: Priority.p1,
          message: 'startScan() 调用未配置超时参数',
          detail: '方法: ${method.name.lexeme}\n'
              'BLE 扫描应设置超时以限制扫描时间，避免过度耗电',
          suggestion:
              '为 startScan() 添加超时参数 (推荐 < ${config.maxScanDurationMs}ms)',
          metadata: {
            'check': 'scan_without_timeout',
            'maxScanDurationMs': config.maxScanDurationMs,
          },
        ));
      }
    }
  }

  static RuleMeta describe() => const RuleMeta(
        id: 'ble_scanning',
        name: 'BLE 扫描管理异常',
        domain: 'architecture',
        riskLevel: 'medium',
        priority: 'p1',
        purpose: '检测 BLE startScan/stopScan、connect/disconnect 配对及扫描超时配置',
        riskReason: '未停止的 BLE 扫描持续消耗电量；缺少超时导致扫描无限进行',
        badExample: 'startScan() 调用后无 stopScan() 和超时参数',
        fixSuggestion: '在 dispose() 中添加 stopScan()；为 startScan 添加超时参数',
        configKeys: ['rules.ble_scanning.maxScanDurationMs'],
        cicdSafe: true,
      );
}
