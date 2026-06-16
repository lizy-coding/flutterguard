// ignore_for_file: unused_field
// Fixture: MQTT connection issues
class MqttClient {}

class MqttService {
  late MqttClient _client;

  void connect() {
    // broker URL hardcoded
    final url = 'tcp://broker.iot.local:1883';
  }

  // disconnect() is missing
}
