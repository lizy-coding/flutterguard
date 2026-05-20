import 'package:flutterguard_core/flutterguard_core.dart';

Future<void> main() async {
  FlutterGuard.configure(const FlutterGuardConfig(enabled: true));

  print('=== FlutterGuard Tracing Demo ===\n');

  await FlutterGuard.action('fetch_user_data', () async {
    FlutterGuard.span('validate_token', () async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });

    FlutterGuard.span('query_database', () async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });

    FlutterGuard.recordNetwork(NetworkTrace(
      method: 'GET',
      path: '/api/users/42',
      statusCode: 200,
      durationMs: 85,
      success: true,
    ));

    FlutterGuard.span('format_response', () async {
      await Future<void>.delayed(const Duration(milliseconds: 15));
    });
  });

  await FlutterGuard.action('process_payment', () async {
    FlutterGuard.recordNetwork(NetworkTrace(
      method: 'POST',
      path: '/api/payments',
      statusCode: 201,
      durationMs: 320,
      success: true,
    ));
  }, tags: {'amount': '29.99', 'currency': 'USD'});

  try {
    await FlutterGuard.action('failing_operation', () async {
      await FlutterGuard.span('risky_call', () async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw Exception('Service unavailable');
      });
    });
  } catch (e) {
    // Error is captured in the trace; demos don't crash.
  }

  print(FlutterGuard.exportMarkdown());
}
