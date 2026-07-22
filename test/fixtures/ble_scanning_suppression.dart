// ignore_for_file: unused_local_variable
// Fixture: BLE scanning with suppression comments
class BleSuppressedDevice {}

class BleSuppressedService {
  late BleSuppressedDevice _device;

  // flutterguard: ignore ble_scanning
  void startScan() {
    // scanning without timeout, suppressed
  }

  void connect() {}
}
