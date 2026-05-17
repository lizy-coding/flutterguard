// Fixture: circular dependency (part of cycle)
import 'cycle_c.dart';

class CycleB {
  final CycleC c;
  CycleB(this.c);
}
