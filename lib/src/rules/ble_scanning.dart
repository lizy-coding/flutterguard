import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import '../config_loader.dart';
import 'rule.dart';
import '../source_workspace.dart';
import '../static_issue.dart';

const _bleTypeNames = {'Ble', 'BluetoothDevice', 'Bluetooth'};

bool _isBleType(String typeName) =>
    _bleTypeNames.any((t) => typeName.contains(t));

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
      final hasBleField = cls.members.whereType<FieldDeclaration>().any((f) {
        final type = f.fields.type?.toSource() ?? '';
        return _isBleType(type);
      });

      final hasBleRef = cls.members.whereType<MethodDeclaration>().any((m) {
        final visitor = _BleTypeUsageVisitor();
        m.accept(visitor);
        return visitor.usesBleType;
      });

      if (!hasBleField && !hasBleRef) continue;

      for (final method in cls.members.whereType<MethodDeclaration>()) {
        if (!_isStartScan(method.name.lexeme)) continue;
        _checkScanTimeout(file, method, lineInfo, issues);
      }
    }

    return issues;
  }

  bool _isStartScan(String name) =>
      name == 'startScan' || name.endsWith('StartScan');

  void _checkScanTimeout(
    String file,
    MethodDeclaration method,
    LineInfo lineInfo,
    List<StaticIssue> issues,
  ) {
    if (_hasTimeoutParameter(method)) return;
    if (_hasTimeoutInBody(method)) return;

    final line = lineNumberForOffset(lineInfo, method.name.offset);
    issues.add(
      StaticIssue(
        id: 'ble_scanning',
        title: 'BLE 扫描缺少超时配置',
        file: file,
        line: line,
        level: config.severity,
        domain: IssueDomain.architecture,
        message: '${method.name.lexeme}() 调用未配置超时参数',
        detail:
            '方法: ${method.name.lexeme}\n'
            'BLE 扫描应设置超时以限制扫描时间，避免过度耗电',
        suggestion: '为 startScan() 添加明确的 timeout 或 duration 参数',
        metadata: {'check': 'scan_without_timeout'},
      ),
    );
  }

  bool _hasTimeoutParameter(MethodDeclaration method) {
    for (final param in method.parameters?.parameters ?? []) {
      if (param is DefaultFormalParameter) {
        final name = param.name?.lexeme ?? '';
        if (_isTimeoutName(name)) return true;
      }
    }
    return false;
  }

  bool _hasTimeoutInBody(MethodDeclaration method) {
    final visitor = _TimeoutArgumentVisitor();
    method.body.accept(visitor);
    return visitor.hasTimeout;
  }

  bool _isTimeoutName(String name) {
    const names = {
      'timeout',
      'duration',
      'maxScanDuration',
      'scanDuration',
      'scanTimeout',
    };
    return names.any(
      (n) => name.toLowerCase().replaceAll('_', '') == n.toLowerCase(),
    );
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

class _BleTypeUsageVisitor extends RecursiveAstVisitor<void> {
  bool usesBleType = false;

  @override
  void visitNamedType(NamedType node) {
    if (_isBleType(node.toSource())) {
      usesBleType = true;
    }
    super.visitNamedType(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_isBleType(node.name)) {
      usesBleType = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

class _TimeoutArgumentVisitor extends RecursiveAstVisitor<void> {
  bool hasTimeout = false;

  static const _timeoutArgNames = {
    'timeout',
    'duration',
    'maxScanDuration',
    'scanDuration',
    'scanTimeout',
  };

  @override
  void visitNamedExpression(NamedExpression node) {
    final label = node.name.label.name;
    if (_timeoutArgNames.any(
      (n) => label.toLowerCase().replaceAll('_', '') == n.toLowerCase(),
    )) {
      hasTimeout = true;
    }
    super.visitNamedExpression(node);
  }
}
