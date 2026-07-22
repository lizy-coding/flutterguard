// Fixture: IoT security issues with suppression comments
class SuppressedIotWidget {
  void connect() {
    // flutterguard: ignore iot_security
    final password = "admin123";

    // flutterguard: ignore iot_security
    final brokerUrl = "tcp://192.168.1.100:1883";

    // flutterguard: ignore iot_security
    final apiUrl = "http://iot.example.com/api/data";

    // flutterguard: ignore iot_security
    final bleConfig = "withoutBonding";
  }
}
