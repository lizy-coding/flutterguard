// Fixture: circular dependency (part of cycle)
import 'cycle_a.dart';

class CycleC {
  final CycleA a;
  CycleC(this.a);
}
