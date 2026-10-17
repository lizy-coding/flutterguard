// ignore_for_file: unused_local_variable
// Fixture: IoT security issues
class IotSecurityWidget {
  void connect() {
    // hardcoded credential
    final password = "admin123";

    // cleartext MQTT
    final brokerUrl = "tcp://192.168.1.100:1883";

    // cleartext HTTP
    final apiUrl = "http://iot.example.com/api/data";

    // insecure BLE
    final bleConfig = "withoutBonding";
  }
}
