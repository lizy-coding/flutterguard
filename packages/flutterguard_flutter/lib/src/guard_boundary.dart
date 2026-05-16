import 'package:flutter/material.dart';
import 'package:flutterguard_core/flutterguard_core.dart';

class GuardBoundary extends StatelessWidget {
  final String name;
  final Widget child;

  const GuardBoundary({
    super.key,
    required this.name,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    FlutterGuard.recordBuild(name);
    return child;
  }
}
