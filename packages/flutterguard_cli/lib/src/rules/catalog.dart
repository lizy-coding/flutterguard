import 'package:path/path.dart' as p;

import '../import_graph.dart';
import '../path_utils.dart';
import '../rule_meta.dart';
import '../scan_context.dart';
import '../static_issue.dart';
import 'ble_scanning.dart';
import 'bloc_state_management.dart';
import 'circular_dependency.dart';
import 'device_lifecycle.dart';
import 'iot_security.dart';
import 'generic_state_management.dart';
import 'large_units.dart';
import 'layer_violation.dart';
import 'lifecycle_resource.dart';
import 'missing_const_constructor.dart';
import 'module_violation.dart';
import 'mqtt_connection.dart';
import 'pubspec_security.dart';
import 'provider_state_management.dart';
import 'riverpod_state_management.dart';
import 'state_dependency_cycle.dart';

typedef RuleExecutor = List<StaticIssue> Function(
  ScanContext context,
  ImportGraph? importGraph,
);

class RuleRegistration {
  final List<RuleMeta> metadata;
  final RuleExecutor execute;

  const RuleRegistration({
    required this.metadata,
    required this.execute,
  });
}

/// Explicit source of truth for rule metadata and execution wiring.
class RuleCatalog {
  static final List<RuleRegistration> registrations = List.unmodifiable([
    RuleRegistration(
      metadata: [
        LargeUnitsRule.describeLargeFile(),
        LargeUnitsRule.describeLargeClass(),
        LargeUnitsRule.describeLargeBuildMethod(),
      ],
      execute: (context, _) => LargeUnitsRule(
        largeFileConfig: context.config.rules.largeFile,
        largeClassConfig: context.config.rules.largeClass,
        largeBuildMethodConfig: context.config.rules.largeBuildMethod,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [LifecycleResourceRule.describe()],
      execute: (context, _) => LifecycleResourceRule(
        context.config.rules.lifecycleResource,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [LayerViolationRule.describe()],
      execute: (context, importGraph) {
        if (!context.config.architecture.layerViolationEnabled) return [];
        return LayerViolationRule(
          context.config.architecture.layers,
          projectPath: context.projectPath,
        ).analyze(
          context.targetFiles,
          allFiles: context.allFiles,
          workspace: context.sources,
          importGraph: importGraph,
        );
      },
    ),
    RuleRegistration(
      metadata: [ModuleViolationRule.describe()],
      execute: (context, importGraph) {
        if (!context.config.architecture.moduleViolationEnabled) return [];
        return ModuleViolationRule(
          context.config.architecture.modules,
          projectPath: context.projectPath,
        ).analyze(
          context.targetFiles,
          allFiles: context.allFiles,
          workspace: context.sources,
          importGraph: importGraph,
        );
      },
    ),
    RuleRegistration(
      metadata: [MissingConstConstructorRule.describe()],
      execute: (context, _) => MissingConstConstructorRule(
        context.config.rules.missingConstConstructor,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [CircularDependencyRule.describe()],
      execute: (context, importGraph) => CircularDependencyRule(
        enabled: !context.isChanged && context.config.architecture.detectCycles,
        projectPath: context.projectPath,
      ).analyze(
        context.targetFiles,
        workspace: context.sources,
        importGraph: importGraph,
      ),
    ),
    RuleRegistration(
      metadata: [DeviceLifecycleRule.describe()],
      execute: (context, _) => DeviceLifecycleRule(
        context.config.rules.deviceLifecycle,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [MqttConnectionRule.describe()],
      execute: (context, _) => MqttConnectionRule(
        context.config.rules.mqttConnection,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [BleScanningRule.describe()],
      execute: (context, _) => BleScanningRule(
        context.config.rules.bleScanning,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [IotSecurityRule.describe()],
      execute: (context, _) => IotSecurityRule(
        context.config.rules.iotSecurity,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [PubspecSecurityRule.describe()],
      execute: (context, _) {
        final pubspecPath = normalizePath(
          p.join(context.projectPath, 'pubspec.yaml'),
        );
        if (context.isChanged && !context.changedFiles.contains(pubspecPath)) {
          return [];
        }
        return PubspecSecurityRule(
          context.config.rules.pubspecSecurity,
        ).analyze(
          context.targetFiles,
          projectPath: context.projectPath,
          workspace: context.sources,
        );
      },
    ),
    RuleRegistration(
      metadata: [SideEffectInBuildRule.describe()],
      execute: (context, _) => SideEffectInBuildRule(
        context.config.rules.sideEffectInBuild,
        context.config.stateManagement,
        projectPath: context.projectPath,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [StateManagerCreatedInBuildRule.describe()],
      execute: (context, _) => StateManagerCreatedInBuildRule(
        context.config.rules.stateManagerCreatedInBuild,
        context.config.stateManagement,
        projectPath: context.projectPath,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [MutableStateExposedRule.describe()],
      execute: (context, _) => MutableStateExposedRule(
        context.config.rules.mutableStateExposed,
        context.config.stateManagement,
        projectPath: context.projectPath,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [StateLayerUiDependencyRule.describe()],
      execute: (context, _) => StateLayerUiDependencyRule(
        context.config.rules.stateLayerUiDependency,
        context.config.stateManagement,
        projectPath: context.projectPath,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [StateDependencyCycleRule.describe()],
      execute: (context, _) => StateDependencyCycleRule(
        context.config.rules.stateDependencyCycle,
        context.config.stateManagement,
        projectPath: context.projectPath,
      ).analyze(
        context.allFiles,
        targetFiles: context.targetFiles,
        changedOnly: context.isChanged,
        workspace: context.sources,
      ),
    ),
    RuleRegistration(
      metadata: [RiverpodReadUsedForRenderRule.describe()],
      execute: (context, _) => RiverpodReadUsedForRenderRule(
        context.config.rules.riverpodReadUsedForRender,
        context.config.stateManagement,
        projectPath: context.projectPath,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [RiverpodWatchInCallbackRule.describe()],
      execute: (context, _) => RiverpodWatchInCallbackRule(
        context.config.rules.riverpodWatchInCallback,
        context.config.stateManagement,
        projectPath: context.projectPath,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [BlocEquatablePropsIncompleteRule.describe()],
      execute: (context, _) => BlocEquatablePropsIncompleteRule(
        context.config.rules.blocEquatablePropsIncomplete,
        context.config.stateManagement,
        projectPath: context.projectPath,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [ProviderValueLifecycleMisuseRule.describe()],
      execute: (context, _) => ProviderValueLifecycleMisuseRule(
        context.config.rules.providerValueLifecycleMisuse,
        context.config.stateManagement,
        projectPath: context.projectPath,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
    RuleRegistration(
      metadata: [NotifyListenersInLoopRule.describe()],
      execute: (context, _) => NotifyListenersInLoopRule(
        context.config.rules.notifyListenersInLoop,
        context.config.stateManagement,
        projectPath: context.projectPath,
      ).analyze(context.targetFiles, workspace: context.sources),
    ),
  ]);

  static List<RuleMeta> metadata() => [
        for (final registration in registrations) ...registration.metadata,
      ];

  static List<StaticIssue> analyze(ScanContext context) {
    final architecture = context.config.architecture;
    final needsImportGraph =
        architecture.layerViolationEnabled && architecture.layers.isNotEmpty ||
            architecture.moduleViolationEnabled &&
                architecture.modules.isNotEmpty ||
            !context.isChanged && architecture.detectCycles;
    final importGraph = needsImportGraph
        ? ImportGraph.build(
            files: context.allFiles,
            sourceFiles: context.targetFiles,
            workspace: context.sources,
            projectPath: context.projectPath,
          )
        : null;

    return [
      for (final registration in registrations)
        ...registration.execute(context, importGraph),
    ];
  }
}
