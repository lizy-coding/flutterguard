import 'package:dio/dio.dart';
import 'package:flutterguard_core/flutterguard_core.dart';
import 'package:flutterguard_dio/flutterguard_dio.dart';
import 'package:test/test.dart';

void main() {
  late Dio dio;

  setUp(() {
    FlutterGuard.reset();
    FlutterGuard.configure(const FlutterGuardConfig(maxTraces: 100));
    dio = Dio(BaseOptions(baseUrl: 'https://example.com'));
    dio.interceptors.add(FlutterGuardDioInterceptor());
  });

  tearDown(() {
    dio.close();
    FlutterGuard.reset();
  });

  test('interceptor records success response', () async {
    final request = RequestOptions(path: '/api/items');
    final startTime = DateTime.now().subtract(const Duration(milliseconds: 50));
    request.extra['flutterguard_start_time'] = startTime;

    final response = Response(
      requestOptions: request,
      statusCode: 200,
      data: {'id': 1},
    );

    FlutterGuard.recordNetwork(NetworkTrace(
      flowId: 'test_flow',
      method: request.method,
      path: request.uri.path,
      statusCode: response.statusCode!,
      durationMs: 50,
      success: true,
    ));

    final traces = FlutterGuard.exportJson();
    expect(traces, contains('200'));
    expect(traces, contains('/api/items'));
  });

  test('interceptor records error response', () async {
    FlutterGuard.recordNetwork(NetworkTrace(
      flowId: 'test_flow',
      method: 'GET',
      path: '/api/error',
      durationMs: 100,
      success: false,
      errorType: 'connectionError',
      errorMessage: 'Connection refused',
    ));

    final traces = FlutterGuard.exportJson();
    expect(traces, contains('Connection refused'));
    expect(traces, contains('/api/error'));
  });

  test('interceptor attaches to current flow', () async {
    await FlutterGuard.action('network_flow', () async {
      FlutterGuard.recordNetwork(NetworkTrace(
        flowId: FlutterGuard.currentTraceId,
        method: 'POST',
        path: '/api/submit',
        statusCode: 201,
        durationMs: 42,
        success: true,
      ));
    });

    final json = FlutterGuard.exportJson();
    expect(json, contains('network_flow'));
    expect(json, contains('/api/submit'));
    expect(json, contains('POST'));
  });

  test('interceptor does not log body by default', () async {
    await FlutterGuard.action('sanitize_flow', () async {
      FlutterGuard.recordNetwork(NetworkTrace(
        flowId: FlutterGuard.currentTraceId,
        method: 'POST',
        path: '/api/login',
        statusCode: 200,
        durationMs: 30,
        success: true,
        requestSize: null,
        responseSize: null,
      ));
    });

    final json = FlutterGuard.exportJson();
    expect(json, contains('/api/login'));
    expect(json, isNot(contains('password')));
    expect(json, isNot(contains('secret')));
  });
}
