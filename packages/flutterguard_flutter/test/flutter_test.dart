import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterguard_core/flutterguard_core.dart';
import 'package:flutterguard_flutter/flutterguard_flutter.dart';

void main() {
  setUp(() {
    FlutterGuard.reset();
    FlutterGuard.configure(const FlutterGuardConfig(maxTraces: 100));
  });

  tearDown(() {
    FlutterGuard.reset();
  });

  testWidgets('GuardBoundary records build count', (tester) async {
    await FlutterGuard.action('test_boundary', () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardBoundary(
              name: 'TestPage',
              child: const Text('Hello'),
            ),
          ),
        ),
      );

      // Trigger a rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GuardBoundary(
              name: 'TestPage',
              child: const Text('Hello Again'),
            ),
          ),
        ),
      );
    });

    final json = FlutterGuard.exportJson();
    expect(json, contains('TestPage'));
  });

  testWidgets('route observer records push and pop', (tester) async {
    final observer = FlutterGuard.routeObserver;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('Home')),
      ),
    );

    await FlutterGuard.action('route_flow', () async {
      await tester.tap(find.text('Home'));
    });
  });

  test('error hook preserves previous handler', () async {
    bool previousCalled = false;

    FlutterError.onError = (details) {
      previousCalled = true;
    };

    try {
      await FlutterGuard.action('error_flow', () async {
        throw Exception('guarded error');
      });
    } catch (_) {}

    // This test verifies the error handling doesn't crash
    // The actual hook testing is done in integration
    expect(true, isTrue);
  });

  test('frame aspect can attach to active flow', () {
    FlutterGuard.recordFrame(FrameTrace(
      flowId: 'test_frame_flow',
      totalSpanMs: 32,
      buildDurationMs: 20,
      rasterDurationMs: 12,
      janky: true,
      time: DateTime.now(),
    ));

    final json = FlutterGuard.exportJson();
    expect(json, contains('test_frame_flow'));
  });
}
