# Changelog

## 0.1.0 (2026-05-17)

### Initial Release

- **cli:** Initial CLI scan command with 3 rules (large_units, lifecycle_resource, boundary_import)
- **cli:** YAML-driven config with include/exclude patterns and rule thresholds
- **cli:** JSON and Markdown report generation with score calculation
- **cli:** CI gate integration with fail-on threshold and min-score support
- **core:** Flow-level aspect tracing engine with Zone-based context propagation
- **core:** Ring buffer trace store (100 trace default)
- **core:** JSON and Markdown export for flow traces
- **dio:** Dio 5.x interceptor for HTTP request tracing within flows
- **flutter:** Flutter runtime integration with error hooks, route observer, and frame metrics
- **flutter:** GuardBoundary widget for rebuild count tracking
- **docs:** Comprehensive FLUTTERGUARD_SPEC.md with full contract, test matrices, and IoT rules
- **docs:** Dual-language README (en/zh) with installation, API reference, and CI integration guide
- **docs:** Agent-readable project rules (CONTEXT.md, PROJECT_RULES.md, AGENTS.md)
- **docs:** ARCHITECTURE.md with dependency graph and override chain documentation
- **meta:** melos monorepo setup with 4 packages + 2 examples
- **meta:** MIT license

### Known Limitations

- IoT-specific rules (device_lifecycle, mqtt_connection, ble_scanning, iot_security, pubspec_security) defined in spec but not yet implemented
- Lifecycle resource detection uses string pattern matching (not type-resolution)
- runtime tracing packages (core/dio/flutter) are frozen — Path A (static analysis) is primary
