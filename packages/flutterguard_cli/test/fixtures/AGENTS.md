# Fixture Layer

## Responsibility
This directory contains intentionally imperfect Dart/YAML files used by CLI rule tests (21 fixture files).

## Fixture Inventory
| File | Rule |
|------|------|
| `large_file.dart` | large_file |
| `large_class.dart` | large_class |
| `large_build.dart` | large_build_method |
| `lifecycle_issue.dart` | lifecycle_resource_not_disposed |
| `boundary_issue.dart` + `forbidden_file.dart` | layer_violation, module_violation |
| `cycle_a/b/c.dart` | circular_dependency |
| `missing_const.dart` | missing_const_constructor |
| `iot_security_issue.dart` | iot_security |
| `device_lifecycle_issue.dart` | device_lifecycle |
| `mqtt_connection_issue.dart` | mqtt_connection |
| `ble_scanning_issue.dart` | ble_scanning |
| `architecture_config.yaml` / `architecture_disabled.yaml` | architecture config parsing |
| `generic_state.dart` | Generic build, mutability, UI dependency, and state-cycle rules |
| `riverpod_state.dart` | Riverpod read/render and watch/callback rules |
| `bloc_state.dart` | Bloc Equatable props completeness |
| `provider_state.dart` | Provider ownership and loop notification rules |
| `state_suppression.dart` | All state rules through suppression and baseline pipelines |

## Rules
- Fixtures may intentionally violate style or architecture rules.
- Keep fixture names tied to the rule or scenario they exercise.
- Do not import app dependencies; fixtures should remain plain Dart snippets where possible.
- When adding architecture fixtures, update or add a matching YAML config.
- Avoid broad fixture changes because many tests can depend on the same file.
- pubspec_security tests create isolated YAML fixtures in temp directories.
