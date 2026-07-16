class Widget {
  Widget({Object? onPressed});
}

class BuildContext {}

class StatelessWidget {}

class DeviceController {
  DeviceController();

  final List<int> _items = [];
  List<int> get items => _items;

  void mutate() {
    state.items.add(1);
  }
}

class DeviceBloc {}

class BadBuildWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    notifyListeners();
    final controller = DeviceController();
    return Widget();
  }
}

class SecondBadBuildWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    setState(() {});
    final bloc = DeviceBloc();
    return Widget();
  }
}

class SafeBuildWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    final values = <int>[];
    values.add(1);
    return Widget(onPressed: () {
      notifyListeners();
      final controller = DeviceController();
    });
  }
}

class DeviceState {
  int count = 0;
  final List<int> items = [];
}

class SafeState {
  final List<int> items = List.unmodifiable(const []);
}

class State<T> {}

class Page {}

class PageState extends State<Page> {
  int widgetCounter = 0;
}

class NavigationController {
  NavigationController(this.context);

  final BuildContext context;

  void open() {
    Navigator.of(context).push('/device');
  }
}

class ThemeController {
  void update(Widget widget) {}
}

class CycleController {
  CycleController(this.service);

  final CycleService service;
}

class CycleService {
  CycleService(this.controller);

  final CycleController controller;
}
