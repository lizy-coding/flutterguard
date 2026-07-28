# Rule fixtures

Small parser inputs — may reference Flutter/third-party types not in deps.

| category | files |
|---|---|
| architecture + cycles | `cycle_*.dart`, `boundary_issue.dart`, `forbidden_file.dart` |
| lifecycle | `lifecycle_issue.dart`, `lifecycle_negative.dart` |
| BLE | `ble_scanning_issue.dart`, `ble_scanning_negative.dart`, `ble_scanning_suppression.dart` |
| IoT security | `iot_security_issue.dart`, `iot_security_negative.dart`, `iot_security_suppression.dart` |
| generic state | `generic_state.dart` |
| provider state | `provider_state.dart` |
| bloc state | `bloc_state.dart` |
| riverpod state | `riverpod_state.dart` |
| suppression | `state_suppression.dart` |

One behavior per file where practical. Add imports only for framework
auto-detection. No generated outputs or full sample apps.

See root AGENTS.md §Per-layer constraints for MUST NOT list.
