// Fixture: device lifecycle issue — initState without dispose
class DeviceWidget {
  void initState() {
    // connect to device
  }

  // dispose() is missing
}
