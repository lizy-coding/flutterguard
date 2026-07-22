# Rule layer

Every detector returns `List<StaticIssue>`. Scanner execution is explicit in
`RuleRegistry.registrations`; metadata and defaults live in the adjacent
`RuleDefinition`.

Ownership:

- `boundary_rule.dart`: both layer and module dependency enforcement.
- `lifecycle_resource.dart`: resource cancel/close/dispose/disconnect checks.
- `ble_scanning.dart`: BLE scan timeout only.
- `iot_security.dart`: credentials and insecure transport.
- state files: generic, Riverpod, Bloc, Provider, and dependency-cycle checks.

Use the supplied `SourceWorkspace`; do not read or parse files again. Respect
`RuleConfig.enabled` and emit `config.severity`. Add special scalar defaults to
`RuleDefinition.defaultOptions`.

Do not add `describe` metadata to another catalog, restore direct public rule
exports, or let two rule families own the same finding.
