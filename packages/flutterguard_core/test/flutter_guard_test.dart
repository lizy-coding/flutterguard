import 'dart:async';

import 'package:flutterguard_core/flutterguard_core.dart';
import 'package:test/test.dart';

void main() {
  setUp(() {
    FlutterGuard.reset();
    FlutterGuard
        .configure(const FlutterGuardConfig(maxTraces: 100));
  });

  tearDown(() {
    FlutterGuard.reset();
  });

  test('action creates flow trace', () async {
    final result = await FlutterGuard.action('test_action', () async {
      await Future.delayed(const Duration(milliseconds: 10));
      return 'done';
    });

    expect(result, equals('done'));
    final json = FlutterGuard.exportJson();
    expect(json, contains('test_action'));
    expect(json, contains('success'));
  });

  test('span attaches to current flow', () async {
    await FlutterGuard.action('test_action', () async {
      final spanResult = await FlutterGuard.span('inner_span', () async {
        await Future.delayed(const Duration(milliseconds: 5));
        return 'span_done';
      });
      expect(spanResult, equals('span_done'));
    });

    final json = FlutterGuard.exportJson();
    expect(json, contains('inner_span'));
  });

  test('zone context survives async futures', () async {
    String? capturedId;

    await FlutterGuard.action('test_action', () async {
      final id1 = FlutterGuard.currentTraceId;
      expect(id1, isNotNull);

      await Future.delayed(const Duration(milliseconds: 5));
      final id2 = FlutterGuard.currentTraceId;
      expect(id2, equals(id1));

      capturedId = id1;
    });

    expect(capturedId, isNotNull);
  });

  test('errors mark flow failed', () async {
    try {
      await FlutterGuard.action('test_action', () async {
        throw Exception('test error');
      });
      fail('should have thrown');
    } catch (_) {}

    final json = FlutterGuard.exportJson();
    expect(json, contains('failed'));
    expect(json, contains('test error'));
  });

  test('json export contains trace', () async {
    await FlutterGuard.action('test_action', () async {});

    final json = FlutterGuard.exportJson();
    expect(json, contains('"version"'));
    expect(json, contains('"traces"'));
    expect(json, contains('"test_action"'));
  });

  test('markdown export contains sections', () async {
    await FlutterGuard.action('test_action', () async {});

    final md = FlutterGuard.exportMarkdown();
    expect(md, contains('# FlutterGuard Flow Report'));
    expect(md, contains('## Summary'));
    expect(md, contains('## Runtime Flows'));
    expect(md, contains('test_action'));
  });

  test('ring buffer respects max traces', () async {
    FlutterGuard.configure(const FlutterGuardConfig(maxTraces: 3));

    for (var i = 0; i < 5; i++) {
      await FlutterGuard.action('action_$i', () async {});
    }

    final json = FlutterGuard.exportJson();
    expect(json, contains('action_2'));
    expect(json, contains('action_3'));
    expect(json, contains('action_4'));
    expect(json, isNot(contains('action_0')));
    expect(json, isNot(contains('action_1')));
  });
}
