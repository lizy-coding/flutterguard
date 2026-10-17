// 场景 8：应该出现红色告警。配置禁止 presentation 直接依赖 data。
import '../data/status_repository.dart';

String renderStatus() => StatusRepository().label;
