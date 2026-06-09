class Widget {}
class BuildContext {}
class StatelessWidget {}
class StatefulWidget {}
class State<T> {}

class ValidWidget extends StatelessWidget {
  const ValidWidget();

  Widget build(BuildContext context) => Widget();
}

class MissingConstWidget extends StatelessWidget {
  MissingConstWidget();

  Widget build(BuildContext context) => Widget();
}

class MyStatefulWidget extends StatefulWidget {
  MyStatefulWidget();

  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  Widget build(BuildContext context) => Widget();
}
