import 'package:flutterguard_cli/src/rule_meta.dart';
import 'package:flutterguard_cli/src/rules/catalog.dart';

class RuleRegistry {
  static final Map<String, RuleMeta> _registry = () {
    final list = RuleCatalog.metadata();
    return {for (final m in list) m.id: m};
  }();

  static List<RuleMeta> all() => _registry.values.toList();

  static RuleMeta? find(String id) => _registry[id];
}
