import 'package:flutter/material.dart';
import 'package:flutterguard_flutter/flutterguard_flutter.dart';
import 'package:flutterguard_dio/flutterguard_dio.dart';
import 'package:dio/dio.dart';

import 'src/checkout_page.dart';

void main() {
  final dio = Dio(BaseOptions(baseUrl: 'https://jsonplaceholder.typicode.com'));
  dio.interceptors.add(FlutterGuardDioInterceptor());

  FlutterGuard.run(
    config: const FlutterGuardConfig(
      enabled: true,
      collectErrors: true,
      collectFrames: true,
      collectRoutes: true,
      collectBuilds: true,
      slowFlowMs: 1000,
      jankFrameMs: 16,
      maxTraces: 100,
    ),
    app: MaterialApp(
      title: 'Checkout Flow Demo',
      navigatorObservers: [FlutterGuard.routeObserver],
      home: CheckoutPage(dio: dio),
    ),
  );
}
