class SuppressedBuildWidget {
  // flutterguard: ignore side_effect_in_build
  Object build(Object context) {
    notifyListeners();
    // flutterguard: ignore state_manager_created_in_build
    final controller = SuppressedController();
    return controller;
  }
}

class SuppressedController {
  // flutterguard: ignore mutable_state_exposed
  int counter = 0;
}

// flutterguard: ignore state_layer_ui_dependency
class SuppressedNavigationController {
  void open(BuildContext context) {
    Navigator.of(context).push('/device');
  }
}

// flutterguard: ignore state_dependency_cycle
class SuppressedCycleController {
  final SuppressedCycleService service;
}

class SuppressedCycleService {
  final SuppressedCycleController controller;
}

class SuppressedRiverpodWidget {
  Object build(Object context, dynamic ref) {
    // flutterguard: ignore riverpod_read_used_for_render
    return Text(ref.read(deviceProvider));
  }

  Object callbacks(dynamic ref) {
    return Button(
      // flutterguard: ignore riverpod_watch_in_callback
      onPressed: () => ref.watch(deviceProvider),
    );
  }
}

// flutterguard: ignore bloc_equatable_props_incomplete
class SuppressedEquatableState extends Equatable {
  final String name;
  final bool connected;

  List<Object?> get props => [name];
}

// flutterguard: ignore provider_value_lifecycle_misuse
final suppressedProvider = ChangeNotifierProvider.value(
  value: SuppressedNotifier(),
);

class SuppressedNotifier {
  void update(List<int> values) {
    // flutterguard: ignore notify_listeners_in_loop
    for (final value in values) {
      notifyListeners();
    }
  }
}
