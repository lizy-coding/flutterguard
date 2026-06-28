import 'package:flutterguard_cli/src/rule_meta.dart';
import 'package:flutterguard_cli/src/rules/ble_scanning.dart';
import 'package:flutterguard_cli/src/rules/circular_dependency.dart';
import 'package:flutterguard_cli/src/rules/device_lifecycle.dart';
import 'package:flutterguard_cli/src/rules/iot_security.dart';
import 'package:flutterguard_cli/src/rules/large_units.dart';
import 'package:flutterguard_cli/src/rules/layer_violation.dart';
import 'package:flutterguard_cli/src/rules/lifecycle_resource.dart';
import 'package:flutterguard_cli/src/rules/missing_const_constructor.dart';
import 'package:flutterguard_cli/src/rules/module_violation.dart';
import 'package:flutterguard_cli/src/rules/mqtt_connection.dart';
import 'package:flutterguard_cli/src/rules/pubspec_security.dart';

class RuleRegistry {
  static final Map<String, RuleMeta> _registry = () {
    final list = <RuleMeta>[
      LargeUnitsRule.describeLargeFile(),
      LargeUnitsRule.describeLargeClass(),
      LargeUnitsRule.describeLargeBuildMethod(),
      LifecycleResourceRule.describe(),
      MissingConstConstructorRule.describe(),
      DeviceLifecycleRule.describe(),
      MqttConnectionRule.describe(),
      BleScanningRule.describe(),
      IotSecurityRule.describe(),
      PubspecSecurityRule.describe(),
      LayerViolationRule.describe(),
      ModuleViolationRule.describe(),
      CircularDependencyRule.describe(),
    ];
    return {for (final m in list) m.id: m};
  }();

  static List<RuleMeta> all() => _registry.values.toList();

  static RuleMeta? find(String id) => _registry[id];
}
