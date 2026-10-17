import 'dart:async';

// 场景 6：显式抑制，预期 0 findings。这是抑制演示，不是修复。
class SuppressedScenario {
  // boundarylens: ignore lifecycle_resource_not_disposed
  Timer? timer;
}
