// Fixture: safe IoT code that should NOT trigger iot_security
class SafeIotService {
  void connect() {
    final password = getPasswordFromEnv();
    final brokerUrl = "mqtts://secure-broker.example.com:8883";
    final apiUrl = "https://iot.example.com/api/data";
    final bleConfig = BondingConfig.withPairing();
  }

  String getPasswordFromEnv() => '';
}

class BondingConfig {
  BondingConfig.withPairing();
}
