// Fixture: IoT security issues with suppression comments
class SuppressedIotWidget {
  void connect() {
    // boundarylens: ignore iot_security
    final password = "admin123";

    // boundarylens: ignore iot_security
    final brokerUrl = "tcp://192.168.1.100:1883";

    // boundarylens: ignore iot_security
    final apiUrl = "http://iot.example.com/api/data";

    // boundarylens: ignore iot_security
    final bleConfig = "withoutBonding";
  }
}
