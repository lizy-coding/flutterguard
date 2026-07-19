# Scan example

This small Dart target is scanned by CI with the current checkout.

```bash
dart run bin/flutterguard.dart scan example --no-color
dart run bin/flutterguard.dart scan example --format json --output .flutterguard/demo
```

Its configuration demonstrates the IoT lifecycle/security options without
depending on Flutter or the FlutterGuard package.
