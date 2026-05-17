import 'package:flutter/material.dart';

class ValidWidget extends StatelessWidget {
  const ValidWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class MissingConstWidget extends StatelessWidget {
  MissingConstWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}

class MyStatefulWidget extends StatefulWidget {
  MyStatefulWidget({super.key});

  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}
