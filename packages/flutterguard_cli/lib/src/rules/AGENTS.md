# Rule Layer

## Responsibility
Each file implements one rule family and returns `List<StaticIssue>`.

## Existing Rule Families
- `large_units.dart`: `large_file`, `large_class`, `large_build_method`
- `lifecycle_resource.dart`: undisposed controllers, streams, timers, MQTT/BLE resources
- `layer_violation.dart`: configured layer dependency breaches
- `module_violation.dart`: configured module dependency breaches
- `circular_dependency.dart`: file-level import cycles
- `missing_const_constructor.dart`: widget classes missing const constructors
- `device_lifecycle.dart`: balanced init/teardown pairs (initState↔dispose, connect↔disconnect, startScan↔stopScan, etc.)
- `mqtt_connection.dart`: MQTT connect/disconnect pairing, subscribe/unsubscribe, hardcoded broker URLs
- `ble_scanning.dart`: BLE startScan/stopScan pairing, connect/disconnect, scan timeout configuration
- `iot_security.dart`: hardcoded credentials, cleartext MQTT (port 1883), cleartext HTTP, insecure BLE
- `pubspec_security.dart`: unbounded deps, deprecated packages (flutter_blue→flutter_blue_plus), outdated IoT dependencies

## Rule Contract
- Constructor receives typed config or explicit parameters.
- Public API is `analyze(List<String> files, {SourceWorkspace? workspace})` for source rules; direct calls may omit the workspace.
- Scanner execution and metadata are explicitly wired in `catalog.dart`.
- Return no issues when disabled or not configured.
- Catch per-file parse/read failures so one bad file does not abort the full scan.
- Use `StaticIssue` with domain, priority, suggestion, and metadata.
- Use line numbers, not analyzer character offsets.
- IoT rules use string/pattern matching on file contents (consistent with lifecycle_resource approach).

## New Rule Checklist
1. Add spec entry in `docs/FLUTTERGUARD_SPEC.md`.
2. Add typed config in `config_loader.dart` if configurable.
3. Implement the rule class here.
4. Add fixture(s) under `test/fixtures/`.
5. Add tests in `test/scanner_test.dart`.
6. Wire the rule and metadata in `catalog.dart`.
7. Export through `lib/flutterguard_cli.dart` if needed.
