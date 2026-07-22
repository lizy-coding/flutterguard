# Rule fixtures

Fixtures are intentionally small parser inputs and may reference Flutter or
third-party types that are not dependencies of this Dart CLI package.

- architecture and cycle files exercise import graphs and boundaries;
- lifecycle/BLE/security files exercise IoT ownership;
- generic/Riverpod/Bloc/Provider files exercise state rules;
- `state_suppression.dart` exercises inline suppression.

Keep one behavior per fixture where practical. Add imports when framework
auto-detection depends on them. Do not add generated outputs or full sample
applications here.
