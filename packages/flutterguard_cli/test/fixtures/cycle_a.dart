// Fixture: circular dependency (part of cycle)
import 'cycle_b.dart';

class CycleA {
  final CycleB b;
  CycleA(this.b);
}
