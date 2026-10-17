class SuppressedBuildWidget {
  // boundarylens: ignore side_effect_in_build
  Object build(Object context) {
    notifyListeners();
    // boundarylens: ignore state_manager_created_in_build
    final controller = SuppressedController();
    return controller;
  }
}

class SuppressedController {
  // boundarylens: ignore mutable_state_exposed
  int counter = 0;
}

// boundarylens: ignore state_layer_ui_dependency
class SuppressedNavigationController {
  void open(BuildContext context) {
    Navigator.of(context).push('/device');
  }
}

// boundarylens: ignore state_dependency_cycle
class SuppressedCycleController {
  final SuppressedCycleService service;
}

class SuppressedCycleService {
  final SuppressedCycleController controller;
}

class SuppressedRiverpodWidget {
  Object build(Object context, dynamic ref) {
    // boundarylens: ignore riverpod_read_used_for_render
    return Text(ref.read(deviceProvider));
  }

  Object callbacks(dynamic ref) {
    return Button(
      // boundarylens: ignore riverpod_watch_in_callback
      onPressed: () => ref.watch(deviceProvider),
    );
  }
}

// boundarylens: ignore bloc_equatable_props_incomplete
class SuppressedEquatableState extends Equatable {
  final String name;
  final bool connected;

  List<Object?> get props => [name];
}

// boundarylens: ignore provider_value_lifecycle_misuse
final suppressedProvider = ChangeNotifierProvider.value(
  value: SuppressedNotifier(),
);

class SuppressedNotifier {
  void update(List<int> values) {
    // boundarylens: ignore notify_listeners_in_loop
    for (final value in values) {
      notifyListeners();
    }
  }
}
