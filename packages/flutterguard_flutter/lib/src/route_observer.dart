import 'package:flutter/material.dart';
import 'package:flutterguard_core/flutterguard_core.dart';

class FlutterGuardRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    FlutterGuard.recordRoute(RouteTrace(
      flowId: FlutterGuard.currentTraceId,
      type: 'push',
      from: previousRoute != null ? _routeName(previousRoute) : null,
      to: _routeName(route),
      time: DateTime.now(),
    ));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    FlutterGuard.recordRoute(RouteTrace(
      flowId: FlutterGuard.currentTraceId,
      type: 'pop',
      from: _routeName(route),
      to: previousRoute != null ? _routeName(previousRoute) : null,
      time: DateTime.now(),
    ));
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    FlutterGuard.recordRoute(RouteTrace(
      flowId: FlutterGuard.currentTraceId,
      type: 'replace',
      from: oldRoute != null ? _routeName(oldRoute) : null,
      to: newRoute != null ? _routeName(newRoute) : null,
      time: DateTime.now(),
    ));
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    FlutterGuard.recordRoute(RouteTrace(
      flowId: FlutterGuard.currentTraceId,
      type: 'remove',
      from: _routeName(route),
      to: previousRoute != null ? _routeName(previousRoute) : null,
      time: DateTime.now(),
    ));
  }

  String _routeName(Route<dynamic> route) {
    return route.settings.name ?? route.runtimeType.toString();
  }
}
