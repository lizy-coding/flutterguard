class DeviceController {}

class ImmutableValue {
  const ImmutableValue();
}

final existingController = DeviceController();

final badValue = ChangeNotifierProvider<DeviceController>.value(
  value: DeviceController(),
);

final badCreate = ChangeNotifierProvider(
  create: (_) => existingController,
);

final safeCreate = ChangeNotifierProvider(
  create: (_) => DeviceController(),
);

final safeValue = ChangeNotifierProvider.value(
  value: existingController,
);

final safeImmutable = Provider.value(
  value: const ImmutableValue(),
);

class DeviceNotifier {
  void updateAll(List<int> values) {
    for (final value in values) {
      notifyListeners();
    }
    values.forEach((value) {
      notifyListeners();
    });
  }

  void safe() {
    for (final value in [1]) {
      notifyListeners();
    }
    for (final value in [1, 2]) {
      consume(value);
    }
    notifyListeners();
  }
}
