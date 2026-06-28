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

const _lifecyclePairs = <String, String>{
  'initState': 'dispose',
  'connect': 'disconnect',
  'startScan': 'stopScan',
  'start': 'stop',
  'listen': 'cancel',
  'subscribe': 'unsubscribe',
};

class DeviceLifecycleRule {
  final DeviceLifecycleRuleConfig config;

  const DeviceLifecycleRule(this.config);

  List<StaticIssue> analyze(List<String> files) {
    if (!config.enabled) return [];

    final issues = <StaticIssue>[];

    for (final file in files) {
      try {
        final content = File(file).readAsStringSync();
        final result = parseString(content: content, path: file);
        issues.addAll(_checkFile(file, result.unit, result.lineInfo));
      } catch (_) {}
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
      final methods = cls.members.whereType<MethodDeclaration>().toList();
      final methodNames = methods.map((m) => m.name.lexeme).toSet();

      for (final initMethod in _lifecyclePairs.keys) {
        if (!methodNames.contains(initMethod)) continue;

        final teardownMethod = _lifecyclePairs[initMethod]!;
        if (!methodNames.contains(teardownMethod)) {
          final initDecl =
              methods.firstWhere((m) => m.name.lexeme == initMethod);
          final line = lineNumberForOffset(lineInfo, initDecl.name.offset);

          issues.add(StaticIssue(
            id: 'device_lifecycle',
            title: '设备生命周期不完整',
            file: file,
            line: line,
            level: RiskLevel.high,
            domain: IssueDomain.architecture,
            priority: Priority.p0,
            message:
                '类 "${cls.name.lexeme}" 中存在 "$initMethod" 但缺少对应的 "$teardownMethod"',
            detail: '类: ${cls.name.lexeme}\n'
                '存在方法: $initMethod\n'
                '缺少方法: $teardownMethod\n'
                '设备生命周期方法应成对出现 (init/teardown)',
            suggestion: '在类 "${cls.name.lexeme}" 中添加 "$teardownMethod" 方法',
            metadata: {
              'className': cls.name.lexeme,
              'initMethod': initMethod,
              'teardownMethod': teardownMethod,
            },
          ));
        }
      }
    }

    return issues;
  }

  static RuleMeta describe() => const RuleMeta(
        id: 'device_lifecycle',
        name: '设备生命周期不匹配',
        domain: 'architecture',
        riskLevel: 'high',
        priority: 'p0',
        purpose: '检测 initState/connect 等初始化方法是否有对应的 dispose/disconnect 销毁方法',
        riskReason: '不匹配的生命周期导致资源泄漏和设备连接未正常关闭',
        badExample: 'connect() 调用存在但 disconnect() 不存在',
        fixSuggestion: '确保每个初始化方法有对应的销毁方法',
        cicdSafe: true,
      );
}
