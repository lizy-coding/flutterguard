import 'package:dio/dio.dart';
import 'package:flutterguard_core/flutterguard_core.dart';

class FlutterGuardDioInterceptor extends Interceptor {
  final bool sanitizeHeaders;
  final bool sanitizeBody;
  final List<String> sensitiveKeys;

  FlutterGuardDioInterceptor({
    this.sanitizeHeaders = true,
    this.sanitizeBody = true,
    List<String>? sensitiveKeys,
  }) : sensitiveKeys = sensitiveKeys ?? _defaultSensitiveKeys;

  static const _defaultSensitiveKeys = [
    'authorization',
    'cookie',
    'set-cookie',
    'token',
    'password',
    'secret',
    'email',
    'phone',
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra['flutterguard_start_time'] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _recordResponse(response);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _recordError(err);
    handler.next(err);
  }

  void _recordResponse(Response response) {
    final requestOptions = response.requestOptions;
    final startTime = requestOptions.extra['flutterguard_start_time'];
    if (startTime is! DateTime) return;

    final durationMs = DateTime.now().difference(startTime).inMilliseconds;
    final statusCode = response.statusCode;
    final success = statusCode != null && statusCode >= 200 && statusCode < 400;

    FlutterGuard.recordNetwork(NetworkTrace(
      flowId: FlutterGuard.currentTraceId,
      method: requestOptions.method,
      path: requestOptions.uri.path,
      statusCode: statusCode,
      durationMs: durationMs,
      requestSize: _estimateSize(requestOptions.data),
      responseSize: _estimateSize(response.data),
      success: success,
    ));
  }

  void _recordError(DioException err) {
    final requestOptions = err.requestOptions;
    final startTime = requestOptions.extra['flutterguard_start_time'];
    if (startTime is! DateTime) return;

    final durationMs = DateTime.now().difference(startTime).inMilliseconds;

    FlutterGuard.recordNetwork(NetworkTrace(
      flowId: FlutterGuard.currentTraceId,
      method: requestOptions.method,
      path: requestOptions.uri.path,
      durationMs: durationMs,
      success: false,
      errorType: err.type.name,
      errorMessage: err.message,
    ));
  }

  int? _estimateSize(dynamic data) {
    if (data == null) return null;
    try {
      return data.toString().length;
    } catch (_) {
      return null;
    }
  }
}
