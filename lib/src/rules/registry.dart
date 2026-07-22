import '../import_graph.dart';
import '../scan_context.dart';
import '../static_issue.dart';
import 'ble_scanning.dart';
import 'bloc_state_management.dart';
import 'boundary_rule.dart';
import 'circular_dependency.dart';
import 'generic_state_management.dart';
import 'iot_security.dart';
import 'lifecycle_resource.dart';
import 'provider_state_management.dart';
import 'riverpod_state_management.dart';
import 'rule.dart';
import 'state_dependency_cycle.dart';

/// The single source of truth for rule metadata, defaults, and execution.
class RuleRegistry {
  static final List<RuleRegistration> registrations = List.unmodifiable([
    RuleRegistration(
      definition: LifecycleResourceRule.describe(),
      execute: (context, config, _) => LifecycleResourceRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: BoundaryRule.definition(BoundaryKind.layer),
      execute: (context, config, graph) {
        if (!config.enabled || context.config.architecture.layers.isEmpty) {
          return [];
        }
        return BoundaryRule(
          kind: BoundaryKind.layer,
          boundaries: context.config.architecture.layers,
          severity: config.severity,
          projectPath: context.projectPath,
        ).analyze(
          context.targetFiles,
          allFiles: context.allFiles,
          workspace: context.sources,
          importGraph: graph!,
        );
      },
    ),
    RuleRegistration(
      definition: BoundaryRule.definition(BoundaryKind.module),
      execute: (context, config, graph) {
        if (!config.enabled || context.config.architecture.modules.isEmpty) {
          return [];
        }
        return BoundaryRule(
          kind: BoundaryKind.module,
          boundaries: context.config.architecture.modules,
          severity: config.severity,
          projectPath: context.projectPath,
        ).analyze(
          context.targetFiles,
          allFiles: context.allFiles,
          workspace: context.sources,
          importGraph: graph!,
        );
      },
    ),
    RuleRegistration(
      definition: CircularDependencyRule.describe(),
      execute: (context, config, graph) =>
          CircularDependencyRule(
            enabled:
                config.enabled &&
                !context.isChanged &&
                context.config.architecture.detectCycles,
            severity: config.severity,
            projectPath: context.projectPath,
          ).analyze(
            context.targetFiles,
            workspace: context.sources,
            importGraph: graph,
          ),
    ),
    RuleRegistration(
      definition: BleScanningRule.describe(),
      execute: (context, config, _) => BleScanningRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: IotSecurityRule.describe(),
      execute: (context, config, _) => IotSecurityRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: SideEffectInBuildRule.describe(),
      execute: (context, config, _) => SideEffectInBuildRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: StateManagerCreatedInBuildRule.describe(),
      execute: (context, config, _) => StateManagerCreatedInBuildRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: MutableStateExposedRule.describe(),
      execute: (context, config, _) => MutableStateExposedRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: StateLayerUiDependencyRule.describe(),
      execute: (context, config, _) => StateLayerUiDependencyRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: StateDependencyCycleRule.describe(),
      execute: (context, config, _) =>
          StateDependencyCycleRule(
            config,
            projectPath: context.projectPath,
          ).analyze(
            context.allFiles,
            targetFiles: context.targetFiles,
            changedOnly: context.isChanged,
            workspace: context.sources,
          ),
    ),
    RuleRegistration(
      definition: RiverpodReadUsedForRenderRule.describe(),
      execute: (context, config, _) => RiverpodReadUsedForRenderRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: RiverpodWatchInCallbackRule.describe(),
      execute: (context, config, _) => RiverpodWatchInCallbackRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: BlocEquatablePropsIncompleteRule.describe(),
      execute: (context, config, _) => BlocEquatablePropsIncompleteRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: ProviderValueLifecycleMisuseRule.describe(),
      execute: (context, config, _) => ProviderValueLifecycleMisuseRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      definition: NotifyListenersInLoopRule.describe(),
      execute: (context, config, _) => NotifyListenersInLoopRule(
        config,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
  ]);

  static List<RuleDefinition> all() => [
    for (final registration in registrations) registration.definition,
  ];

  static RuleDefinition? find(String id) {
    for (final definition in all()) {
      if (definition.id == id) return definition;
    }
    return null;
  }

  static List<StaticIssue> analyze(ScanContext context) {
    final needsImportGraph =
        context.config.architecture.layers.isNotEmpty ||
        context.config.architecture.modules.isNotEmpty ||
        (!context.isChanged && context.config.architecture.detectCycles);
    final graph = needsImportGraph
        ? ImportGraph.build(
            files: context.allFiles,
            sourceFiles: context.targetFiles,
            workspace: context.sources,
            projectPath: context.projectPath,
          )
        : null;

    final issues = <StaticIssue>[];
    for (final registration in registrations) {
      final definition = registration.definition;
      final config = context.config.rule(
        definition.id,
        defaultSeverity: definition.defaultSeverity,
        defaultOptions: definition.defaultOptions,
      );
      issues.addAll(registration.execute(context, config, graph));
    }
    return issues;
  }
}
