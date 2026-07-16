class DeviceState extends Equatable {
  const DeviceState(this.name, this.connected);

  final String name;
  final bool connected;

  List<Object?> get props => [name];
}

class ReadingState extends Equatable {
  const ReadingState(this.temperature, this.humidity);

  final double temperature;
  final double humidity;

  List<Object?> get props => [temperature];
}

class CompleteState extends Equatable {
  const CompleteState(this.a, this.b);

  final int a;
  final int b;

  List<Object?> get props => [a, b];
}

class EmptyState extends Equatable {
  const EmptyState();

  static const version = 1;
  int get computed => 1;
  List<Object?> get props => const [];
}
