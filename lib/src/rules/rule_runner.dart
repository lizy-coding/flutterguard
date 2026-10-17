import '../import_graph.dart';
import '../config_loader.dart';
import '../scan_context.dart';
import '../static_issue.dart';
import 'rule.dart';

class RuleRunResult {
  final List<StaticIssue> issues;
  final Map<String, Map<String, Object?>> coverage;

  const RuleRunResult(this.issues, this.coverage);
}

/// Internal execution service. Registrations still come from the sole registry;
/// tests may pass ephemeral registrations without extending the product catalog.
class RuleRunner {
  static void validateDefinitions(Iterable<RuleRegistration> registrations) {
    final ids = <String>{};
    for (final registration in registrations) {
      final d = registration.definition;
      if (d.id.isEmpty || !ids.add(d.id)) {
        throw StateError('Duplicate or empty rule ID: ${d.id}');
      }
      if (d.defaultOptions.length != d.optionTypes.length ||
          d.defaultOptions.entries.any(
            (e) => !(d.optionTypes[e.key]?.accepts(e.value) ?? false),
          )) {
        throw StateError(
          'Rule ${d.id} has inconsistent option defaults/schema.',
        );
      }
    }
  }

  static RuleRunResult run(
    ScanContext context,
    List<RuleRegistration> registrations,
  ) {
    validateDefinitions(registrations);
    final coverage = <String, Map<String, Object?>>{};
    final active = <RuleRegistration>[];
    final configs = <String, RuleConfig>{};
    for (final registration in registrations) {
      final d = registration.definition;
      final config = context.config.rule(
        d.id,
        defaultSeverity: d.defaultSeverity,
        defaultOptions: d.defaultOptions,
        defaultEnabled: d.defaultEnabled,
      );
      // Revalidate at the internal execution boundary, including disabled rules.
      for (final option in config.options.entries) {
        if (!(d.optionTypes[option.key]?.accepts(option.value) ?? false)) {
          throw FormatException('Invalid option rules.${d.id}.${option.key}.');
        }
      }
      configs[d.id] = config;
      String? status;
      String? reason;
      if (!config.enabled) {
        status = 'disabled';
        reason = 'disabled_by_config';
      } else if (!d.scopes.contains(context.scope)) {
        status = 'unsupported_scope';
        reason = 'scope_not_supported';
      } else if (!_configured(d.activation, context)) {
        status = 'not_configured';
        reason = 'required_configuration_missing';
      } else if (context.targetFiles.isEmpty) {
        status = 'not_applicable';
        reason = 'no_selected_sources';
      }
      if (status != null) {
        coverage[d.id] = _coverage(context, status, [reason!], 0);
      } else {
        active.add(registration);
      }
    }
    final graphRequired = active.any(
      (r) => r.definition.inputs.contains(RuleInput.importGraph),
    );
    final graph = graphRequired
        ? ImportGraph.build(
            files: context.allFiles,
            sourceFiles: context.targetFiles,
            workspace: context.sources,
            projectPath: context.projectPath,
          )
        : null;
    final graphProblems =
        graphRequired && context.sources.diagnostics.isNotEmpty;
    final issues = <StaticIssue>[];
    for (final registration in active) {
      final d = registration.definition;
      final files = d.inputs.contains(RuleInput.projectSyntax)
          ? context.allFiles
          : context.targetFiles;
      final needsSyntax =
          d.inputs.contains(RuleInput.targetSyntax) ||
          d.inputs.contains(RuleInput.projectSyntax);
      var unavailable = false;
      if (needsSyntax) {
        for (final file in files) {
          if (context.sources.source(file) == null) unavailable = true;
        }
      }
      final reasons = <String>[];
      if (unavailable) {
        reasons.add('source_input_unavailable');
      }
      if (d.inputs.contains(RuleInput.importGraph) && graphProblems) {
        reasons.add('reference_input_incomplete');
      }
      if (!unavailable) {
        final before = context.sources.diagnostics.length;
        final findings = registration.execute(context, configs[d.id]!, graph);
        if (findings.any((issue) => issue.id != d.id)) {
          throw StateError(
            'Rule ${d.id} emitted a finding owned by another rule.',
          );
        }
        issues.addAll(findings);
        if (context.sources.diagnostics.length > before) {
          reasons.add('rule_diagnostics');
        }
      }
      if (d.activation == RuleActivation.modules &&
          context.config.architecture.modules.any(
            (m) => m.entryPoints == null,
          )) {
        reasons.add('entry_points_not_declared');
      }
      coverage[d.id] = _coverage(
        context,
        reasons.isEmpty ? 'complete' : 'partial',
        reasons,
        files.length,
      );
    }
    return RuleRunResult(issues, coverage);
  }

  static bool _configured(RuleActivation activation, ScanContext context) =>
      switch (activation) {
        RuleActivation.always => true,
        RuleActivation.layers => context.config.architecture.layers.isNotEmpty,
        RuleActivation.modules =>
          context.config.architecture.modules.isNotEmpty,
        RuleActivation.cycles => context.config.architecture.detectCycles,
      };

  static Map<String, Object?> _coverage(
    ScanContext context,
    String status,
    List<String> reasons,
    int checked,
  ) => {
    'status': status,
    'scope': context.scope.name,
    'reasons': reasons,
    'checkedFiles': checked,
  };
}
