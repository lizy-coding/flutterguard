# Rule layer

## Ownership

| detector file | finding IDs owned |
|---|---|
| `boundary_rule.dart` | `layer_violation`, `module_violation` |
| `circular_dependency.dart` | `circular_dependency` |
| `lifecycle_resource.dart` | `lifecycle_resource_not_disposed` |
| `ble_scanning.dart` | `ble_scanning` |
| `iot_security.dart` | `iot_security` |
| `generic_state_management.dart` | `side_effect_in_build`, `state_manager_created_in_build`, `mutable_state_exposed`, `state_layer_ui_dependency` |
| `provider_state_management.dart` | `provider_value_lifecycle_misuse`, `notify_listeners_in_loop` |
| `riverpod_state_management.dart` | `riverpod_read_used_for_render`, `riverpod_watch_in_callback` |
| `bloc_state_management.dart` | `bloc_equatable_props_incomplete` |
| `state_dependency_cycle.dart` | `state_dependency_cycle` |
| `state_management_utils.dart` | shared utilities (no findings) |
| `rule.dart` | `RuleDefinition`, `RuleRegistration` types |
| `registry.dart` | sole `RuleRegistry.registrations` source |

## Contract

- Detectors receive `ScanContext` + effective `RuleConfig` + optional
  `ImportGraph`.
- Use `SourceWorkspace` from context; never re-read/re-parse files.
- Respect `RuleConfig.enabled`; emit `config.severity`.
- Scalar defaults in `RuleDefinition.defaultOptions`.
- Parameter types belong in `RuleDefinition.optionTypes`; defaults and schema must agree.
- Declare inputs/scopes/activation in the definition. The private RuleRunner owns
  shared preparation, central skipping, execution status and identity validation.
  Do not wire a new detector into scanner/IDE or introduce a second registry.

See root AGENTS.md §Per-layer constraints for MUST NOT list.
