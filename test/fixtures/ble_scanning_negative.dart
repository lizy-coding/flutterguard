// Fixture: BLE scanning with proper timeout configuration
class BleDevice {}

class ScanResult {}

class BleService {
  late BleDevice _device;

  void startScan({Duration? timeout}) {
    // configured with timeout parameter
  }

  void startScanWithTimeout() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
  }

  void stopAndDisconnect() {
    _device.disconnect();
  }
}
