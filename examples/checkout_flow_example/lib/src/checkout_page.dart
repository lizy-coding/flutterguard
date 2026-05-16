import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutterguard_flutter/flutterguard_flutter.dart';

class CheckoutPage extends StatefulWidget {
  final Dio dio;

  const CheckoutPage({super.key, required this.dio});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _isSubmitting = false;
  String? _result;

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _result = null;
    });

    try {
      final orderResult = await FlutterGuard.action(
        'submit_order',
        () => _submitOrder(),
        tags: {'screen': 'checkout'},
      );

      setState(() {
        _result = orderResult;
        _isSubmitting = false;
      });

      if (mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Order Result')),
              body: Center(child: Text('Order: $orderResult')),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isSubmitting = false;
      });
    }
  }

  Future<String> _submitOrder() async {
    final isValid = await FlutterGuard.span(
      'validate_form',
      () async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        return true;
      },
    );

    if (!isValid) throw Exception('Validation failed');

    final response = await FlutterGuard.span(
      'request_create_order',
      () async {
        final resp = await widget.dio.post<Map<String, dynamic>>(
          '/posts',
          data: jsonEncode({
            'title': 'Checkout Order',
            'body': 'Order placed via FlutterGuard demo',
            'userId': 1,
          }),
        );
        return resp;
      },
    );

    // ignore: avoid_dynamic_calls
    return 'Order #${response.data!['id']} created';
  }

  @override
  Widget build(BuildContext context) {
    return GuardBoundary(
      name: 'CheckoutPage',
      child: Scaffold(
        appBar: AppBar(title: const Text('Checkout Flow Demo')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSubmitting) const CircularProgressIndicator(),
              if (!_isSubmitting && _result == null)
                ElevatedButton(
                  onPressed: _handleSubmit,
                  child: const Text('Submit Order'),
                ),
              if (_result != null) Text(_result!),
              if (!_isSubmitting) const SizedBox(height: 20),
              if (!_isSubmitting)
                ElevatedButton(
                  onPressed: () {
                    final report = FlutterGuard.exportJson();
                    showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Export Report'),
                        content: SingleChildScrollView(
                          child: Text(report,
                              style: const TextStyle(fontSize: 10)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('View Report'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
