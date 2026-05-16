import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutterguard_core/flutterguard_core.dart' as core;

import 'route_observer.dart';

class FlutterGuard {
  static final FlutterGuardRouteObserver routeObserver =
      FlutterGuardRouteObserver();

  static void run({
    required Widget app,
    core.FlutterGuardConfig config = const core.FlutterGuardConfig(),
  }) {
    core.FlutterGuard.configure(config);

    final previousOnError = FlutterError.onError;
    if (config.collectErrors) {
      FlutterError.onError = (details) {
        core.FlutterGuard.recordError(core.ErrorTrace(
          flowId: core.FlutterGuard.currentTraceId,
          errorType: details.exception.runtimeType.toString(),
          message: details.exception.toString(),
          stackTrace: details.stack?.toString(),
          time: DateTime.now(),
        ));
        previousOnError?.call(details);
      };
    }

    if (config.collectFrames) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _recordFrameStats(config);
      });
    }

    runZonedGuarded(
      () {
        WidgetsFlutterBinding.ensureInitialized();
        runApp(app);
      },
      (error, stack) {
        if (config.collectErrors) {
          core.FlutterGuard.recordError(core.ErrorTrace(
            flowId: core.FlutterGuard.currentTraceId,
            errorType: error.runtimeType.toString(),
            message: error.toString(),
            stackTrace: stack.toString(),
            time: DateTime.now(),
          ));
        }
      },
    );
  }

  static void _recordFrameStats(core.FlutterGuardConfig config) {
    final binding = SchedulerBinding.instance;
    try {
      binding.addTimingsCallback((timings) {
        for (final timing in timings) {
          final totalSpan = timing.totalSpan.inMicroseconds ~/ 1000;
          final buildDuration = timing.buildDuration.inMicroseconds ~/ 1000;
          final rasterDuration = timing.rasterDuration.inMicroseconds ~/ 1000;
          final janky = totalSpan > config.jankFrameMs;

          core.FlutterGuard.recordFrame(core.FrameTrace(
            flowId: core.FlutterGuard.currentTraceId,
            totalSpanMs: totalSpan,
            buildDurationMs: buildDuration,
            rasterDurationMs: rasterDuration,
            janky: janky,
            time: DateTime.now(),
          ));
        }
      });
    } on NoSuchMethodError {
      // addTimingsCallback not available on this Flutter version
    }
  }

  static String? get currentTraceId => core.FlutterGuard.currentTraceId;

  static Future<T> action<T>(
    String name,
    FutureOr<T> Function() body, {
    Map<String, Object?> tags = const {},
  }) =>
      core.FlutterGuard.action(name, body, tags: tags);

  static Future<T> span<T>(
    String name,
    FutureOr<T> Function() body, {
    Map<String, Object?> tags = const {},
  }) =>
      core.FlutterGuard.span(name, body, tags: tags);

  static void recordNetwork(core.NetworkTrace trace) =>
      core.FlutterGuard.recordNetwork(trace);

  static void recordRoute(core.RouteTrace trace) =>
      core.FlutterGuard.recordRoute(trace);

  static void recordError(core.ErrorTrace trace) =>
      core.FlutterGuard.recordError(trace);

  static void recordFrame(core.FrameTrace trace) =>
      core.FlutterGuard.recordFrame(trace);

  static void recordBuild(String boundaryName) =>
      core.FlutterGuard.recordBuild(boundaryName);

  static String exportJson() => core.FlutterGuard.exportJson();

  static String exportMarkdown() => core.FlutterGuard.exportMarkdown();

  static void reset() => core.FlutterGuard.reset();

  static void configure(core.FlutterGuardConfig config) =>
      core.FlutterGuard.configure(config);
}
